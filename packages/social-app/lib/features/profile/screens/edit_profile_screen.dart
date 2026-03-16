import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../providers/app_state.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/specialty_chip.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _bioController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _emailFieldKey = GlobalKey<FormFieldState>();
  final List<String> _selectedSpecialties = [];
  bool _isSubmitting = false;
  bool _emailTouched = false;

  // Original values for change detection
  String _originalName = '';
  String _originalEmail = '';
  String _originalBio = '';
  List<String> _originalSpecialties = [];

  @override
  void initState() {
    super.initState();
    final user = context.read<AppState>().currentUser;
    if (user != null) {
      _nameController.text = user.name ?? '';
      _emailController.text = user.email ?? '';
      _bioController.text = user.bio ?? '';
      _selectedSpecialties.addAll(user.specialties);

      _originalName = _nameController.text;
      _originalEmail = _emailController.text;
      _originalBio = _bioController.text;
      _originalSpecialties = List.from(user.specialties);
    }
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

  bool get _hasChanges {
    if (_nameController.text != _originalName ||
        _emailController.text != _originalEmail ||
        _bioController.text != _originalBio) {
      return true;
    }
    final sorted = List<String>.from(_selectedSpecialties)..sort();
    final origSorted = List<String>.from(_originalSpecialties)..sort();
    if (sorted.length != origSorted.length) return true;
    for (var i = 0; i < sorted.length; i++) {
      if (sorted[i] != origSorted[i]) return true;
    }
    return false;
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

  Future<bool> _confirmDiscard() async {
    if (!_hasChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
            'You have unsaved changes. Are you sure you want to leave?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _saveProfile() async {
    final formValid = _formKey.currentState!.validate();
    if (!formValid) return;

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
            email: _emailController.text.isNotEmpty
                ? _emailController.text
                : null,
            bio: _bioController.text.isNotEmpty ? _bioController.text : null,
            specialties: _selectedSpecialties,
          );

      if (mounted) {
        Navigator.of(context).pop();
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
    final user = context.watch<AppState>().currentUser;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _confirmDiscard();
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Profile'),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
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
                                backgroundImage: user?.profilePhotoUrl != null
                                    ? NetworkImage(user!.profilePhotoUrl!)
                                    : null,
                                backgroundColor: AppColors.surfaceLight,
                                child: user?.profilePhotoUrl == null
                                    ? Text(
                                        getInitials(user?.name),
                                        style: AppTypography.headlineLarge,
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AppColors.primary,
                                  child: IconButton(
                                    icon: const Icon(Icons.camera_alt, size: 16),
                                    onPressed: null, // photo upload deferred to v1.0
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
                          onChanged: (_) => setState(() {}),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your name';
                            }
                            return validateDisplayName(value);
                          },
                        ),

                        const SizedBox(height: 24),

                        // Email
                        Text('Email (optional)', style: AppTypography.titleMedium),
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
                                    ? const Icon(Icons.check_circle,
                                        color: AppColors.success)
                                    : _emailTouched
                                        ? const Icon(Icons.error,
                                            color: AppColors.error)
                                        : null,
                          ),
                          onChanged: (_) {
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
                          onChanged: (_) => setState(() {}),
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
                          children: Specialty.all.map((specialty) {
                            return SpecialtyChip(
                              specialty: specialty.name,
                              selected:
                                  _selectedSpecialties.contains(specialty.id),
                              onTap: () => _toggleSpecialty(specialty.id),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),

              // Save button pinned at bottom
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _saveProfile,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Changes'),
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
