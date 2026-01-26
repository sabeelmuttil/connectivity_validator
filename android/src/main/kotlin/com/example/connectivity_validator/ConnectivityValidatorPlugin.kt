package com.example.connectivity_validator

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Handler
import android.os.Looper

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
        // 1. Send initial state immediately
        sendUpdate(events, isNetworkAvailable())

        // 2. Define the callback
        networkCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onLost(network: Network) {
                sendUpdate(events, false)
            }

            override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) {
                val isRealInternet = caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
                        caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
                sendUpdate(events, isRealInternet)
            }
        }

        // 3. Register callback (API 24+ compatible per your image usage)
        connectivityManager.registerDefaultNetworkCallback(networkCallback!!)
    }

    override fun onCancel(arguments: Any?) {
        networkCallback?.let {
            connectivityManager.unregisterNetworkCallback(it)
        }
        networkCallback = null
    }

    // Helper logic from your image
    private fun sendUpdate(events: EventChannel.EventSink?, isOnline: Boolean) {
        // Optimization: Only send if value actually changed
        if (isOnline == lastState) return
        lastState = isOnline

        // Ensure we send on Main Thread
        mainHandler.post {
            events?.success(isOnline)
        }
    }

    private fun isNetworkAvailable(): Boolean {
        val network = connectivityManager.activeNetwork ?: return false
        val caps = connectivityManager.getNetworkCapabilities(network) ?: return false

        return caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
                caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
    }
}