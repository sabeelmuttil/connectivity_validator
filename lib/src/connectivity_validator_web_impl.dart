import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Default cross-origin probe used under `no-cors` mode.
///
/// Under `no-cors`, the response is opaque — status codes cannot be read.
/// Online means the fetch promise fulfilled; offline means reject/timeout.
const String _kDefaultProbeUrl = 'https://www.gstatic.com/generate_204';

const Duration _kProbeTimeout = Duration(seconds: 2);
const Duration _kPeriodicInterval = Duration(seconds: 12);

class ConnectivityValidator {
  ConnectivityValidator({String? probeUrl})
      : _probeUrl = probeUrl ?? _kDefaultProbeUrl,
        _useCorsStatusCheck = probeUrl != null;

  final String _probeUrl;

  /// When true, fetch with CORS and require HTTP 204 (custom same-origin /
  /// CORS-enabled endpoints). When false, use no-cors and treat fulfill/reject
  /// as the connectivity signal.
  final bool _useCorsStatusCheck;

  late final Stream<bool> _connectivityChanges = _createConnectivityStream();

  /// Returns the current network state once.
  /// true = The probe was reachable. With a custom CORS-enabled [probeUrl],
  /// this means the endpoint returned HTTP 204.
  /// false = No network, the probe failed, or the browser blocked the request.
  ///
  /// Use this for on-demand checks (e.g. when the user taps a button).
  Future<bool> get getConnectivityStatus => _checkConnectivity();

  /// Returns a stream of booleans (for continuous monitoring).
  /// With the default cross-origin probe, this reports reachability only: a
  /// browser cannot inspect an opaque `no-cors` response to detect a captive
  /// portal. Supply a CORS-enabled [probeUrl] for strict HTTP-204 validation.
  ///
  /// Consecutive duplicate values are filtered out, so listeners only
  /// see actual connectivity changes.
  Stream<bool> get onConnectivityChanged {
    return _connectivityChanges;
  }

  Stream<bool> _createConnectivityStream() {
    late StreamController<bool> controller;
    StreamSubscription<web.Event>? onlineSub;
    StreamSubscription<web.Event>? offlineSub;
    StreamSubscription<web.Event>? visibilitySub;
    Timer? periodicTimer;
    var active = false;
    var latestProbeId = 0;

    Future<void> emitLatest() async {
      if (!active) return;
      final probeId = ++latestProbeId;
      final isOnline = await _checkConnectivity();
      // Fetch completion order is not guaranteed. Ignore an older result that
      // completed after a newer probe or an offline browser event.
      if (active && !controller.isClosed && probeId == latestProbeId) {
        controller.add(isOnline);
      }
    }

    void emitOffline() {
      // Invalidate any in-flight probe that could otherwise overwrite this
      // unambiguous browser offline event with a stale `true` value.
      latestProbeId++;
      if (active && !controller.isClosed) {
        controller.add(false);
      }
    }

    void stopPeriodic() {
      periodicTimer?.cancel();
      periodicTimer = null;
    }

    void startPeriodic() {
      stopPeriodic();
      if (!active || web.document.visibilityState == 'hidden') return;
      periodicTimer = Timer.periodic(_kPeriodicInterval, (_) {
        unawaited(emitLatest());
      });
    }

    void tearDown() {
      active = false;
      latestProbeId++;
      stopPeriodic();
      onlineSub?.cancel();
      offlineSub?.cancel();
      visibilitySub?.cancel();
      onlineSub = null;
      offlineSub = null;
      visibilitySub = null;
    }

    controller = StreamController<bool>.broadcast(
      onListen: () {
        active = true;
        unawaited(emitLatest());

        onlineSub = web.EventStreamProviders.onlineEvent
            .forTarget(web.window)
            .listen((_) => unawaited(emitLatest()));

        offlineSub = web.EventStreamProviders.offlineEvent
            .forTarget(web.window)
            .listen((_) => emitOffline());

        visibilitySub = web.document.onVisibilityChange.listen((_) {
          if (web.document.visibilityState == 'hidden') {
            stopPeriodic();
          } else {
            unawaited(emitLatest());
            startPeriodic();
          }
        });

        startPeriodic();
      },
      onCancel: tearDown,
    );

    return controller.stream.distinct();
  }

  Future<bool> _checkConnectivity() async {
    if (!web.window.navigator.onLine) return false;
    return _probe();
  }

  Future<bool> _probe() async {
    final abort = web.AbortController();
    final timeout = Timer(_kProbeTimeout, () => abort.abort());

    try {
      if (_useCorsStatusCheck) {
        final response = await web.window
            .fetch(
              _probeUrl.toJS,
              web.RequestInit(
                method: 'GET',
                mode: 'cors',
                cache: 'no-store',
                signal: abort.signal,
              ),
            )
            .toDart;
        return response.status == 204;
      }

      // Default path: no-cors — opaque response; fulfill == reached network.
      await web.window
          .fetch(
            _probeUrl.toJS,
            web.RequestInit(
              method: 'GET',
              mode: 'no-cors',
              cache: 'no-store',
              signal: abort.signal,
            ),
          )
          .toDart;
      return true;
    } catch (_) {
      return false;
    } finally {
      timeout.cancel();
    }
  }
}
