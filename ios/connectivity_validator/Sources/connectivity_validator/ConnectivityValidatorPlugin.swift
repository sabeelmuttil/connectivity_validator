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
                "https://clients3.google.com/generate_204"
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
        request.timeoutInterval = 0.5
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let task = URLSession.shared.dataTask(with: request) { _, response, _ in
            if let http = response as? HTTPURLResponse, (http.statusCode == 204 || (200..<400).contains(http.statusCode)) {
                completion(true)
                return
            }
            self.testConnectivityOneShot(urls: urls, index: index + 1, completion: completion)
        }
        task.resume()
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        
        // Monitor all network interfaces (WiFi, cellular, etc.)
        // This ensures we detect changes when WiFi loses internet but remains connected
        monitor = NWPathMonitor()

        monitor?.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            // .satisfied means internet is validated (past captive portals)
            // However, this can be stale when router loses internet but WiFi stays connected
            let pathSaysOnline = (path.status == .satisfied)
            
            // If HTTPS test has determined we're offline, don't override with stale path status
            if pathSaysOnline && self.consecutiveHttpsFailures >= self.REQUIRED_FAILURES_TO_OVERRIDE {
                // Don't send update - keep current OFFLINE state from HTTPS test
                return
            }
            
            // Send immediate update based on path status for responsiveness
            if pathSaysOnline != self.lastState {
                self.lastState = pathSaysOnline
                
                // Send immediately on main thread for faster response
                if Thread.isMainThread {
                    events(pathSaysOnline)
                } else {
                    DispatchQueue.main.async {
                        events(pathSaysOnline)
                    }
                }
            }
            
            // If path says online, verify with HTTPS test in background
            // This catches cases where path.status is stale (router lost internet)
            if pathSaysOnline {
                self.verifyConnectivityAsync()
            } else {
                // Path says offline - reset failure counter
                self.consecutiveHttpsFailures = 0
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
            
            // Check current path status
            guard let path = self.monitor?.currentPath else {
                // No path - definitely offline
                if self.lastState != false {
                    self.lastState = false
                    self.sendUpdate(isOnline: false, force: true)
                }
                return
            }
            
            let pathSaysOnline = (path.status == .satisfied)
            
            if pathSaysOnline {
                // Path says online, but check if HTTPS test has determined we're offline
                if self.consecutiveHttpsFailures >= self.REQUIRED_FAILURES_TO_OVERRIDE {
                    // Don't send update - keep current OFFLINE state
                } else {
                    // No HTTPS failures or only 1 failure - trust path status
                    if self.lastState != true {
                        self.lastState = true
                        self.sendUpdate(isOnline: true, force: false)
                    }
                }
                
                // Verify with HTTPS test periodically
                let currentTime = Date().timeIntervalSince1970 * 1000
                if currentTime - self.lastConnectivityTestTime > self.CONNECTIVITY_TEST_CACHE_MS {
                    self.verifyConnectivityAsync()
                }
            } else {
                // Path says offline - reset failure counter and send update
                self.consecutiveHttpsFailures = 0
                if self.lastState != false {
                    self.lastState = false
                    self.sendUpdate(isOnline: false, force: true)
                }
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
            "https://clients3.google.com/generate_204"
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
        request.timeoutInterval = 0.5
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let httpResponse = response as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                if statusCode == 204 || (statusCode >= 200 && statusCode < 400) {
                    // Success - we have connectivity
                    self.handleHttpsTestResult(success: true)
                    return
                }
            }
            
            // This URL failed, try next
            self.testConnectivityWithUrls(urls, index: index + 1)
        }
        
        task.resume()
    }
    
    private func handleHttpsTestResult(success: Bool) {
        lastConnectivityTestTime = Date().timeIntervalSince1970 * 1000
        
        let currentState = lastState ?? false
        
        if success {
            // HTTPS test succeeded - reset failure counter
            consecutiveHttpsFailures = 0
            
            if !currentState {
                // HTTPS says online but we're showing offline - update immediately
                lastState = true
                sendUpdate(isOnline: true, force: true)
            }
        } else {
            // HTTPS test failed - increment failure counter
            consecutiveHttpsFailures += 1
            
            // Only override path status if we have multiple consecutive failures
            if currentState && consecutiveHttpsFailures >= REQUIRED_FAILURES_TO_OVERRIDE {
                lastState = false
                sendUpdate(isOnline: false, force: true)
            }
        }
    }
    
    private func sendUpdate(isOnline: Bool, force: Bool) {
        guard let events = eventSink else { return }
        
        // Only skip if not forced AND state hasn't changed
        if !force && isOnline == (lastState ?? false) {
            return
        }
        
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
        return nil
    }
}