import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'network_status_controller.dart';

/// Example: both live (stream) and on-demand (button) connectivity.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

class ConnectivityStatusPage extends StatelessWidget {
  const ConnectivityStatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<NetworkStatusController>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Connectivity Validator'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              _LiveSection(controller: controller),
              const SizedBox(height: 32),
              _ManualSection(controller: controller),
            ],
          ),
        ),
      ),
    );
  }
}

/// Live status from stream (updates automatically).
class _LiveSection extends StatelessWidget {
  const _LiveSection({required this.controller});

  final NetworkStatusController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Obx(() {
          final isOffline = controller.liveIsOffline.value;
          final hasError = controller.liveHasError.value;
          final errorMessage = controller.liveErrorMessage.value;
          final lastUpdate = controller.liveLastUpdateTime.value;

          return Column(
            children: [
              Row(
                children: [
                  Icon(Icons.live_tv, size: 20, color: Colors.grey[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Live status',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  _statusChip(isOffline, hasError),
                ],
              ),
              const SizedBox(height: 16),
              Icon(
                isOffline ? Icons.wifi_off : Icons.wifi,
                size: 64,
                color: hasError
                    ? Colors.orange
                    : (isOffline ? Colors.red : Colors.green),
              ),
              const SizedBox(height: 8),
              Text(
                hasError
                    ? (errorMessage.isNotEmpty ? errorMessage : 'Error')
                    : (isOffline ? 'Offline' : 'Online'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: hasError
                      ? Colors.orange
                      : (isOffline ? Colors.red : Colors.green),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Updates automatically from stream',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Last update: ${_formatTime(lastUpdate)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _statusChip(bool isOffline, bool hasError) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: hasError
            ? Colors.orange
            : (isOffline ? Colors.red : Colors.green).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        hasError ? 'Error' : (isOffline ? 'Offline' : 'Online'),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: hasError
              ? Colors.orange
              : (isOffline ? Colors.red : Colors.green),
        ),
      ),
    );
  }
}

/// Manual check on button tap.
class _ManualSection extends StatelessWidget {
  const _ManualSection({required this.controller});

  final NetworkStatusController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Obx(() {
          final isOffline = controller.isOffline.value;
          final hasError = controller.hasError.value;
          final errorMessage = controller.errorMessage.value;
          final lastUpdate = controller.lastUpdateTime.value;
          final isChecking = controller.isChecking.value;
          final didCheck = controller.hasChecked.value;

          return Column(
            children: [
              Row(
                children: [
                  Icon(Icons.touch_app, size: 20, color: Colors.grey[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Manual check',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!didCheck && !isChecking)
                Text(
                  'Tap the button to check connectivity once.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                )
              else ...[
                Icon(
                  isChecking
                      ? Icons.sync
                      : (isOffline ? Icons.wifi_off : Icons.wifi),
                  size: 64,
                  color: isChecking
                      ? Colors.grey
                      : (hasError
                            ? Colors.orange
                            : (isOffline ? Colors.red : Colors.green)),
                ),
                const SizedBox(height: 8),
                Text(
                  isChecking
                      ? 'Checking...'
                      : (hasError
                            ? (errorMessage.isNotEmpty ? errorMessage : 'Error')
                            : (isOffline ? 'Offline' : 'Online')),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isChecking
                        ? Colors.grey
                        : (hasError
                              ? Colors.orange
                              : (isOffline ? Colors.red : Colors.green)),
                  ),
                  textAlign: TextAlign.center,
                ),
                if (!isChecking && didCheck) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Last check: ${_formatTime(lastUpdate)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: isChecking ? null : () => controller.checkNow(),
                icon: isChecking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_find),
                label: Text(isChecking ? 'Checking...' : 'Check network'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 24,
                  ),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
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
