import Flutter
import UIKit
import Network

public class ConnectivityValidatorPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var monitor: NWPathMonitor?
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var lastState: Bool? = nil
    private var eventSink: FlutterEventSink?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterEventChannel(name: "connectivity_validator/status", binaryMessenger: registrar.messenger())
        let instance = ConnectivityValidatorPlugin()
        channel.setStreamHandler(instance)
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        monitor = NWPathMonitor()

        monitor?.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            // .satisfied means internet is validated (past captive portals)
            let isOnline = (path.status == .satisfied)

            // Optimization: Only send if state changed
            if isOnline != self.lastState {
                self.lastState = isOnline

                // Native updates happen on background queue; send to Flutter on Main Thread
                DispatchQueue.main.async {
                    events(isOnline)
                }
            }
        }

        monitor?.start(queue: queue)
        
        // Send initial state after starting monitor (first update will come immediately)
        // The pathUpdateHandler will be called with the current state when monitor starts
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        monitor?.cancel()
        monitor = nil
        lastState = nil
        eventSink = nil
        return nil
    }
}