// ignore_for_file: file_names, avoid_print, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:colae_cut/services/sevice.dart';

class GuestQRPage extends StatelessWidget {
  final String vendorRef = 'store123';

  const GuestQRPage({super.key});

  @override
  Widget build(BuildContext context) {
    final qrUrl = 'deli-box://login?ref=$vendorRef';

    return Scaffold(
      appBar: AppBar(title: const Text('QR Code for deli_box Login')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'สแกน QR เพื่อล็อกอิน deli_box',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            QrImageView(
              data: qrUrl,
              version: QrVersions.auto,
              size: 200.w,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: EdgeInsets.all(16.w),
            ),
            const SizedBox(height: 16),
            Text(
              'ลูกค้าสแกน QR นี้จาก LINE/กล้องโทรศัพท์\nจะเปิดแอป deli_box และไปหน้าล็อกอินทันที',
              textAlign: TextAlign.center,
              style: styles(fontSize: 14.sp, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                print('QR URL: $qrUrl'); // Copy หรือ save
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('QR พร้อมใช้งาน: $qrUrl')),
                );
              },
              child: const Text('แชร์ QR'),
            ),
          ],
        ),
      ),
    );
  }
}
