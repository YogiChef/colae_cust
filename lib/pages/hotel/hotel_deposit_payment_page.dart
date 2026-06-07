import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:colae_cut/services/sevice.dart';

class HotelDepositPaymentPage extends StatefulWidget {
  final String bookingId;
  final String hotelOwnerId;
  final double depositAmount;

  const HotelDepositPaymentPage({
    super.key,
    required this.bookingId,
    required this.hotelOwnerId,
    required this.depositAmount,
  });

  @override
  State<HotelDepositPaymentPage> createState() => _HotelDepositPaymentPageState();
}

class _HotelDepositPaymentPageState extends State<HotelDepositPaymentPage> {
  final _picker = ImagePicker();
  final _screenshotController = ScreenshotController();
  Map<String, dynamic>? _vendorData;
  File? _slipFile;
  bool _loading = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _loadVendor();
  }

  Future<void> _loadVendor() async {
    final doc = await FirebaseFirestore.instance
        .collection('vendors')
        .doc(widget.hotelOwnerId)
        .get();
    if (mounted) {
      setState(() {
        _vendorData = doc.data();
        _loading = false;
      });
    }
  }

  String _generatePromptPayPayload({
    required String promptPayId,
    required double amount,
  }) {
    final cleanId = promptPayId.replaceAll(RegExp(r'[^\d]'), '');
    String aid;
    String idFormatted;
    if (cleanId.length == 13) {
      aid = 'A000000677010111';
      idFormatted = '0213$cleanId';
    } else if (cleanId.length == 10) {
      final mobile = '0066${cleanId.substring(1)}';
      aid = 'A000000677010111';
      idFormatted = '0113$mobile';
    } else {
      idFormatted = '0113$cleanId';
      aid = 'A000000677010111';
    }

    String payload =
        '00020101021129${(idFormatted.length + 20).toString().padLeft(2, '0')}0016$aid$idFormatted';
    payload += '5303764';

    final amtStr = amount.toStringAsFixed(2);
    payload += '54${amtStr.length.toString().padLeft(2, '0')}$amtStr';
    payload += '5802TH';
    payload += '6304';

    final crc = _computeCRC16CCITT(payload);
    return '$payload$crc';
  }

  String _computeCRC16CCITT(String data) {
    int crc = 0xFFFF;
    const int poly = 0x1021;
    for (int i = 0; i < data.length; i++) {
      int charCode = data.codeUnitAt(i);
      crc ^= (charCode << 8);
      for (int j = 0; j < 8; j++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ poly) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  Future<void> _saveQrToGallery() async {
    try {
      final imageBytes = await _screenshotController.capture();
      if (imageBytes != null && imageBytes.isNotEmpty) {
        await Gal.putImageBytes(imageBytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('บันทึกรูปสำเร็จ'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('บันทึกไม่สำเร็จ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickAndUploadSlip() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('ถ่ายรูป'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('เลือกจากแกลลอรี่'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;
    final picked = await _picker.pickImage(source: source);
    if (picked == null) return;

    setState(() {
      _slipFile = File(picked.path);
      _uploading = true;
    });

    EasyLoading.show(status: 'กำลังอัปโหลด...');
    try {
      final ref = FirebaseStorage.instance.ref(
        'hotel_slips/${widget.bookingId}/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await ref.putFile(_slipFile!);
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('hotel_bookings')
          .doc(widget.bookingId)
          .update({
        'depositPaid': true,
        'depositSlipUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      EasyLoading.showSuccess('ส่งหลักฐานสำเร็จ');
      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
        Fluttertoast.showToast(msg: 'จองสำเร็จ! รอเจ้าของยืนยัน');
      }
    } catch (e) {
      EasyLoading.showError('ผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(backgroundColor: mainColor, foregroundColor: Colors.white),
        body: Center(child: CircularProgressIndicator(color: mainColor)),
      );
    }

    final promptPay = (_vendorData?['promptPayId'] ?? '').toString();
    final ownerName = (_vendorData?['ownerName'] ?? '').toString();

    if (promptPay.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('สแกน QR Code', style: styles(color: Colors.white, fontSize: 18.sp)),
          backgroundColor: mainColor,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(20.w),
            child: Text(
              'เจ้าของยังไม่ได้ตั้งค่า PromptPay\nกรุณาติดต่อเจ้าของโดยตรง',
              textAlign: TextAlign.center,
              style: styles(fontSize: 14.sp, color: Colors.grey[700]),
            ),
          ),
        ),
      );
    }

    final payload = _generatePromptPayPayload(
      promptPayId: promptPay,
      amount: widget.depositAmount,
    );

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'สแกน QR Code',
          style: styles(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w600),
        ),
        backgroundColor: mainColor,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(20.w),
                child: Screenshot(
                  controller: _screenshotController,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(24.w),
                    child: Column(
                      children: [
                        // PromptPay header
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFF003D6B),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: const Text(
                            'PromptPay',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        SizedBox(height: 20.h),
                        // QR Code
                        QrImageView(
                          data: payload,
                          version: QrVersions.auto,
                          size: 260.h,
                        ),
                        SizedBox(height: 20.h),
                        // ยอดเงิน
                        Text(
                          '฿${widget.depositAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 28.sp,
                            fontWeight: FontWeight.bold,
                            color: mainColor,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'ยอดมัดจำที่ต้องชำระ',
                          style: styles(fontSize: 13.sp, color: Colors.grey[600]),
                        ),
                        SizedBox(height: 12.h),
                        const Divider(),
                        SizedBox(height: 8.h),
                        if (ownerName.isNotEmpty) ...[
                          Text(
                            ownerName,
                            style: styles(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 4.h),
                        ],
                        Text(
                          promptPay,
                          style: styles(fontSize: 13.sp, color: Colors.blue[700]),
                        ),
                        SizedBox(height: 8.h),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // ปุ่ม บันทึก + ยืนยัน
          Container(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.download, color: Colors.orange),
                    label: Text(
                      'บันทึก',
                      style: styles(
                        fontSize: 15.sp,
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.yellow.shade50,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      side: const BorderSide(color: Colors.orange),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    onPressed: _saveQrToGallery,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                    label: Text(
                      'ยืนยัน',
                      style: styles(
                        fontSize: 15.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _uploading ? Colors.grey : mainColor,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    onPressed: _uploading ? null : _pickAndUploadSlip,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
