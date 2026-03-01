import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/specialty_chip.dart';

/// Full-screen celebration overlay shown when a QR connection is made.
/// Used by both the scanner (instant feedback) and the scanned user (poll detection).
class NewConnectionOverlay extends StatefulWidget {
  final User otherUser;
  final bool justVerified;
  final VoidCallback onDismiss;

  const NewConnectionOverlay({
    super.key,
    required this.otherUser,
    required this.justVerified,
    required this.onDismiss,
  });

  @override
  State<NewConnectionOverlay> createState() => _NewConnectionOverlayState();
}

class _NewConnectionOverlayState extends State<NewConnectionOverlay>
    with SingleTickerProviderStateMixin {
  late final ConfettiController _confettiController;
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );

    _confettiController.play();
    _animController.forward();

    // Auto-dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.otherUser;
    final firstName = user.name?.split(' ').first ?? 'Someone';

    return Material(
      color: Colors.black87,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Tappable background to dismiss
          GestureDetector(
            onTap: widget.onDismiss,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox.expand(),
          ),

          // Celebration card
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'New Connection!',
                    style: AppTypography.headlineLarge.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Avatar
                  CircleAvatar(
                    radius: 48,
                    backgroundImage: user.profilePhotoUrl != null
                        ? NetworkImage(user.profilePhotoUrl!)
                        : null,
                    backgroundColor: AppColors.surfaceLight,
                    child: user.profilePhotoUrl == null
                        ? Text(
                            getInitials(user.name),
                            style: AppTypography.displayMedium,
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Name
                  Text(
                    '$firstName connected with you',
                    style: AppTypography.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Specialties
                  if (user.specialties.isNotEmpty) ...[
                    SpecialtyChipList(
                      specialties: user.specialties
                          .take(3)
                          .map((id) => Specialty.fromId(id)?.name ?? id)
                          .toList(),
                      wrap: false,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Verification celebration
                  if (widget.justVerified) ...[
                    const Divider(),
                    const SizedBox(height: 12),
                    const Icon(Icons.verified, color: Colors.amber, size: 36),
                    const SizedBox(height: 8),
                    Text(
                      "You're Verified!",
                      style: AppTypography.headlineMedium.copyWith(
                        color: Colors.amber,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your first connection verified your profile',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                  ],

                  Text(
                    'Tap anywhere to continue',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Confetti from top
          Positioned(
            top: 0,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2,
              emissionFrequency: 0.05,
              numberOfParticles: 25,
              maxBlastForce: 20,
              minBlastForce: 5,
              gravity: 0.3,
              colors: const [
                Colors.amber,
                Colors.purple,
                Colors.pink,
                Colors.blue,
                Colors.orange,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
