import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../providers/app_state.dart';
import '../../../shared/theme/app_theme.dart';

class ActivationCodeScreen extends StatefulWidget {
  final String eventId;
  final String? eventName;
  final DateTime? eventEndTime;

  const ActivationCodeScreen({
    super.key,
    required this.eventId,
    this.eventName,
    this.eventEndTime,
  });

  @override
  State<ActivationCodeScreen> createState() => _ActivationCodeScreenState();
}

class _ActivationCodeScreenState extends State<ActivationCodeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _codeController = TextEditingController();
  MobileScannerController? _scannerController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scannerController = MobileScannerController();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 0) {
      _scannerController?.start();
    } else {
      _scannerController?.stop();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _codeController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  // ── QR detection ──────────────────────────────────────────

  void _onDetect(BarcodeCapture capture) {
    if (_isSubmitting) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    final value = barcode!.rawValue!;

    // Expected: industrynight://checkin/{eventId}/{activationCode}
    if (!value.startsWith('industrynight://checkin/')) return;

    final parts = value.replaceFirst('industrynight://checkin/', '').split('/');
    if (parts.length != 2) return;

    final scannedEventId = parts[0];
    final scannedCode = parts[1];

    if (scannedEventId != widget.eventId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This QR code is for a different event')),
      );
      return;
    }

    _checkIn(scannedCode);
  }

  // ── Shared check-in logic ─────────────────────────────────

  Future<void> _checkIn(String code) async {
    if (code.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final appState = context.read<AppState>();
      final checkedInTicket = await appState.eventsApi.checkIn(widget.eventId, code);

      // NOTE: Do NOT call appState.setActiveEvent() here.
      // It triggers notifyListeners() which fires GoRouter's refreshListenable,
      // potentially orphaning the push<Ticket> future on the EventDetailScreen.
      // EventDetailScreen handles setActiveEvent after the pop completes.

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Checked In!'),
          content: const Text('Enjoy the event!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      context.pop(checkedInTicket);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check-in failed. Please try again.')),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Check In'),
        actions: [
          if (_tabController.index == 0 && _scannerController != null)
            IconButton(
              icon: const Icon(Icons.flash_on),
              tooltip: 'Toggle flashlight',
              onPressed: () => _scannerController!.toggleTorch(),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'Scan QR'),
            Tab(icon: Icon(Icons.dialpad), text: 'Enter Code'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildScanTab(),
          _buildCodeTab(),
        ],
      ),
    );
  }

  // ── Scan QR tab ───────────────────────────────────────────

  Widget _buildScanTab() {
    return Stack(
      children: [
        if (_scannerController != null)
          MobileScanner(
            controller: _scannerController!,
            onDetect: _onDetect,
          ),

        // Scanning frame overlay
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
            'Scan the venue QR code to check in',
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
        if (_isSubmitting)
          Container(
            color: Colors.black54,
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  // ── Enter Code tab ────────────────────────────────────────

  Widget _buildCodeTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          const Icon(
            Icons.dialpad,
            size: 64,
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
            'Ask venue staff for the 4-digit code',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _codeController,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 4,
            style: AppTypography.headlineMedium.copyWith(
              letterSpacing: 8,
            ),
            decoration: const InputDecoration(
              hintText: '0000',
              counterText: '',
            ),
            onChanged: (value) {
              if (value.length == 4) {
                _checkIn(value.trim());
              }
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSubmitting ? null : () => _checkIn(_codeController.text.trim()),
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
    );
  }
}
