// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:colae_cut/pages/hotel/hotel_deposit_payment_page.dart';
import 'package:colae_cut/services/sevice.dart';

class HotelBookingPage extends StatefulWidget {
  final String hotelId;
  final Map<String, dynamic> hotelData;
  final Map<String, dynamic> roomData;
  final DateTime checkIn;
  final DateTime checkOut;
  final double totalPrice;

  const HotelBookingPage({
    super.key,
    required this.hotelId,
    required this.hotelData,
    required this.roomData,
    required this.checkIn,
    required this.checkOut,
    required this.totalPrice,
  });

  @override
  State<HotelBookingPage> createState() => _HotelBookingPageState();
}

class _HotelBookingPageState extends State<HotelBookingPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _noteController = TextEditingController();

  int _guests = 1;
  int _rooms = 1;
  String _paymentTiming = 'deposit_now';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadBuyerInfo();
  }

  Future<void> _loadBuyerInfo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('buyers')
        .doc(uid)
        .get();
    if (doc.exists && mounted) {
      final d = doc.data()!;
      setState(() {
        _nameController.text = d['fullName'] ?? '';
        _phoneController.text = d['custphone'] ?? '';
      });
    }
  }

  String _generateBookingCode() {
    final rand = DateTime.now().millisecondsSinceEpoch % 9000000 + 1000000;
    return rand.toString();
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    EasyLoading.show(status: 'กำลังจอง...');

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final totalPrice = widget.totalPrice * _rooms;
      final depositPct =
          (widget.roomData['depositPercentage'] as num?)?.toInt() ?? 30;
      final depositAmount = totalPrice * depositPct / 100;
      final nights = widget.checkOut.difference(widget.checkIn).inDays;

      final cancellationDeadline = widget.checkIn.subtract(
        const Duration(days: 1),
      );

      final bookingRef = FirebaseFirestore.instance
          .collection('hotel_bookings')
          .doc();

      await bookingRef.set({
        'bookingCode': _generateBookingCode(),
        'hotelId': widget.hotelId,
        'hotelName': widget.hotelData['name'] ?? '',
        'hotelType': widget.hotelData['mainType'] ?? 'ที่พัก',
        'roomId': widget.roomData['id'],
        'roomName': widget.roomData['name'] ?? '',
        'roomType': widget.roomData['roomType'] ?? '',
        'guestId': uid,
        'guestName': _nameController.text.trim(),
        'guestPhone': _phoneController.text.trim(),
        'checkIn': Timestamp.fromDate(widget.checkIn),
        'checkOut': Timestamp.fromDate(widget.checkOut),
        'nights': nights,
        'guests': _guests,
        'rooms': _rooms,
        'pricePerNight': widget.totalPrice / nights,
        'totalPrice': totalPrice,
        'depositPercentage': depositPct,
        'depositAmount': depositAmount,
        'depositPaid': false,
        'fullyPaid': false,
        'paymentTiming': _paymentTiming,
        'note': _noteController.text.trim(),
        'status': 'pending',
        'cancellationDeadline': Timestamp.fromDate(cancellationDeadline),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      EasyLoading.showSuccess('จองสำเร็จ');

      if (!mounted) return;

      if (_paymentTiming == 'deposit_now') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HotelDepositPaymentPage(
              bookingId: bookingRef.id,
              hotelOwnerId: widget.hotelId,
              depositAmount: depositAmount,
            ),
          ),
        );
      } else {
        Navigator.popUntil(context, (route) => route.isFirst);
        Fluttertoast.showToast(msg: 'จองสำเร็จ! เจ้าของจะติดต่อกลับเร็วๆ นี้');
      }
    } catch (e) {
      EasyLoading.showError('ผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nights = widget.checkOut.difference(widget.checkIn).inDays;
    final totalPrice = widget.totalPrice * _rooms;
    final depositPct =
        (widget.roomData['depositPercentage'] as num?)?.toInt() ?? 30;
    final depositAmount = totalPrice * depositPct / 100;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ยืนยันการจอง',
          style: styles(
            color: Colors.white,
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: mainColor,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: Colors.white,
                child: Padding(
                  padding: EdgeInsets.all(12.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.hotel, color: mainColor),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              widget.hotelData['name'] ?? '',
                              style: styles(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: mainColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Row(
                        children: [
                          Icon(Icons.bed, color: Colors.grey, size: 24.sp),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              widget.roomData['name'] ?? '',
                              style: styles(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      _infoRow(
                        'Check-in',
                        DateFormat('d MM yyyy').format(widget.checkIn),
                      ),
                      _infoRow(
                        'Check-out',
                        DateFormat('d MM yyyy').format(widget.checkOut),
                      ),
                      _infoRow('จำนวนคืน', '$nights คืน'),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 16.h),
              _sectionTitle('ข้อมูลผู้จอง'),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'ชื่อ *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'กรุณากรอกชื่อ' : null,
              ),
              SizedBox(height: 12.h),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'เบอร์โทร *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'กรุณากรอกเบอร์โทร' : null,
              ),
              SizedBox(height: 12.h),

              _counterRow(
                'จำนวนคน',
                _guests,
                (v) => setState(() => _guests = v),
                min: 1,
                max: 20,
              ),
              SizedBox(height: 8.h),
              _counterRow(
                'จำนวนห้อง',
                _rooms,
                (v) => setState(() => _rooms = v),
                min: 1,
                max: 10,
              ),

              SizedBox(height: 12.h),
              TextFormField(
                controller: _noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'หมายเหตุ',
                  border: OutlineInputBorder(),
                  hintText: 'เช่น ขอเตียงเสริม, มาถึงตอนเย็น',
                ),
              ),

              SizedBox(height: 20.h),
              _sectionTitle('สรุปราคา'),
              Card(
                color: Colors.white,
                child: Padding(
                  padding: EdgeInsets.all(12.w),
                  child: Column(
                    children: [
                      _priceRow(
                        'ราคาห้อง (${widget.totalPrice.toStringAsFixed(0)} × $_rooms ห้อง)',
                        totalPrice,
                      ),
                      const Divider(),
                      _priceRow('ยอดรวม', totalPrice, isBold: true),
                      SizedBox(height: 4.h),
                      _priceRow(
                        'มัดจำ $depositPct%',
                        depositAmount,
                        isHighlight: true,
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 20.h),
              _sectionTitle('การชำระเงิน'),
              Card(
                color: Colors.white,
                child: Column(
                  children: [
                    RadioListTile<String>(
                      value: 'deposit_now',
                      groupValue: _paymentTiming,
                      onChanged: (v) => setState(() => _paymentTiming = v!),
                      activeColor: mainColor,
                      title: Text(
                        'จ่ายมัดจำตอนนี้',
                        style: styles(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      subtitle: Text(
                        'มัดจำ ฿${depositAmount.toStringAsFixed(0)} • ยืนยันการจองทันที',
                        style: styles(fontSize: 12.sp, color: Colors.grey[700]),
                      ),
                    ),
                    RadioListTile<String>(
                      value: 'pay_at_checkin',
                      groupValue: _paymentTiming,
                      onChanged: (v) => setState(() => _paymentTiming = v!),
                      activeColor: mainColor,
                      title: Text(
                        'จ่ายตอน check-in',
                        style: styles(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      subtitle: Text(
                        'จ่ายเต็มจำนวน ฿${totalPrice.toStringAsFixed(0)} ตอนเข้าพัก',
                        style: styles(fontSize: 12.sp, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.amber[800],
                      size: 18.sp,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'ยกเลิกก่อน 24 ชม. ของ check-in คืนเงินเต็ม นอกนั้นไม่คืน',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.amber[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24.h),
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _submitting ? Colors.grey : mainColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  onPressed: _submitting ? null : _submitBooking,
                  child: Text(
                    _submitting ? 'กำลังจอง...' : 'ยืนยันการจอง',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 30.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Text(
        text,
        style: styles(
          fontSize: 15.sp,
          fontWeight: FontWeight.bold,
          color: Colors.grey[800],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          SizedBox(
            width: 100.w,
            child: Text(
              label,
              style: styles(fontSize: 13.sp, color: Colors.grey[700]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: styles(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: Colors.grey[500],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceRow(
    String label,
    double amount, {
    bool isBold = false,
    bool isHighlight = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isHighlight ? mainColor : Colors.grey[800],
            ),
          ),
          Text(
            '฿${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: isBold ? 16.sp : 14.sp,
              fontWeight: isBold || isHighlight
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: isHighlight ? mainColor : Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _counterRow(
    String label,
    int value,
    ValueChanged<int> onChanged, {
    int min = 1,
    int max = 10,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: styles(
                fontSize: 14.sp,
                color: Colors.grey[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 40,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: styles(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: mainColor),
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }
}
