import 'package:connectivity_validator_example/network_status_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

void main() async {
  // Don't forget to add this
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
      body: Center(
        child: Obx(() {
          final isOffline = controller.isOffline.value;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isOffline ? Icons.wifi_off : Icons.wifi,
                size: 100,
                color: isOffline ? Colors.red : Colors.green,
              ),
              const SizedBox(height: 20),
              Text(
                isOffline ? 'Offline' : 'Online',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: isOffline ? Colors.red : Colors.green,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isOffline
                    ? 'No internet connection or captive portal detected'
                    : 'Internet connection validated and working',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          );
        }),
      ),
    );
  }
}
