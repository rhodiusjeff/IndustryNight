import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_state.dart';
import '../../../shared/theme/app_theme.dart';
import '../networking_state.dart';
import '../widgets/scanned_user_sheet.dart';

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
    final user = await networkingState.lookupScannedUser(userId);

    if (!mounted) return;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(networkingState.error ?? 'User not found'),
        ),
      );
      setState(() => _isProcessing = false);
      return;
    }

    // Show profile preview bottom sheet
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => ChangeNotifierProvider.value(
        value: networkingState,
        child: ScannedUserSheet(
          user: user,
          qrData: value,
          onConnected: () {
            Navigator.of(sheetContext).pop(true);
          },
        ),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      // Connection was made — pop scanner back to Connect tab
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected with ${user.name ?? 'user'}!'),
        ),
      );
      Navigator.of(context).pop();
    } else {
      // Sheet dismissed without connecting — resume scanning
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
