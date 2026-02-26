import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_state.dart';
import '../widgets/digital_card.dart';

/// The Connect tab — shows the user's digital card and a "Scan to Connect" button.
class ConnectTabScreen extends StatelessWidget {
  const ConnectTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: user != null
                        ? DigitalCard(user: user)
                        : const CircularProgressIndicator(),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Scan to Connect button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/connect/scan'),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan to Connect'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
