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
  final _bioController = TextEditingController();
  final List<String> _selectedSpecialties = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSpecialties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one specialty')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await context.read<AppState>().updateProfile(
            name: _nameController.text,
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
                Text('Display Name', style: AppTypography.titleMedium),
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
                Text('What do you do?', style: AppTypography.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Select all that apply',
                  style: AppTypography.bodySmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: specialtyDisplayNames.map((specialty) {
                    return SpecialtyChip(
                      specialty: specialty,
                      selected: _selectedSpecialties.contains(specialty),
                      onTap: () => _toggleSpecialty(specialty),
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
