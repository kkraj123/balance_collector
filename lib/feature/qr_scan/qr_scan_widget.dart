import 'dart:io';

import 'package:collector_app/common/app/theme.dart';
import 'package:collector_app/feature/database/cb_db.dart';
import 'package:collector_app/feature/qr_scan/overlay_with_hole_painter.dart';
import 'package:collector_app/feature/qr_scan/qr_util.dart';
import 'package:collector_app/views/pages/Input_data_table/input_data_table.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class QRScanWidget extends StatefulWidget {
  const QRScanWidget({super.key});

  @override
  State<QRScanWidget> createState() => _QRScanWidgetState();
}

class _QRScanWidgetState extends State<QRScanWidget>
    with WidgetsBindingObserver {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');

  QRViewController? controller;
  Barcode? scannedData;
  String? scannedUser;
  bool hasCameraPermission = false;
  bool isFlashOn = false;
  bool isProcessing = false;
  final CBDB _db = CBDB();
  Map<String, List<Map<String, dynamic>>> _groupedAccounts = {};
  Map<String, List<Map<String, dynamic>>> _filteredAccounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestCameraPermission();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);
    try {
      final accounts = await _db.getAllAccounts();
      final grouped = _groupAccountsByName(accounts);

      setState(() {
        _groupedAccounts = grouped;
        _filteredAccounts = grouped;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading accounts: $e');
    }
  }

  void _handleSearch(String myquery) {
    final query = myquery.toLowerCase();
    final Map<String, List<Map<String, dynamic>>> filtered = {};
    _groupedAccounts.forEach((name, accounts) {
      final matchingAccounts = accounts.where((account) {
        final memberNumber = account['id_no'].toLowerCase();
        return memberNumber.contains(query);
      }).toList();
      // print("this is the matchingAccounts $matchingAccounts");
      if (matchingAccounts.isNotEmpty) {
        filtered[name] = matchingAccounts;
      }
    });
    setState(() => _filteredAccounts = filtered);
    // print("this is the data see : $filtered");
    if (filtered.isNotEmpty) {
      final firstGroupKey = filtered.keys.first;
      final accountsList = filtered[firstGroupKey]!;
      if (accountsList.isNotEmpty) {
        final account = accountsList;
        setState(() {
          scannedUser = account.first['ac_name'];
        });
        controller?.pauseCamera();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InputDataTable(account: account),
          ),
        ).then((_) {
          if (mounted) controller?.resumeCamera();
        });
      }
    } else {
      _showErrorSnackBar("No account found with ID: $query");
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupAccountsByName(
      List<Map<String, dynamic>> accounts) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var account in accounts) {
      final name = account['ac_name'] as String;
      if (!grouped.containsKey(name)) {
        grouped[name] = [];
      }
      grouped[name]!.add(account);
    }

    return grouped;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    super.dispose();
  }

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller?.pauseCamera();
    }
    controller?.resumeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      controller?.resumeCamera();
    } else if (state == AppLifecycleState.inactive) {
      controller?.pauseCamera();
    }
  }

  void _toggleFlash() async {
    if (controller == null) return;
    if (controller != null) {
      await controller!.toggleFlash();
      final status = await controller!.getFlashStatus();
      setState(() {
        isFlashOn = status ?? false;
      });
    }
  }

  Future<void> _requestCameraPermission() async {
    hasCameraPermission = await QrUtils.requestCameraPermission(context);
    setState(() {});
  }

  Future<void> _scanQRFromGallery() async {
    try {
      final result = await QrUtils.scanQRFromGallery(context);
      if (result != null && result.isNotEmpty) {
        setState(() {
          scannedData = Barcode(result, BarcodeFormat.qrcode, []);
        });
      } else {
        _showErrorSnackBar("No Qr code found in the image");
      }
    } catch (e) {
      _showErrorSnackBar("Error scanning from gallery: $e");
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2)),
    );
  }

  void _onQrViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((event) {
      if (isProcessing) return;
      setState(() {
        isProcessing = true;
        scannedData = event;
      });
      _handleSearch(event.code ?? '');
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => isProcessing = false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    const qrSize = 200.0;
    return Scaffold(
        body: Stack(
      children: [
        hasCameraPermission
            ? QRView(
                key: qrKey,
                onQRViewCreated: _onQrViewCreated,
                overlay: QrScannerOverlayShape(
                    borderColor: CustomTheme.appThemeColorPrimary,
                    borderRadius: 10,
                    borderLength: 30,
                    borderWidth: 8,
                    cutOutSize: 200.0),
                formatsAllowed: const [BarcodeFormat.qrcode],
              )
            : _buildPermissionDeniedView(),
        if (hasCameraPermission) ...[
          CustomPaint(
            size: Size(size.width, size.height),
            painter: OverlayWithHolePainter(holeSize: qrSize),
          ),
          Positioned(
              top: size.height * 0.7,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  scannedData != null
                      ? 'Name: $scannedUser\nId: ${scannedData!.code}'
                      : "Scan a code",
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
              )),
          Positioned(
            right: 20,
            top: size.width,
            child: IconButton(
              icon: Icon(isFlashOn ? Icons.flash_on : Icons.flash_off,
                  color: Colors.white),
              onPressed: _toggleFlash,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: (size.height - 200) / 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Image.asset(
                      'assets/icons/balance1.png',
                      height: 60,
                      color: Colors.green,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Please align the QR within frame.",
                    style: textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: (size.width - 100) / 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _scanQRFromGallery,
                  icon: const Icon(Icons.photo_library),
                  label: const Text("Gallery"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: CustomTheme.appThemeColorPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).viewPadding.top + 10,
            left: 20,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: Colors.white10,
              ),
              child: IconButton(
                icon: const Icon(Icons.close),
                color: Colors.white,
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
          ),
        ]
      ],
    ));
  }

  Widget _buildPermissionDeniedView() {
    return Container(
      color: CustomTheme.appThemeColorPrimary.withOpacity(.4),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error,
            size: 80,
            color: CustomTheme.appThemeColorPrimary,
          ),
          const SizedBox(height: 16),
          const Text(
            "Camera permission is required",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            "Please grant camera permission to use the QR scanner",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              await openAppSettings();
            },
            child: const Text(
              "Open Settings",
              style: TextStyle(color: CustomTheme.appThemeColorPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
