import Flutter
import UIKit
import Network

public class ConnectivityValidatorPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var monitor: NWPathMonitor?
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var lastState: Bool? = nil
    private var eventSink: FlutterEventSink?
    
    // HTTPS connectivity testing
    private var consecutiveHttpsFailures = 0
    private let REQUIRED_FAILURES_TO_OVERRIDE = 2
    private var lastConnectivityTestTime: TimeInterval = 0
    private let CONNECTIVITY_TEST_CACHE_MS: TimeInterval = 5000 // 5 seconds
    private var periodicCheckTimer: Timer?
    private let PERIODIC_CHECK_INTERVAL: TimeInterval = 2.0 // 2 seconds

    /// Emit false only after this many separate offline signals (OS, timers, probe failures).
    /// A first-ever offline state is emitted immediately; this debounce only applies to changes.
    private let REQUIRED_OFFLINE_SIGNALS = 2

    /// Probe timeout — must cover a full TLS handshake on slow cellular networks;
    /// 0.5s caused false "offline" results on high-latency connections.
    private let PROBE_TIMEOUT: TimeInterval = 2.0
    private var pendingOfflineSignals = 0

    public static func register(with registrar: FlutterPluginRegistrar) {
        let eventChannel = FlutterEventChannel(name: "connectivity_validator/status", binaryMessenger: registrar.messenger())
        let instance = ConnectivityValidatorPlugin()
        eventChannel.setStreamHandler(instance)
        
        let methodChannel = FlutterMethodChannel(name: "connectivity_validator/method", binaryMessenger: registrar.messenger())
        methodChannel.setMethodCallHandler(instance.handleMethodCall)
    }

    private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "getStatus" else {
            result(FlutterMethodNotImplemented)
            return
        }
        queue.async { [weak self] in
            self?.getCurrentConnectivityStatus { isOnline in
                DispatchQueue.main.async {
                    result(isOnline)
                }
            }
        }
    }

    /// One-time check: path status + HTTPS validation. Safe to call without stream.
    /// Uses pathUpdateHandler because currentPath is not reliable until the monitor has run.
    private func getCurrentConnectivityStatus(completion: @escaping (Bool) -> Void) {
        let oneShotMonitor = NWPathMonitor()
        oneShotMonitor.pathUpdateHandler = { [weak oneShotMonitor] path in
            oneShotMonitor?.cancel()
            guard path.status == .satisfied else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            // Verify with HTTPS
            let urls = [
                "https://www.google.com/generate_204",
                "https://connectivitycheck.gstatic.com/generate_204",
                "https://cp.cloudflare.com/generate_204" // Cloudflare fallback (Google-blocked regions)
            ]
            self.testConnectivityOneShot(urls: urls, index: 0) { isOnline in
                DispatchQueue.main.async { completion(isOnline) }
            }
        }
        oneShotMonitor.start(queue: queue)
    }

    private func testConnectivityOneShot(urls: [String], index: Int, completion: @escaping (Bool) -> Void) {
        guard index < urls.count, let url = URL(string: urls[index]) else {
            completion(false)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = PROBE_TIMEOUT
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let task = URLSession.shared.dataTask(with: request) { _, response, _ in
            if let http = response as? HTTPURLResponse {
                // generate_204 endpoints ALWAYS return 204. Anything else means a
                // captive portal or proxy intercepted the request — not real internet.
                completion(http.statusCode == 204)
                return
            }
            self.testConnectivityOneShot(urls: urls, index: index + 1, completion: completion)
        }
        task.resume()
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        pendingOfflineSignals = 0
        
        // Monitor all network interfaces (WiFi, cellular, etc.)
        // This ensures we detect changes when WiFi loses internet but remains connected
        monitor = NWPathMonitor()

        monitor?.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            let pathSaysOnline = (path.status == .satisfied)

            if pathSaysOnline && self.consecutiveHttpsFailures >= self.REQUIRED_FAILURES_TO_OVERRIDE {
                return
            }

            if pathSaysOnline {
                self.reportOnline()
                self.verifyConnectivityAsync()
            } else {
                self.consecutiveHttpsFailures = 0
                if self.lastState == nil {
                    // First update and we're offline — emit immediately so listeners
                    // (e.g. `onConnectivityChanged.first`) get an initial value
                    self.reportOfflineNow()
                } else {
                    self.reportOfflineCandidate()
                }
            }
        }

        // Start monitoring - this will immediately call pathUpdateHandler with current state
        monitor?.start(queue: queue)
        
        // Start periodic checks to detect when router loses internet
        startPeriodicCheck()
        
        return nil
    }
    
    private func startPeriodicCheck() {
        stopPeriodicCheck()
        
        periodicCheckTimer = Timer.scheduledTimer(withTimeInterval: PERIODIC_CHECK_INTERVAL, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            guard let path = self.monitor?.currentPath else {
                self.reportOfflineCandidate()
                return
            }

            let pathSaysOnline = (path.status == .satisfied)

            if pathSaysOnline {
                // Don't report online from the path alone here: it can stay satisfied
                // after the router loses upstream internet, and reporting online would
                // reset the offline debounce and mask HTTPS probe failures.
                // The probe result (verifyConnectivityAsync) is authoritative.
                let currentTime = Date().timeIntervalSince1970 * 1000
                if currentTime - self.lastConnectivityTestTime > self.CONNECTIVITY_TEST_CACHE_MS {
                    self.verifyConnectivityAsync()
                }
            } else {
                self.consecutiveHttpsFailures = 0
                self.reportOfflineCandidate()
            }
        }
    }
    
    private func stopPeriodicCheck() {
        periodicCheckTimer?.invalidate()
        periodicCheckTimer = nil
    }
    
    private func verifyConnectivityAsync() {
        let currentTime = Date().timeIntervalSince1970 * 1000
        
        // Check cache
        if currentTime - lastConnectivityTestTime < CONNECTIVITY_TEST_CACHE_MS {
            return
        }
        
        // Test URLs (HTTPS endpoints)
        let testUrls = [
            "https://www.google.com/generate_204",
            "https://connectivitycheck.gstatic.com/generate_204",
            "https://cp.cloudflare.com/generate_204" // Cloudflare fallback (Google-blocked regions)
        ]
        
        // Try each URL sequentially - if any succeeds, we have connectivity
        testConnectivityWithUrls(testUrls, index: 0)
    }
    
    private func testConnectivityWithUrls(_ urls: [String], index: Int) {
        guard index < urls.count else {
            // All URLs failed
            handleHttpsTestResult(success: false)
            return
        }
        
        guard let url = URL(string: urls[index]) else {
            // Invalid URL, try next
            testConnectivityWithUrls(urls, index: index + 1)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = PROBE_TIMEOUT
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let httpResponse = response as? HTTPURLResponse {
                // generate_204 endpoints ALWAYS return 204. Anything else means a
                // captive portal or proxy intercepted the request — not real internet,
                // and it will intercept the remaining URLs too.
                self.handleHttpsTestResult(success: httpResponse.statusCode == 204)
                return
            }

            // No HTTP response (network error) — try next URL
            self.testConnectivityWithUrls(urls, index: index + 1)
        }

        task.resume()
    }

    private func handleHttpsTestResult(success: Bool) {
        lastConnectivityTestTime = Date().timeIntervalSince1970 * 1000

        if success {
            consecutiveHttpsFailures = 0
            reportOnline()
        } else {
            consecutiveHttpsFailures += 1
            reportOfflineCandidate()
        }
    }

    private func reportOnline() {
        pendingOfflineSignals = 0
        emitToFlutter(isOnline: true)
    }

    /// Debounced offline: emit false only after enough independent offline signals.
    private func reportOfflineCandidate() {
        pendingOfflineSignals += 1
        if pendingOfflineSignals >= REQUIRED_OFFLINE_SIGNALS {
            emitToFlutter(isOnline: false)
            pendingOfflineSignals = 0
        }
    }

    /// Immediate offline for unambiguous states (e.g. first path update says offline).
    private func reportOfflineNow() {
        pendingOfflineSignals = 0
        emitToFlutter(isOnline: false)
    }

    private func emitToFlutter(isOnline: Bool) {
        guard let events = eventSink else { return }

        // Dedupe against the last emitted value; a nil lastState (nothing emitted yet)
        // always goes through so listeners get an initial value
        if let last = lastState, isOnline == last {
            return
        }

        lastState = isOnline

        if Thread.isMainThread {
            events(isOnline)
        } else {
            DispatchQueue.main.async {
                events(isOnline)
            }
        }
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        stopPeriodicCheck()
        monitor?.cancel()
        monitor = nil
        lastState = nil
        eventSink = nil
        consecutiveHttpsFailures = 0
        pendingOfflineSignals = 0
        return nil
    }
}