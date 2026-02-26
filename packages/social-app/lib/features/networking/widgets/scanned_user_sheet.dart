import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/specialty_chip.dart';
import '../../../shared/widgets/verified_badge.dart';
import '../networking_state.dart';

/// Modal bottom sheet shown after scanning a user's QR code.
/// Displays their profile and a "Connect" button.
class ScannedUserSheet extends StatefulWidget {
  final User user;
  final String qrData;
  final VoidCallback onConnected;

  const ScannedUserSheet({
    super.key,
    required this.user,
    required this.qrData,
    required this.onConnected,
  });

  @override
  State<ScannedUserSheet> createState() => _ScannedUserSheetState();
}

class _ScannedUserSheetState extends State<ScannedUserSheet> {
  bool _isConnecting = false;
  bool _alreadyConnected = false;
  String? _errorMessage;

  Future<void> _connect() async {
    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    try {
      await context.read<NetworkingState>().createConnection(widget.qrData);
      if (mounted) {
        widget.onConnected();
      }
    } on ApiException catch (e) {
      if (mounted) {
        if (e.statusCode == 409) {
          setState(() {
            _alreadyConnected = true;
            _isConnecting = false;
          });
        } else {
          setState(() {
            _errorMessage = e.message;
            _isConnecting = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isConnecting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final firstName = user.name?.split(' ').first ?? 'this person';

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 24),

          // Avatar
          CircleAvatar(
            radius: 40,
            backgroundImage: user.profilePhotoUrl != null
                ? NetworkImage(user.profilePhotoUrl!)
                : null,
            backgroundColor: AppColors.surfaceLight,
            child: user.profilePhotoUrl == null
                ? Text(
                    getInitials(user.name),
                    style: AppTypography.headlineMedium,
                  )
                : null,
          ),

          const SizedBox(height: 16),

          // Name + badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  user.name ?? 'Unknown',
                  style: AppTypography.headlineMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              VerifiedBadge(status: user.verificationStatus, size: 20),
            ],
          ),

          const SizedBox(height: 8),

          // Specialties
          if (user.specialties.isNotEmpty)
            SpecialtyChipList(
              specialties: user.specialties
                  .take(3)
                  .map((id) => Specialty.fromId(id)?.name ?? id)
                  .toList(),
              wrap: false,
            ),

          // Bio
          if (user.bio != null) ...[
            const SizedBox(height: 12),
            Text(
              user.bio!,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 24),

          // Error message
          if (_errorMessage != null) ...[
            Text(
              _errorMessage!,
              style: AppTypography.bodySmall.copyWith(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
          ],

          // Already connected message
          if (_alreadyConnected) ...[
            Text(
              'Already connected with $firstName',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/users/${user.id}');
                },
                child: const Text('View Profile'),
              ),
            ),
          ] else ...[
            // Connect button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isConnecting ? null : _connect,
                child: _isConnecting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('Connect with $firstName'),
              ),
            ),
          ],

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
