import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../config/routes.dart';
import '../../../shared/theme/app_theme.dart';

class NotRegisteredScreen extends StatelessWidget {
  const NotRegisteredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.person_off,
                size: 80,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 24),

              Text(
                'Not Registered',
                style: AppTypography.headlineLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'This phone number is not associated with an Industry Night account. '
                'You need to purchase a ticket to an event to join.',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: () {
                  // Open ticket purchase link
                },
                child: const Text('Find Events'),
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: () => context.go(Routes.phoneEntry),
                child: const Text('Try a different number'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
