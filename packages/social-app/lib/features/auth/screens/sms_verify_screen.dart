import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../config/routes.dart';
import '../../../providers/app_state.dart';
import '../../../shared/theme/app_theme.dart';

class SmsVerifyScreen extends StatefulWidget {
  final String phone;
  final String? devCode;

  const SmsVerifyScreen({super.key, required this.phone, this.devCode});

  @override
  State<SmsVerifyScreen> createState() => _SmsVerifyScreenState();
}

class _SmsVerifyScreenState extends State<SmsVerifyScreen> {
  final _codeController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Auto-fill only when API explicitly returns a devCode in fallback mode.
    if (widget.devCode != null) {
      _codeController.text = widget.devCode!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _verifyCode());
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.length != 6) return;

    setState(() => _isSubmitting = true);

    final success = await context.read<AppState>().verifyCode(
          widget.phone,
          _codeController.text,
        );

    if (mounted) {
      setState(() => _isSubmitting = false);

      if (success) {
        // Router will handle redirect based on auth state
        context.go(Routes.events);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.read<AppState>().error ?? 'Invalid code'),
          ),
        );
      }
    }
  }

  Future<void> _resendCode() async {
    try {
      final devCode =
          await context.read<AppState>().requestVerificationCode(widget.phone);
      if (mounted) {
        if (devCode != null) {
          _codeController.text = devCode;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Code sent!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),

              Text(
                'Enter verification code',
                style: AppTypography.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'We sent a 6-digit code to ${widget.phone}',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Code expires in 10 minutes',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),

              // Dev mode indicator
              if (widget.devCode != null) ...[
                const SizedBox(height: 8),
                Text(
                  'DEV MODE — code auto-filled',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 32),

              // Code input
              TextFormField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: AppTypography.headlineLarge.copyWith(
                  letterSpacing: 8,
                ),
                decoration: const InputDecoration(
                  hintText: '000000',
                  counterText: '',
                ),
                onChanged: (value) {
                  if (value.length == 6) {
                    _verifyCode();
                  }
                },
              ),

              const SizedBox(height: 24),

              // Verify button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _verifyCode,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Verify'),
              ),

              const SizedBox(height: 16),

              // Resend
              TextButton(
                onPressed: _resendCode,
                child: const Text("Didn't receive a code? Resend"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
