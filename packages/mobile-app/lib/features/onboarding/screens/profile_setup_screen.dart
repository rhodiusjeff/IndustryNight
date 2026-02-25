import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../config/routes.dart';
import '../../../providers/app_state.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/specialty_chip.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _bioController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _nameKey = GlobalKey();
  final _emailKey = GlobalKey();
  final _emailFieldKey = GlobalKey<FormFieldState>();
  final _specialtiesKey = GlobalKey();
  final List<String> _selectedSpecialties = [];
  bool _isSubmitting = false;
  bool _emailTouched = false;

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(() {
      if (!_emailFocusNode.hasFocus && _emailController.text.isNotEmpty) {
        setState(() => _emailTouched = true);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  void _toggleSpecialty(String specialty) {
    setState(() {
      if (_selectedSpecialties.contains(specialty)) {
        _selectedSpecialties.remove(specialty);
      } else {
        _selectedSpecialties.add(specialty);
      }
    });
  }

  void _scrollToKey(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(context,
          duration: const Duration(milliseconds: 300), alignment: 0.3);
    }
  }

  void _showValidationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _saveProfile() async {
    // Run form validation (name, email, bio)
    final formValid = _formKey.currentState!.validate();

    // Check which field is invalid for scroll + snackbar
    if (!formValid) {
      final nameEmpty = _nameController.text.trim().isEmpty;
      final emailInvalid = _emailController.text.trim().isNotEmpty &&
          !isValidEmail(_emailController.text.trim());

      if (nameEmpty) {
        _scrollToKey(_nameKey);
        _showValidationError('Please enter your display name');
      } else if (emailInvalid) {
        _scrollToKey(_emailKey);
        _showValidationError('Please enter a valid email address');
      }
      return;
    }

    if (_selectedSpecialties.isEmpty) {
      _scrollToKey(_specialtiesKey);
      _showValidationError('Please select at least one specialty');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await context.read<AppState>().updateProfile(
            name: _nameController.text,
            email: _emailController.text.isNotEmpty ? _emailController.text : null,
            bio: _bioController.text.isNotEmpty ? _bioController.text : null,
            specialties: _selectedSpecialties,
          );

      if (mounted) {
        context.go(Routes.events);
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
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile photo
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppColors.surfaceLight,
                        child: const Icon(
                          Icons.person,
                          size: 50,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primary,
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt, size: 16),
                            onPressed: () {
                              // TODO: Implement photo picker
                            },
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Name
                Text('Display Name', key: _nameKey, style: AppTypography.titleMedium),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'Your name',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    return validateDisplayName(value);
                  },
                ),

                const SizedBox(height: 24),

                // Email
                Text('Email (optional)', key: _emailKey, style: AppTypography.titleMedium),
                const SizedBox(height: 8),
                TextFormField(
                  key: _emailFieldKey,
                  controller: _emailController,
                  focusNode: _emailFocusNode,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: InputDecoration(
                    hintText: 'you@example.com',
                    suffixIcon: _emailController.text.trim().isEmpty
                        ? null
                        : isValidEmail(_emailController.text.trim())
                            ? const Icon(Icons.check_circle, color: AppColors.success)
                            : _emailTouched
                                ? const Icon(Icons.error, color: AppColors.error)
                                : null,
                  ),
                  onChanged: (_) {
                    // Re-validate to clear error state when email becomes valid
                    if (_emailTouched) {
                      _emailFieldKey.currentState?.validate();
                    }
                    setState(() {});
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return null; // Optional field
                    }
                    if (!isValidEmail(value.trim())) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // Bio
                Text('Bio (optional)', style: AppTypography.titleMedium),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _bioController,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    hintText: 'Tell us about yourself...',
                  ),
                  validator: (value) => validateBio(value),
                ),

                const SizedBox(height: 24),

                // Specialties
                Text('What do you do?', key: _specialtiesKey, style: AppTypography.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Select all that apply',
                  style: AppTypography.bodySmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: Specialty.all.map((specialty) {
                    return SpecialtyChip(
                      specialty: specialty.name,
                      selected: _selectedSpecialties.contains(specialty.id),
                      onTap: () => _toggleSpecialty(specialty.id),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 32),

                // Submit
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _saveProfile,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Complete Setup'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
