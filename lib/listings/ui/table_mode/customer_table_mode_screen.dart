import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:caribtap/core/model/user.dart';
import 'package:caribtap/core/ui/loading/loading_cubit.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/listings_app_config.dart';
import 'package:caribtap/listings/api/firebase/table_mode_firebase.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/table_mode_models.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class CustomerTableModeScreen extends StatefulWidget {
  final ListingModel listing;
  final User currentUser;

  const CustomerTableModeScreen({
    super.key,
    required this.listing,
    required this.currentUser,
  });

  @override
  State<CustomerTableModeScreen> createState() => _CustomerTableModeScreenState();
}

class _CustomerTableModeScreenState extends State<CustomerTableModeScreen> {
  final _tableCodeController = TextEditingController();
  final _repository = tableModeRepository;

  TableSessionModel? _activeSession;
  StreamSubscription? _sessionSubscription;
  Timer? _cooldownTimer;
  int _remainingCooldownSeconds = 0;
  bool _isScanning = false;
  MobileScannerController? _scannerController;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  @override
  void dispose() {
    _tableCodeController.dispose();
    _sessionSubscription?.cancel();
    _cooldownTimer?.cancel();
    _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _checkExistingSession() async {
    try {
      final session = await _repository.getCustomerActiveSession(
        listingId: widget.listing.id,
        customerUid: widget.currentUser.userID,
      );

      if (session != null && mounted) {
        setState(() {
          _activeSession = session;
        });
        _startSessionStream(session.sessionId);
        _startCooldownTimer();
      }
    } catch (e) {
      debugPrint('Check existing session error: $e');
    }
  }

  void _startSessionStream(String sessionId) {
    _sessionSubscription?.cancel();
    _sessionSubscription = _repository.streamTableSession(sessionId: sessionId).listen(
      (session) {
        if (mounted) {
          setState(() {
            _activeSession = session;
          });
          _startCooldownTimer();
        }
      },
      onError: (e) {
        debugPrint('Session stream error: $e');
      },
    );
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    if (_activeSession == null || !_activeSession!.isSummonOnCooldown) {
      setState(() {
        _remainingCooldownSeconds = 0;
      });
      return;
    }

    setState(() {
      _remainingCooldownSeconds = _activeSession!.remainingSummonCooldownSeconds;
    });

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_activeSession == null || !_activeSession!.isSummonOnCooldown) {
        setState(() {
          _remainingCooldownSeconds = 0;
        });
        timer.cancel();
        return;
      }

      setState(() {
        _remainingCooldownSeconds = _activeSession!.remainingSummonCooldownSeconds;
      });
    });
  }

  Future<void> _scanQRCode() async {
    setState(() {
      _isScanning = true;
    });
  }

  void _stopScanning() {
    setState(() {
      _isScanning = false;
    });
    _scannerController?.stop();
  }

  Future<void> _handleQRScanned(String qrData) async {
    _stopScanning();

    // Parse QR: caribtap://table?listingId=<listingId>&tableId=<tableId>&secret=<secret>
    try {
      final uri = Uri.parse(qrData);
      if (uri.scheme != 'caribtap' || uri.host != 'table') {
        showSnackBar(context, 'Invalid QR code'.tr());
        return;
      }

      final listingId = uri.queryParameters['listingId'];
      final tableId = uri.queryParameters['tableId'];
      final secret = uri.queryParameters['secret'];

      if (listingId != widget.listing.id) {
        showSnackBar(context, 'This QR code is for a different restaurant'.tr());
        return;
      }

      if (tableId == null || secret == null) {
        showSnackBar(context, 'Invalid QR code data'.tr());
        return;
      }

      await _createSession(mode: 'QR', tableId: tableId, secret: secret);
    } catch (e) {
      showSnackBar(context, 'Failed to scan QR code'.tr());
      debugPrint('QR scan error: $e');
    }
  }

  Future<void> _enterTableCodeManually() async {
    final code = _tableCodeController.text.trim();
    if (code.isEmpty) {
      showSnackBar(context, 'Please enter table code'.tr());
      return;
    }

    await _createSession(mode: 'MANUAL', tableCodePublic: code);
  }

  Future<void> _createSession({
    required String mode,
    String? tableId,
    String? secret,
    String? tableCodePublic,
  }) async {
    showProgress(context, 'Creating session...'.tr(), false, Color(colorPrimary));

    try {
      final sessionId = await _repository.createTableSession(
        listingId: widget.listing.id,
        mode: mode,
        tableId: tableId,
        secret: secret,
        tableCodePublic: tableCodePublic,
      );

      hideProgress();

      setState(() {
        _tableCodeController.clear();
      });

      _startSessionStream(sessionId);

      showSnackBar(context, 'Session created! Waiting for staff confirmation...'.tr());
    } catch (e) {
      hideProgress();
      showSnackBar(context, e.toString().replaceAll('Exception: ', ''));
      debugPrint('Create session error: $e');
    }
  }

  Future<void> _summonWaiter() async {
    final purpose = await showDialog<SummonPurpose>(
      context: context,
      builder: (context) => _SummonPurposeDialog(),
    );

    if (purpose == null) return;

    showProgress(context, 'Summoning waiter...'.tr(), false, Color(colorPrimary));

    try {
      await _repository.summonWaiter(
        sessionId: _activeSession!.sessionId,
        purpose: purpose.value,
      );

      hideProgress();
      showSnackBar(context, 'Waiter summoned successfully!'.tr());
    } catch (e) {
      hideProgress();
      showSnackBar(context, e.toString().replaceAll('Exception: ', ''));
      debugPrint('Summon waiter error: $e');
    }
  }

  Future<void> _requestBill() async {
    final method = await showDialog<PaymentMethod>(
      context: context,
      builder: (context) => _PaymentMethodDialog(),
    );

    if (method == null) return;

    showProgress(context, 'Requesting bill...'.tr(), false, Color(colorPrimary));

    try {
      await _repository.requestBill(
        sessionId: _activeSession!.sessionId,
        paymentMethod: method.value,
      );

      hideProgress();
      showSnackBar(context, 'Bill requested successfully!'.tr());
    } catch (e) {
      hideProgress();
      showSnackBar(context, e.toString().replaceAll('Exception: ', ''));
      debugPrint('Request bill error: $e');
    }
  }

  Future<void> _closeSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Close Session?'.tr()),
        content: Text('Are you sure you want to close this table session?'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Close'.tr()),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    showProgress(context, 'Closing session...'.tr(), false, Color(colorPrimary));

    try {
      await _repository.closeTableSession(sessionId: _activeSession!.sessionId);

      hideProgress();
      setState(() {
        _activeSession = null;
      });
      showSnackBar(context, 'Session closed'.tr());
    } catch (e) {
      hideProgress();
      showSnackBar(context, e.toString().replaceAll('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Table Mode'.tr()),
        backgroundColor: Color(colorPrimary),
      ),
      body: _isScanning ? _buildScanner() : _buildContent(),
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController ??= MobileScannerController(
            detectionSpeed: DetectionSpeed.normal,
            facing: CameraFacing.back,
          ),
          onDetect: (capture) {
            final barcodes = capture.barcodes;
            if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
              _handleQRScanned(barcodes.first.rawValue!);
            }
          },
        ),
        Positioned(
          top: 16,
          right: 16,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 32),
            onPressed: _stopScanning,
          ),
        ),
        Positioned(
          bottom: 32,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              'Scan Table QR Code'.tr(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 3.0,
                    color: Colors.black,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_activeSession != null) {
      return _buildActiveSession();
    }

    return _buildJoinTable();
  }

  Widget _buildJoinTable() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Join a Table'.tr(),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          
          // QR Scan option
          Card(
            child: ListTile(
              leading: const Icon(Icons.qr_code_scanner, size: 40),
              title: Text('Scan QR Code'.tr()),
              subtitle: Text('Scan the QR code on your table'.tr()),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _scanQRCode,
            ),
          ),
          
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('OR'.tr()),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 16),
          
          // Manual entry option
          Text(
            'Enter Table Code'.tr(),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _tableCodeController,
            decoration: InputDecoration(
              hintText: 'e.g., T7'.tr(),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.table_restaurant),
            ),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _enterTableCodeManually,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text('Join Table'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSession() {
    final session = _activeSession!;
    final isPending = session.status == TableSessionStatus.PENDING;
    final isActive = session.status == TableSessionStatus.ACTIVE;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table info card
          Card(
            color: isPending ? Colors.orange.shade50 : Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    isPending ? Icons.pending : Icons.check_circle,
                    size: 48,
                    color: isPending ? Colors.orange : Colors.green,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    session.tableName,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPending ? 'Waiting for staff confirmation'.tr() : 'Session Active'.tr(),
                    style: TextStyle(
                      color: isPending ? Colors.orange.shade900 : Colors.green.shade900,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),

          // Assigned staff (if active)
          if (isActive && session.assignedStaff.isNotEmpty) ...[
            Text(
              'Your Waiter'.tr(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...session.assignedStaff.map((staff) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: staff.photoUrl.isNotEmpty
                      ? NetworkImage(staff.photoUrl)
                      : null,
                  child: staff.photoUrl.isEmpty
                      ? Text(staff.firstName[0].toUpperCase())
                      : null,
                ),
                title: Text(staff.firstName),
                subtitle: Text(staff.role),
              ),
            )),
            const SizedBox(height: 16),
          ],

          // Actions (only if active)
          if (isActive) ...[
            Text(
              'Actions'.tr(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            // Summon Waiter
            ListTile(
              leading: const Icon(Icons.notifications_active),
              title: Text('Summon Waiter'.tr()),
              subtitle: _remainingCooldownSeconds > 0
                  ? Text('Wait ${_remainingCooldownSeconds}s'.tr())
                  : Text('Call for assistance'.tr()),
              trailing: const Icon(Icons.arrow_forward_ios),
              enabled: _remainingCooldownSeconds == 0,
              onTap: _remainingCooldownSeconds == 0 ? _summonWaiter : null,
            ),
            const Divider(),
            
            // Request Bill
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: Text('Request Bill'.tr()),
              subtitle: Text('Ready to pay?'.tr()),
              trailing: const Icon(Icons.arrow_forward_ios),
              enabled: !session.isBillRequestOnCooldown,
              onTap: !session.isBillRequestOnCooldown ? _requestBill : null,
            ),
            const Divider(),
            
            // Place Order (navigate to Mini Store)
            ListTile(
              leading: const Icon(Icons.shopping_cart),
              title: Text('Place Order'.tr()),
              subtitle: Text('Browse menu and order'.tr()),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                // Navigate back to Mini Store with session ID
                Navigator.pop(context, session.sessionId);
              },
            ),
          ],

          const SizedBox(height: 24),
          
          // Close session button
          OutlinedButton(
            onPressed: _closeSession,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
            child: Text('Close Session'.tr()),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SUMMON PURPOSE DIALOG
// ============================================================================

class _SummonPurposeDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Why do you need assistance?'.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: SummonPurpose.values.map((purpose) {
          return ListTile(
            title: Text(purpose.displayName.tr()),
            onTap: () => Navigator.pop(context, purpose),
          );
        }).toList(),
      ),
    );
  }
}

// ============================================================================
// PAYMENT METHOD DIALOG
// ============================================================================

class _PaymentMethodDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Payment Method'.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: PaymentMethod.values.map((method) {
          return ListTile(
            title: Text(method.displayName.tr()),
            onTap: () => Navigator.pop(context, method),
          );
        }).toList(),
      ),
    );
  }
}
