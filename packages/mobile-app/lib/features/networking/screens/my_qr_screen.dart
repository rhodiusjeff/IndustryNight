import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../providers/app_state.dart';
import '../../../shared/theme/app_theme.dart';

class MyQrScreen extends StatelessWidget {
  const MyQrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Network'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () => context.push('/networking/connections'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // QR Code
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    QrImageView(
                      data: 'industrynight://connect/${user?.id ?? 'unknown'}',
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user?.name ?? 'Your Name',
                      style: AppTypography.titleLarge,
                    ),
                    if (user?.specialties.isNotEmpty ?? false) ...[
                      const SizedBox(height: 4),
                      Text(
                        user!.specialties.take(2).join(' • '),
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Text(
              'Show this QR code to connect',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),

            const Spacer(),

            // Scan button
            ElevatedButton.icon(
              onPressed: () => context.push('/networking/scan'),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan to Connect'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
