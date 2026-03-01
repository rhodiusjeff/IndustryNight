import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../providers/app_state.dart';
import '../../../shared/theme/app_theme.dart';
import '../networking_state.dart';
import '../widgets/new_connection_overlay.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    final value = barcode!.rawValue!;
    if (!value.startsWith('industrynight://connect/')) return;

    final userId = value.replaceFirst('industrynight://connect/', '');
    if (userId.isEmpty) return;

    // Self-scan check
    final currentUserId = context.read<AppState>().currentUser?.id;
    if (userId == currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You scanned your own code!')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    final networkingState = context.read<NetworkingState>();
    final appState = context.read<AppState>();

    try {
      // Instant connection — no confirmation step
      final result = await networkingState.createConnection(value);
      if (!mounted) return;

      final connection = result?.connection;
      final justVerified = result?.justVerified ?? false;

      if (justVerified) {
        appState.setVerified();
      }

      // Get the other user from the enriched connection response
      final otherUser = connection?.getOtherUser(networkingState.currentUserId);

      if (otherUser != null) {
        // Show celebration overlay
        await showGeneralDialog(
          context: context,
          barrierDismissible: true,
          barrierLabel: 'Dismiss',
          barrierColor: Colors.transparent,
          pageBuilder: (dialogContext, _, __) {
            return NewConnectionOverlay(
              otherUser: otherUser,
              justVerified: justVerified,
              onDismiss: () => Navigator.of(dialogContext).pop(),
            );
          },
        );
      }

      // Pop scanner back to Connect tab
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 409) {
        // Show dialog and pop back — don't resume scanning (causes loop)
        await showDialog(
          context: context,
          barrierDismissible: true,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.people, size: 40, color: AppColors.primary),
            title: const Text('Already Connected'),
            content: const Text(
              'You are already connected with this person.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        if (mounted) Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection failed. Please try again.')),
      );
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_off),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Overlay with scanning frame
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          // Instructions
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Text(
              'Point the camera at a QR code',
              style: AppTypography.bodyLarge.copyWith(
                color: Colors.white,
                shadows: [
                  const Shadow(blurRadius: 4, color: Colors.black),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Processing indicator
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
