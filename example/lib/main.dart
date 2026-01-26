import 'package:connectivity_validator_example/network_status_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Best Practice Example: Real-time Connectivity Monitoring
///
/// This example demonstrates:
/// - Proper GetX controller initialization
/// - Real-time connectivity status updates
/// - Error handling
/// - User-friendly UI with status indicators
/// - Last update timestamp
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Best Practice: Initialize controller as permanent (lives for app lifetime)
  // This ensures connectivity monitoring continues throughout the app lifecycle
  Get.put(NetworkStatusController(), permanent: true);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Connectivity Validator Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ConnectivityStatusPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Best Practice: Connectivity Status Page
///
/// Shows real-time connectivity status with:
/// - Visual indicators (icons, colors)
/// - Status messages
/// - Last update timestamp
/// - Error handling display
/// - Manual refresh option
class ConnectivityStatusPage extends StatelessWidget {
  const ConnectivityStatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<NetworkStatusController>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Connectivity Validator'),
        actions: [
          // Manual refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.refresh(),
            tooltip: 'Refresh connectivity status',
          ),
        ],
      ),
      body: Obx(() {
        final isOffline = controller.isOffline.value;
        final hasError = controller.hasError.value;
        final errorMessage = controller.errorMessage.value;
        final lastUpdate = controller.lastUpdateTime.value;

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Status Icon with Animation
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    isOffline ? Icons.wifi_off : Icons.wifi,
                    key: ValueKey(isOffline),
                    size: 120,
                    color: hasError
                        ? Colors.orange
                        : (isOffline ? Colors.red : Colors.green),
                  ),
                ),
                const SizedBox(height: 32),

                // Status Text
                Text(
                  hasError ? 'Error' : (isOffline ? 'Offline' : 'Online'),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: hasError
                        ? Colors.orange
                        : (isOffline ? Colors.red : Colors.green),
                  ),
                ),
                const SizedBox(height: 16),

                // Status Message
                Text(
                  hasError
                      ? errorMessage.isNotEmpty
                            ? errorMessage
                            : 'An error occurred while checking connectivity'
                      : (isOffline
                            ? 'No internet connection or captive portal detected'
                            : 'Internet connection validated and working'),
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Last Update Time
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Last update: ${_formatTime(lastUpdate)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Real-time Indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Real-time monitoring active',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Test Instructions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '💡 Test Real-time Updates',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Disconnect your router\'s internet while WiFi remains connected. The status should update within 1-2 seconds.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 5) {
      return 'Just now';
    } else if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else {
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final second = dateTime.second.toString().padLeft(2, '0');
      return '$hour:$minute:$second';
    }
  }
}
