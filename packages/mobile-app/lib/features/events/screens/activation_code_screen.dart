import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/theme/app_theme.dart';

class ActivationCodeScreen extends StatefulWidget {
  final String eventId;

  const ActivationCodeScreen({super.key, required this.eventId});

  @override
  State<ActivationCodeScreen> createState() => _ActivationCodeScreenState();
}

class _ActivationCodeScreenState extends State<ActivationCodeScreen> {
  final _codeController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _checkIn() async {
    if (_codeController.text.isEmpty) return;

    setState(() => _isSubmitting = true);

    // TODO: Implement check-in API call
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      setState(() => _isSubmitting = false);
      // Show success
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Checked In!'),
          content: const Text('Enjoy the event!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Check In'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.qr_code_scanner,
              size: 80,
              color: AppColors.primary,
            ),
            const SizedBox(height: 24),

            Text(
              'Enter Activation Code',
              style: AppTypography.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Ask venue staff for the activation code',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            TextField(
              controller: _codeController,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              style: AppTypography.headlineMedium.copyWith(
                letterSpacing: 4,
              ),
              decoration: const InputDecoration(
                hintText: 'CODE',
              ),
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isSubmitting ? null : _checkIn,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Check In'),
            ),
          ],
        ),
      ),
    );
  }
}
