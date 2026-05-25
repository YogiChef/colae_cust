import 'dart:async';
import 'package:colae_cut/assistants/qr_scanner_overlay.dart';
import 'package:colae_cut/pages/main_products.dart';
import 'package:colae_cut/services/sevice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:colae_cut/providers/cart_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final MobileScannerController controller = MobileScannerController(
    formats: [BarcodeFormat.qrCode],
    autoStart: true,
  );

  bool _isScanned = false;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณาอนุญาตกล้องในตั้งค่าแอป')),
        );
      }
    }
  }

  void _handleQR(String code) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    try {
      final uri = Uri.parse(code);
      final restaurantId = uri.queryParameters['restaurant_id'];

      if (restaurantId == null || restaurantId.isEmpty) {
        _resetScan();
        return;
      }

      final tableNumber = uri.queryParameters['table'];
      controller.stop();

      if (tableNumber != null && tableNumber.isNotEmpty) {
        cartProvider.setTableId(tableNumber);
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MainProductPage(
              vendorid: restaurantId,
              tableNumber: tableNumber,
              fromQr: true,
            ),
          ),
        );
      }
    } catch (_) {
      _resetScan();
    }
  }

  void _resetScan() {
    _isScanned = false;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR Code ไม่รองรับ กรุณาสแกนใหม่')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: mainColor,
        title: Text(
          'สแกน QR Code',
          style: styles(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back, color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: controller,
              builder: (context, state, _) {
                return state.torchState == TorchState.on
                    ? Icon(Icons.flash_on, color: Colors.yellow, size: 24.r)
                    : Icon(Icons.flash_off, color: Colors.white, size: 24.r);
              },
            ),
            onPressed: () => controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (_isScanned) return;
              _isScanned = true;

              final code = capture.barcodes.firstOrNull?.rawValue;
              if (code != null && code.isNotEmpty) {
                _handleQR(code);
              } else {
                _isScanned = false;
              }
            },
          ),
          const QRScannerOverlay(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
