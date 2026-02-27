import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../config/routes.dart';
import '../../../providers/app_state.dart';
import '../../../shared/theme/app_theme.dart';

class PhoneEntryScreen extends StatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  State<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends State<PhoneEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isSubmitting = false;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedPhone();
  }

  Future<void> _loadRememberedPhone() async {
    final storage = SecureStorage();
    final phone = await storage.getRememberedPhone();
    if (mounted && phone != null) {
      setState(() {
        _phoneController.text = phone;
        _rememberMe = true;
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submitPhone() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      // Save or clear remembered phone
      final storage = SecureStorage();
      if (_rememberMe) {
        await storage.saveRememberedPhone(_phoneController.text);
      } else {
        await storage.clearRememberedPhone();
      }

      final appState = context.read<AppState>();
      final devCode = await appState.requestVerificationCode(
            _phoneController.text,
          );

      if (mounted) {
        context.push(Routes.smsVerify, extra: {
          'phone': _phoneController.text,
          'devCode': devCode,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),

                // Logo
                Image.asset(
                  'assets/images/logo_white.png',
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 8),
                Text(
                  'Connect with creative professionals',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const Spacer(),

                // Phone input
                Text(
                  'Enter your phone number',
                  style: AppTypography.titleMedium,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  decoration: const InputDecoration(
                    hintText: '(555) 555-5555',
                    prefixIcon: Icon(Icons.phone),
                    prefixText: '+1 ',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    if (!isValidPhoneNumber(value)) {
                      return 'Please enter a valid phone number';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 8),

                // Remember me checkbox
                Row(
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _rememberMe,
                        onChanged: (value) {
                          setState(() => _rememberMe = value ?? false);
                        },
                        activeColor: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _rememberMe = !_rememberMe),
                      child: Text(
                        'Remember me',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Submit button
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitPhone,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Continue'),
                ),

                const SizedBox(height: 16),

                // Terms
                Text(
                  'By continuing, you agree to our Terms of Service and Privacy Policy',
                  style: AppTypography.bodySmall,
                  textAlign: TextAlign.center,
                ),

                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
