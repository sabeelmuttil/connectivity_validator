package com.skm.connectivity_validator

import android.content.Context
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Handler
import android.os.Looper
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import java.util.concurrent.Future

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class ConnectivityValidatorPlugin : FlutterPlugin, EventChannel.StreamHandler, MethodChannel.MethodCallHandler {
    private lateinit var context: Context
    private var eventChannel: EventChannel? = null
    private var methodChannel: MethodChannel? = null

    // Logic variables from your image
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private lateinit var connectivityManager: ConnectivityManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private var lastState: Boolean? = null
    private var periodicCheckRunnable: Runnable? = null
    private var events: EventChannel.EventSink? = null
    private var lastConnectivityTestTime: Long = 0
    private var lastConnectivityTestResult: Boolean = false
    private val executor = Executors.newSingleThreadExecutor()
    private var currentConnectivityTest: Future<*>? = null
    
    // Periodic check interval (2 seconds) - balanced for real-time detection without battery drain
    private val PERIODIC_CHECK_INTERVAL_MS = 2000L
    
    // Connectivity test timeout - must cover a full TLS handshake on slow mobile
    // networks; 500ms caused false "offline" results on high-latency connections
    private val CONNECTIVITY_TEST_TIMEOUT_MS = 2000L

    // Cache connectivity test results for 500ms to avoid too many HTTP requests
    // But periodic checks always force fresh tests
    private val CONNECTIVITY_TEST_CACHE_MS = 500L

    /// Require this many separate "offline" signals before emitting false (reduces false offline).
    /// A missing network is emitted immediately; this debounce only applies to ambiguous signals.
    private val REQUIRED_OFFLINE_SIGNALS = 2
    private var pendingOfflineSignals = 0

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        eventChannel = EventChannel(binding.binaryMessenger, "connectivity_validator/status")
        eventChannel?.setStreamHandler(this)
        methodChannel = MethodChannel(binding.binaryMessenger, "connectivity_validator/method")
        methodChannel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // The engine can detach without onCancel being called (e.g. hot restart),
        // so release everything here to avoid leaking the network callback and handler
        onCancel(null)
        eventChannel?.setStreamHandler(null)
        eventChannel = null
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        executor.shutdownNow()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "getStatus") {
            executor.submit {
                try {
                    val isOnline = getCurrentConnectivityStatus()
                    mainHandler.post { result.success(isOnline) }
                } catch (e: Exception) {
                    mainHandler.post { result.error("CHECK_FAILED", e.message, null) }
                }
            }
        } else {
            result.notImplemented()
        }
    }

    /** One-time check: current network capabilities + HTTPS validation. Safe to call without stream. */
    private fun getCurrentConnectivityStatus(): Boolean {
        val network = connectivityManager.activeNetwork ?: return false
        val caps = connectivityManager.getNetworkCapabilities(network) ?: return false
        if (!caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) return false
        if (!caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)) return false
        return testActualConnectivity(network)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        // EventChannel is single-subscription on the native side. Be defensive
        // if a second Dart stream starts before the first one cancels, otherwise
        // the old callback would remain registered and continue probing.
        if (networkCallback != null || this.events != null) {
            onCancel(null)
        }
        this.events = events
        
        // 1. Emit unambiguous offline immediately. An apparent online state is
        // emitted only after the HTTPS probe succeeds.
        val network = connectivityManager.activeNetwork
        val caps = network?.let { connectivityManager.getNetworkCapabilities(it) }
        val hasInternet = caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true
        val hasValidated = caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) == true
        val initialCheck = hasInternet && hasValidated
        
        pendingOfflineSignals = 0
        if (network != null && initialCheck) {
            verifyConnectivityAsync(network, forceFresh = true)
        } else {
            reportOfflineNow(events)
        }

        // 2. Define the callback
        networkCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                // Network became available - check capabilities immediately (non-blocking)
                val caps = connectivityManager.getNetworkCapabilities(network)
                val hasInternet = caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true
                val hasValidated = caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) == true
                val quickCheck = hasInternet && hasValidated
                
                if (quickCheck) {
                    // OS capabilities are only a hint; the probe emits true.
                    verifyConnectivityAsync(network, forceFresh = true)
                } else {
                    reportOfflineCandidate(events)
                }

                // Start periodic checks when network is available
                startPeriodicCheck()
            }

            override fun onLost(network: Network) {
                val activeNetwork = connectivityManager.activeNetwork
                if (activeNetwork != null) {
                    val caps = connectivityManager.getNetworkCapabilities(activeNetwork)
                    val hasInternet = caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true
                    val hasValidated = caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) == true
                    val quickCheck = hasInternet && hasValidated
                    if (quickCheck) {
                        verifyConnectivityAsync(activeNetwork, forceFresh = true)
                    } else {
                        reportOfflineCandidate(events)
                    }
                } else {
                    // No network left at all — unambiguous, skip the debounce
                    reportOfflineNow(events)
                }
                startPeriodicCheck()
            }

            override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) {
                // Capabilities changed - this is the key callback for validated connectivity
                invalidateConnectivityCache()
                
                val activeNetwork = connectivityManager.activeNetwork
                val capsToCheck = if (network == activeNetwork) caps else {
                    connectivityManager.getNetworkCapabilities(activeNetwork)
                }
                
                val hasInternet = capsToCheck?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true
                val hasValidated = capsToCheck?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) == true
                val quickCheck = hasInternet && hasValidated

                if (quickCheck && activeNetwork != null) {
                    verifyConnectivityAsync(activeNetwork, forceFresh = true)
                } else {
                    reportOfflineCandidate(events)
                }

                startPeriodicCheck()
            }

            override fun onLinkPropertiesChanged(network: Network, linkProperties: LinkProperties) {
                // Link properties changed - invalidate cache and recheck connectivity
                invalidateConnectivityCache()
                
                val activeNetwork = connectivityManager.activeNetwork
                val caps = if (network == activeNetwork) {
                    connectivityManager.getNetworkCapabilities(network)
                } else {
                    activeNetwork?.let { connectivityManager.getNetworkCapabilities(it) }
                }
                
                val hasInternet = caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true
                val hasValidated = caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) == true
                val quickCheck = hasInternet && hasValidated

                if (quickCheck && activeNetwork != null) {
                    verifyConnectivityAsync(activeNetwork, forceFresh = true)
                } else {
                    reportOfflineCandidate(events)
                }
                startPeriodicCheck()
            }
        }

        // 3. Register callback (API 24+ compatible per your image usage)
        connectivityManager.registerDefaultNetworkCallback(networkCallback!!)
        
        // 4. Start periodic checks to detect when router loses internet
        // CRITICAL: Always start periodic checks to ensure real-time updates
        startPeriodicCheck()
        
        // Double-check that periodic checks are running (defensive)
        mainHandler.postDelayed({
            if (periodicCheckRunnable == null && events != null) {
                // Periodic check stopped unexpectedly, restart it
                startPeriodicCheck()
            }
        }, PERIODIC_CHECK_INTERVAL_MS * 2)
    }
    
    private fun startPeriodicCheck() {
        // Stop any existing periodic check
        stopPeriodicCheck()
        
        // Create periodic check runnable
        periodicCheckRunnable = object : Runnable {
            override fun run() {
                // Periodically check network state to detect when router loses internet
                // This is important because Android might not immediately update NET_CAPABILITY_VALIDATED
                val network = connectivityManager.activeNetwork
                val caps = network?.let { connectivityManager.getNetworkCapabilities(it) }

                if (network != null && caps != null) {
                    val hasInternet = caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                    val hasValidated = caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)

                    if (hasInternet && hasValidated) {
                        // Don't report online from capabilities alone here: VALIDATED can stay
                        // stale after the router loses upstream internet, and reporting online
                        // would reset the offline debounce and mask HTTPS probe failures.
                        // The probe result (verifyConnectivityAsync) is authoritative.
                        val currentTime = System.currentTimeMillis()
                        if (currentTime - lastConnectivityTestTime > 5000) {
                            invalidateConnectivityCache()
                            verifyConnectivityAsync(network, forceFresh = true)
                        }
                    } else {
                        reportOfflineCandidate(events)
                    }
                } else {
                    // No active network — unambiguous, skip the debounce
                    reportOfflineNow(events)
                }

                // Schedule next check - ensure it always runs
                mainHandler.postDelayed(this, PERIODIC_CHECK_INTERVAL_MS)
            }
        }
        
        // Start periodic checks
        mainHandler.postDelayed(periodicCheckRunnable!!, PERIODIC_CHECK_INTERVAL_MS)
    }
    
    private fun verifyConnectivityAsync(network: Network, forceFresh: Boolean = false) {
        // Cancel any existing connectivity test
        currentConnectivityTest?.cancel(true)
        
        // Check cache first (unless forced fresh)
        if (!forceFresh) {
            val currentTime = System.currentTimeMillis()
            if (currentTime - lastConnectivityTestTime < CONNECTIVITY_TEST_CACHE_MS) {
                // Replay last probe without stacking debounce (avoids cache hammering offline counter).
                emitToFlutter(events, lastConnectivityTestResult, force = false)
                return
            }
        }
        
                // Run connectivity test in background thread (non-blocking)
        currentConnectivityTest = executor.submit {
            try {
                val result = testActualConnectivity(network)
                lastConnectivityTestTime = System.currentTimeMillis()
                lastConnectivityTestResult = result
                
                if (result) {
                    mainHandler.post {
                        reportOnline(events)
                    }
                } else {
                    mainHandler.post {
                        reportOfflineFromProbe(events)
                    }
                }
            } catch (e: Exception) {
                mainHandler.post {
                    reportOfflineFromProbe(events)
                }
            }
        }
    }
    
    private fun invalidateConnectivityCache() {
        // Invalidate cache to force fresh connectivity test
        lastConnectivityTestTime = 0
    }
    
    private fun stopPeriodicCheck() {
        periodicCheckRunnable?.let {
            mainHandler.removeCallbacks(it)
            periodicCheckRunnable = null
        }
    }

    override fun onCancel(arguments: Any?) {
        // Stop periodic checks
        stopPeriodicCheck()

        // Cancel any ongoing connectivity test
        currentConnectivityTest?.cancel(true)
        currentConnectivityTest = null

        // Unregister network callback
        networkCallback?.let {
            try {
                connectivityManager.unregisterNetworkCallback(it)
            } catch (e: Exception) {
                // Already unregistered — ignore
            }
        }
        networkCallback = null
        events = null
        lastState = null
        pendingOfflineSignals = 0
    }

    private fun reportOnline(events: EventChannel.EventSink?) {
        pendingOfflineSignals = 0
        emitToFlutter(events, true)
    }

    /** Debounced offline: emit false only after enough independent offline signals. */
    private fun reportOfflineCandidate(events: EventChannel.EventSink?) {
        pendingOfflineSignals++
        if (pendingOfflineSignals >= REQUIRED_OFFLINE_SIGNALS) {
            emitToFlutter(events, false)
            pendingOfflineSignals = 0
        }
    }

    /** A failed first probe is enough to establish the initial offline state. */
    private fun reportOfflineFromProbe(events: EventChannel.EventSink?) {
        if (lastState == null) {
            reportOfflineNow(events)
        } else {
            reportOfflineCandidate(events)
        }
    }

    /** Immediate offline for unambiguous states (no active network at all). */
    private fun reportOfflineNow(events: EventChannel.EventSink?) {
        pendingOfflineSignals = 0
        emitToFlutter(events, false)
    }

    /** Emit to Flutter; does not touch offline debounce counter (used for initial + cached probe replay). */
    private fun emitToFlutter(events: EventChannel.EventSink?, isOnline: Boolean, force: Boolean = false) {
        if (!force && isOnline == lastState) {
            return
        }

        lastState = isOnline

        val sendUpdateAction = Runnable {
            try {
                events?.success(isOnline)
            } catch (e: Exception) {
                // Stream cancelled — ignore
            }
        }

        if (Looper.myLooper() == Looper.getMainLooper()) {
            sendUpdateAction.run()
        } else {
            mainHandler.post(sendUpdateAction)
        }
    }

    private fun testActualConnectivity(network: Network): Boolean {
        // Test actual connectivity using HTTPS endpoints (required for Android 9+)
        // Android 9+ blocks cleartext HTTP by default, so we use HTTPS.
        // Cloudflare is included as a fallback for regions where Google is blocked.
        val testUrls = listOf(
            "https://www.google.com/generate_204",  // Google's HTTPS connectivity check
            "https://connectivitycheck.gstatic.com/generate_204",  // Android's HTTPS connectivity check
            "https://cp.cloudflare.com/generate_204"  // Cloudflare fallback (Google-blocked regions)
        )
        
        // Try each URL - if any succeeds, we have connectivity
        for (urlString in testUrls) {
            var connection: HttpURLConnection? = null
            try {
                val url = URL(urlString)
                connection = network.openConnection(url) as? HttpURLConnection
                if (connection != null) {
                    connection.connectTimeout = CONNECTIVITY_TEST_TIMEOUT_MS.toInt()
                    connection.readTimeout = CONNECTIVITY_TEST_TIMEOUT_MS.toInt()
                    connection.requestMethod = "HEAD"
                    connection.instanceFollowRedirects = false
                    
                    val responseCode = connection.responseCode

                    // generate_204 endpoints always return 204 when reachable.
                    if (responseCode == 204) {
                        return true
                    }
                    // Redirects with redirect-following disabled are a strong captive
                    // portal signal. Other HTTP errors can be endpoint-specific (for
                    // example, a corporate proxy blocks Google), so try the fallback.
                    if (responseCode in 300..399) {
                        return false
                    }
                    continue
                }
            } catch (e: java.net.SocketTimeoutException) {
                // Timeout - try next URL
                continue
            } catch (e: java.net.UnknownHostException) {
                // Cannot resolve host - try next URL
                continue
            } catch (e: java.io.IOException) {
                // IO error - try next URL
                continue
            } catch (e: Exception) {
                // Any other exception - try next URL
                continue
            } finally {
                // Always disconnect to free resources
                try {
                    connection?.disconnect()
                } catch (e: Exception) {
                    // Ignore disconnect errors
                }
            }
        }
        
        // All URLs failed - no connectivity
        return false
    }
}
