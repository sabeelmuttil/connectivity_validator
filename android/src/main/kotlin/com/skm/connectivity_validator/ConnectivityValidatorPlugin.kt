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

class ConnectivityValidatorPlugin : FlutterPlugin, EventChannel.StreamHandler {
    private lateinit var context: Context
    private var eventChannel: EventChannel? = null

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
    
    // Connectivity test timeout (500ms) - fast enough to not block, but reliable
    private val CONNECTIVITY_TEST_TIMEOUT_MS = 500L
    
    // Cache connectivity test results for 500ms to avoid too many HTTP requests
    // But periodic checks always force fresh tests
    private val CONNECTIVITY_TEST_CACHE_MS = 500L
    
    // Track consecutive HTTPS test failures to prevent ping-pong
    // Only override capabilities if we get multiple failures in a row
    private var consecutiveHttpsFailures = 0
    private val REQUIRED_FAILURES_TO_OVERRIDE = 2  // Need 2 failures before overriding capabilities

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        eventChannel = EventChannel(binding.binaryMessenger, "connectivity_validator/status")
        eventChannel?.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        eventChannel?.setStreamHandler(null)
        eventChannel = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.events = events
        
        // 1. Send initial state immediately (non-blocking capability check)
        val network = connectivityManager.activeNetwork
        val caps = network?.let { connectivityManager.getNetworkCapabilities(it) }
        val hasInternet = caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true
        val hasValidated = caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) == true
        val initialCheck = hasInternet && hasValidated
        
        // Send initial state based on capabilities
        // Note: On initial load, we trust capabilities first, then verify with HTTPS
        sendUpdate(events, initialCheck)
        
        // Verify with HTTPS test if capabilities say online
        // This ensures we catch stale VALIDATED flags on initial load
        if (network != null && initialCheck) {
            verifyConnectivityAsync(network, forceFresh = true)
        } else {
            consecutiveHttpsFailures = 0
        }

        // 2. Define the callback
        networkCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                // Network became available - check capabilities immediately (non-blocking)
                val caps = connectivityManager.getNetworkCapabilities(network)
                val hasInternet = caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true
                val hasValidated = caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) == true
                val quickCheck = hasInternet && hasValidated
                
                // If HTTPS test has determined we're offline, don't override with stale capabilities
                if (quickCheck && consecutiveHttpsFailures >= REQUIRED_FAILURES_TO_OVERRIDE) {
                    // Don't send update - keep current OFFLINE state from HTTPS test
                } else {
                    // Send immediate update for responsiveness
                    sendUpdate(events, quickCheck)
                }
                
                // Verify with HTTPS test if capabilities say online
                if (quickCheck) {
                    verifyConnectivityAsync(network, forceFresh = true)
                } else {
                    consecutiveHttpsFailures = 0
                }
                
                // Start periodic checks when network is available
                startPeriodicCheck()
            }

            override fun onLost(network: Network) {
                // Network was lost - immediately check if any other network is available
                val activeNetwork = connectivityManager.activeNetwork
                if (activeNetwork != null) {
                    val caps = connectivityManager.getNetworkCapabilities(activeNetwork)
                    val hasInternet = caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true
                    val hasValidated = caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) == true
                    val quickCheck = hasInternet && hasValidated
                    
                    // Trust Android's validated capabilities
                    sendUpdate(events, quickCheck)
                } else {
                    // No active network, definitely offline
                    sendUpdate(events, false)
                }
                
                // Continue periodic checks to detect if another network takes over
                startPeriodicCheck()
            }

            override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) {
                // Capabilities changed - this is the key callback for validated connectivity
                // Invalidate cache when capabilities change to force fresh connectivity test
                invalidateConnectivityCache()
                
                // For immediate response, check capabilities first (non-blocking)
                val activeNetwork = connectivityManager.activeNetwork
                val capsToCheck = if (network == activeNetwork) caps else {
                    connectivityManager.getNetworkCapabilities(activeNetwork)
                }
                
                // Quick capability check for immediate update (non-blocking)
                val hasInternet = capsToCheck?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true
                val hasValidated = capsToCheck?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) == true
                val quickCheck = hasInternet && hasValidated
                
                // If HTTPS test has determined we're offline, don't override with stale capabilities
                if (quickCheck && consecutiveHttpsFailures >= REQUIRED_FAILURES_TO_OVERRIDE) {
                    // Don't send update - keep current OFFLINE state from HTTPS test
                } else {
                    // Send immediate update based on capabilities for responsiveness
                    sendUpdate(events, quickCheck)
                }
                
                // If capabilities say online, verify with HTTPS test in background
                // This catches cases where VALIDATED flag is stale (router lost internet)
                if (quickCheck && activeNetwork != null) {
                    verifyConnectivityAsync(activeNetwork, forceFresh = true)
                } else {
                    // Capabilities say offline - reset failure counter
                    consecutiveHttpsFailures = 0
                }
                
                // Restart periodic checks after capability change
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
                
                // Send immediate update based on capabilities
                sendUpdate(events, quickCheck)
                
                // Verify with HTTPS test if capabilities say online
                if (quickCheck && activeNetwork != null) {
                    verifyConnectivityAsync(activeNetwork, forceFresh = true)
                } else {
                    consecutiveHttpsFailures = 0
                }
                
                // Restart periodic checks
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
                        // Capabilities say online, but check if HTTPS test has determined we're offline
                        // If we have multiple HTTPS failures, trust HTTPS over stale capabilities
                        if (consecutiveHttpsFailures >= REQUIRED_FAILURES_TO_OVERRIDE) {
                            // HTTPS test says offline - don't override it with stale capabilities
                            // Don't send update - keep current OFFLINE state
                        } else {
                            // No HTTPS failures or only 1 failure - trust capabilities
                            sendUpdate(events, true, force = false)
                        }
                        
                        // Always verify with HTTPS test periodically to catch stale VALIDATED flag
                        // Only verify every 5 seconds to balance accuracy with performance
                        val currentTime = System.currentTimeMillis()
                        if (currentTime - lastConnectivityTestTime > 5000) {
                            invalidateConnectivityCache()
                            verifyConnectivityAsync(network, forceFresh = true)
                        }
                    } else {
                        // No capabilities, definitely offline - send update immediately
                        consecutiveHttpsFailures = 0  // Reset failure counter
                        sendUpdate(events, false, force = true)
                    }
                } else {
                    // No network, offline - send update immediately with force
                    sendUpdate(events, false, force = true)
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
                // Use cached result - but still send update to ensure stream is active
                sendUpdate(events, lastConnectivityTestResult, force = false)
                return
            }
        }
        
                // Run connectivity test in background thread (non-blocking)
        currentConnectivityTest = executor.submit {
            try {
                val result = testActualConnectivity(network)
                lastConnectivityTestTime = System.currentTimeMillis()
                lastConnectivityTestResult = result
                
                val currentState = lastState ?: false
                
                if (result) {
                    // HTTPS test succeeded - reset failure counter and trust it
                    consecutiveHttpsFailures = 0
                    if (!currentState) {
                        // HTTPS says online but we're showing offline - update immediately
                        mainHandler.post {
                            sendUpdate(events, true, force = true)
                        }
                    }
                } else {
                    // HTTPS test failed - increment failure counter
                    consecutiveHttpsFailures++
                    
                    // Only override capabilities if we have multiple consecutive failures
                    // This prevents ping-pong from single test failures
                    if (currentState && consecutiveHttpsFailures >= REQUIRED_FAILURES_TO_OVERRIDE) {
                        mainHandler.post {
                            sendUpdate(events, false, force = true)
                        }
                    }
                }
            } catch (e: Exception) {
                // Test threw exception - treat as failure
                consecutiveHttpsFailures++
                val currentState = lastState ?: false
                
                // Only override if we have multiple consecutive failures
                if (currentState && consecutiveHttpsFailures >= REQUIRED_FAILURES_TO_OVERRIDE) {
                    mainHandler.post {
                        sendUpdate(events, false, force = true)
                    }
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
            connectivityManager.unregisterNetworkCallback(it)
        }
        networkCallback = null
        events = null
    }

    // Helper logic from your image
    private fun sendUpdate(events: EventChannel.EventSink?, isOnline: Boolean, force: Boolean = false) {
        // CRITICAL: Always send updates from periodic checks and HTTP tests (force=true)
        // Only skip if not forced AND state hasn't changed
        if (!force && isOnline == lastState) {
            return
        }
        
        // Update last state
        lastState = isOnline

        // Send immediately on main thread for faster response
        // Using post ensures thread safety without delay
        val sendUpdateAction = Runnable {
            try {
                events?.success(isOnline)
            } catch (e: Exception) {
                // If sending fails, events might be null (stream cancelled)
                // This is normal and can be ignored
            }
        }
        
        if (Looper.myLooper() == Looper.getMainLooper()) {
            // Already on main thread, send immediately
            sendUpdateAction.run()
        } else {
            // Post to main thread
            mainHandler.post(sendUpdateAction)
        }
    }

    private fun isNetworkAvailable(): Boolean {
        val network = connectivityManager.activeNetwork ?: return false
        val caps = connectivityManager.getNetworkCapabilities(network) ?: return false

        // Check for basic internet capability
        if (!caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) {
            return false
        }

        // Check if network has validated connectivity (real internet, not just connection)
        // NET_CAPABILITY_VALIDATED means the network has been validated and can actually reach the internet
        val hasValidated = caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
        
        // If Android says it's validated, perform a quick connectivity test
        // This is critical because Android may cache VALIDATED even when router loses internet
        if (hasValidated) {
            // Use cached result if available and recent (to avoid too many HTTP requests)
            val currentTime = System.currentTimeMillis()
            if (currentTime - lastConnectivityTestTime < CONNECTIVITY_TEST_CACHE_MS) {
                return lastConnectivityTestResult
            }
            
            // Perform actual connectivity test and cache the result
            val result = testActualConnectivity(network)
            lastConnectivityTestTime = currentTime
            lastConnectivityTestResult = result
            return result
        }

        return false
    }
    
    private fun testActualConnectivity(network: Network): Boolean {
        // Test actual connectivity using HTTPS endpoints (required for Android 9+)
        // Android 9+ blocks cleartext HTTP by default, so we use HTTPS
        val testUrls = listOf(
            "https://www.google.com/generate_204",  // Google's HTTPS connectivity check
            "https://connectivitycheck.gstatic.com/generate_204",  // Android's HTTPS connectivity check
            "https://clients3.google.com/generate_204"  // Alternative Google HTTPS endpoint
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
                    
                    // 204 (No Content) is the expected response from generate_204
                    // Any 2xx or 3xx response indicates connectivity
                    if (responseCode == 204 || responseCode in 200..399) {
                        return true
                    }
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