import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:colae_cut/pages/hotel/hotel_deposit_payment_page.dart';
import 'package:colae_cut/pages/hotel/hotel_review_page.dart';
import 'package:colae_cut/pages/minor_page/chat_page.dart';
import 'package:colae_cut/services/sevice.dart';

class HotelBookingDetailPage extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic> bookingData;
  final bool isHistory;
  const HotelBookingDetailPage({
    super.key,
    required this.bookingId,
    required this.bookingData,
    this.isHistory = false,
  });

  @override
  State<HotelBookingDetailPage> createState() => _HotelBookingDetailPageState();
}

class _HotelBookingDetailPageState extends State<HotelBookingDetailPage> {
  Future<bool> _hasReviewed() async {
    final snap = await FirebaseFirestore.instance
        .collection('hotel_reviews')
        .where('bookingId', isEqualTo: widget.bookingId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'รายละเอียดการจอง',
          style: styles(
            color: Colors.white,
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: mainColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('hotel_bookings')
            .doc(widget.bookingId)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return Center(child: CircularProgressIndicator(color: mainColor));
          }
          final d = snap.data!.data() as Map<String, dynamic>;
          return _buildBody(d);
        },
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> d) {
    final status = d['status'] as String? ?? '';
    final checkIn = (d['checkIn'] as Timestamp).toDate();
    final checkOut = (d['checkOut'] as Timestamp).toDate();
    final totalPrice = (d['totalPrice'] as num?)?.toDouble() ?? 0;
    final depositAmount = (d['depositAmount'] as num?)?.toDouble() ?? 0;
    final depositPaid = d['depositPaid'] as bool? ?? false;
    final fullyPaid = d['fullyPaid'] as bool? ?? false;
    final cancellationDeadline = (d['cancellationDeadline'] as Timestamp?)
        ?.toDate();
    final canCancel = status == 'confirmed' || status == 'checked_in';
    final depositSlipUrl = d['depositSlipUrl'] as String?;
    final fullPaymentSlipUrl = d['fullPaymentSlipUrl'] as String?;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 12.h),
          Row(
            children: [
              Icon(
                Icons.confirmation_number,
                size: 16.sp,
                color: Colors.grey[700],
              ),
              SizedBox(width: 6.w),

              Text(
                d['bookingCode'] ?? '-',
                style: styles(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () {
                  Clipboard.setData(
                    ClipboardData(text: d['bookingCode'] ?? ''),
                  );
                  Fluttertoast.showToast(msg: 'คัดลอกแล้ว');
                },
                child: Icon(Icons.copy, size: 16.sp, color: mainColor),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Icon(
                _statusIcon(status),
                color: _statusColor(status),
                size: 28.sp,
              ),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _statusLabel(status),
                    style: styles(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: _statusColor(status),
                    ),
                  ),
                  Text(
                    _statusDescription(status),
                    style: styles(fontSize: 12.sp, color: Colors.grey[700]),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 20.h),
          _infoTable(
            rows: [
              MapEntry(
                d['hotelType'] as String? ?? 'ที่พัก',
                d['hotelName'] ?? '-',
              ),
              MapEntry('ห้อง', d['roomName'] ?? '-'),
            ],
          ),
          SizedBox(height: 16.h),
          _infoTable(
            rows: [
              MapEntry(
                'Check-in',
                DateFormat('d MMMM yyyy', 'th').format(checkIn),
              ),
              MapEntry(
                'Check-out',
                DateFormat('d MMMM yyyy', 'th').format(checkOut),
              ),
              MapEntry('จำนวนคืน', '${d['nights']} คืน'),
              MapEntry('จำนวนคน', '${d['guests']} คน'),
              MapEntry('จำนวนห้อง', '${d['rooms']} ห้อง'),
              if ((d['note'] ?? '').toString().isNotEmpty)
                MapEntry('หมายเหตุ', d['note'].toString()),
            ],
          ),
          SizedBox(height: 16.h),
          _infoTable(
            rows: [
              MapEntry('ยอดรวม', '฿${totalPrice.toStringAsFixed(0)}'),
              MapEntry(
                'มัดจำ (${d['depositPercentage'] ?? 30}%)',
                '฿${depositAmount.toStringAsFixed(0)} ${depositPaid ? "✅" : "⏳"}',
              ),
              MapEntry(
                'ยอดคงเหลือ',
                '฿${(totalPrice - depositAmount).toStringAsFixed(0)} ${fullyPaid ? "✅" : "⏳"}',
              ),
              if ((d['refundAmount'] as num?) != null &&
                  (d['refundAmount'] as num) > 0)
                MapEntry(
                  'คืนเงินแล้ว',
                  '฿${(d['refundAmount'] as num).toStringAsFixed(0)} ↩️',
                ),
            ],
          ),
          if (!widget.isHistory && depositSlipUrl != null) ...[
            SizedBox(height: 20.h),
            InkWell(
              onTap: () => _showSlipDialog(depositSlipUrl, 'Slip มัดจำ'),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.image, color: mainColor, size: 16.sp),
                  SizedBox(width: 4.w),
                  Text(
                    'ดู slip มัดจำ',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: mainColor,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!widget.isHistory && fullPaymentSlipUrl != null) ...[
            SizedBox(height: 20.h),
            InkWell(
              onTap: () =>
                  _showSlipDialog(fullPaymentSlipUrl, 'Slip ส่วนที่เหลือ'),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.image, color: mainColor, size: 16.sp),
                  SizedBox(width: 4.w),
                  Text(
                    'ดู slip ส่วนที่เหลือ',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: mainColor,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (canCancel && cancellationDeadline!.isBefore(DateTime.now())) ...[
            SizedBox(height: 12.h),
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber[800], size: 18.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'ยกเลิกได้ก่อน ${DateFormat('d MMMM yyyy, HH:mm', 'th').format(cancellationDeadline)} (คืนเงินเต็มจำนวน)',
                    style: styles(fontSize: 11.sp, color: Colors.amber[900]),
                  ),
                ),
              ],
            ),
          ],

          SizedBox(height: 24.h),
          Center(
            child: _buildActionButtons(
              d,
              status,
              depositPaid,
              fullyPaid,
              canCancel,
            ),
          ),
          SizedBox(height: 30.h),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    Map<String, dynamic> d,
    String status,
    bool depositPaid,
    bool fullyPaid,
    bool canCancel,
  ) {
    final buttons = <Widget>[];
    if (!widget.isHistory) {
      buttons.add(
        Container(
          width: width * 0.8,
          padding: EdgeInsets.only(bottom: 20.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: ElevatedButton.icon(
                  icon: const Icon(
                    Icons.chat_bubble_outline,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: Text(
                    'แชท',
                    style: styles(
                      color: Colors.white,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    minimumSize: Size(0, 32.h),
                    padding: EdgeInsets.symmetric(
                      vertical: 2.h,
                      horizontal: 8.w,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatPage(
                          vendorId: d['hotelId'],
                          buyerId: d['guestId'],
                          proId: 'hotel_${widget.bookingId}',
                          proName: d['hotelName'] ?? 'ที่พัก',
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(width: 8.w),
              Flexible(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.phone, color: Colors.white, size: 18),
                  label: Text(
                    'โทร',
                    style: styles(
                      color: Colors.white,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    minimumSize: Size(0, 32.h),
                    padding: EdgeInsets.symmetric(
                      vertical: 2.h,
                      horizontal: 8.w,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  onPressed: () => _callOwner(d['hotelId']),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final cancelRequested = d['cancelRequested'] as bool? ?? false;
    if (cancelRequested && status != 'cancelled') {
      buttons.add(
        Container(
          width: width * 0.8,
          padding: EdgeInsets.all(12.w),
          margin: EdgeInsets.only(bottom: 16.h),
          decoration: BoxDecoration(
            color: Colors.deepOrange,
            borderRadius: BorderRadius.circular(7.r),
            border: Border.all(color: Colors.deepOrange),
          ),
          child: Text(
            '⏳ รออนุมัติ',
            textAlign: TextAlign.center,
            style: styles(
              fontSize: 16.sp,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    } else if (canCancel && !cancelRequested) {
      buttons.add(
        _actionButton(
          'ขอยกเลิก',
          Icons.cancel_outlined,
          Colors.deepOrange,
          () => _requestCancel(),
        ),
      );
    }

    if (!depositPaid && status != 'cancelled' && status != 'completed') {
      buttons.add(
        _actionButton('จ่ายมัดจำ', Icons.payment, Colors.green, () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HotelDepositPaymentPage(
                bookingId: widget.bookingId,
                hotelOwnerId: d['hotelId'],
                depositAmount: (d['depositAmount'] as num).toDouble(),
              ),
            ),
          );
        }),
      );
    }

    if (depositPaid &&
        !fullyPaid &&
        status != 'cancelled' &&
        status != 'completed') {
      final totalPrice = (d['totalPrice'] as num).toDouble();
      final depositAmount = (d['depositAmount'] as num).toDouble();
      final remaining = totalPrice - depositAmount;
      final pendingCash = d['pendingCashPayment'] == true;
      final hasSlip = (d['fullPaymentSlipUrl'] ?? '').toString().isNotEmpty;
      if (pendingCash || hasSlip) {
        buttons.add(
          Container(
            width: width * 0.8,
            padding: EdgeInsets.all(12.w),
            margin: EdgeInsets.only(bottom: 16.h),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              border: Border.all(color: Colors.amber.shade400),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time, color: Colors.amber[800], size: 18.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    '⏳ รอเจ้าของยืนยันรับเงิน',
                    style: styles(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber[900],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        buttons.add(
          _actionButton(
            'จ่ายส่วนที่เหลือ ฿${remaining.toStringAsFixed(0)}',
            Icons.payment,
            Colors.blue,
            () => _showRemainingPaymentSheet(
              remaining,
              d['hotelId'] as String? ?? '',
            ),
          ),
        );
      }
    }

    if (status == 'completed') {
      buttons.add(
        FutureBuilder<bool>(
          future: _hasReviewed(),
          builder: (context, snap) {
            final reviewed = snap.data ?? false;
            return Padding(
              padding: EdgeInsets.only(bottom: 16.h),
              child: SizedBox(
                width: width * 0.8,
                child: ElevatedButton.icon(
                  icon: Icon(
                    reviewed ? Icons.check_circle : Icons.rate_review,
                    color: Colors.white,
                  ),
                  label: Text(
                    reviewed ? 'รีวิวแล้ว ✓' : 'เขียนรีวิว',
                    style: styles(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: reviewed
                        ? Colors.grey.shade200
                        : Colors.amber.shade700,
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HotelReviewPage(
                          bookingId: widget.bookingId,
                          hotelId: d['hotelId'],
                          hotelName: d['hotelName'] ?? '',
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      );
    }

    return Column(children: buttons);
  }

  Future<void> _showRemainingPaymentSheet(
    double remaining,
    String hotelOwnerId,
  ) async {
    final method = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Text(
                'เลือกวิธีจ่ายส่วนที่เหลือ ฿${remaining.toStringAsFixed(0)}',
                style: styles(fontSize: 15.sp, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.payments,
                color: Colors.green[700],
                size: 28.sp,
              ),
              title: Text(
                'เงินสด',
                style: styles(
                  color: Colors.black54,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'จ่ายที่โรงแรม',
                style: styles(
                  color: Colors.black54,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => Navigator.pop(ctx, 'cash'),
            ),
            ListTile(
              leading: Icon(
                Icons.qr_code,
                color: Colors.blue[700],
                size: 28.sp,
              ),
              title: Text(
                'โอน / QR',
                style: styles(
                  color: Colors.black54,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'สแกน QR และอัปโหลดสลิป',
                style: styles(
                  color: Colors.black54,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => Navigator.pop(ctx, 'qr'),
            ),
            SizedBox(height: 16.h),
          ],
        ),
      ),
    );

    if (method == null || !mounted) return;

    if (method == 'cash') {
      try {
        await FirebaseFirestore.instance
            .collection('hotel_bookings')
            .doc(widget.bookingId)
            .update({
              'fullPaymentMethod': 'cash',
              'pendingCashPayment': true,
              'fullPaymentRequestedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
      } catch (_) {}
    } else {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HotelDepositPaymentPage(
            bookingId: widget.bookingId,
            hotelOwnerId: hotelOwnerId,
            depositAmount: remaining,
            isFullPayment: true,
          ),
        ),
      );
    }
  }

  Widget _actionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: SizedBox(
        width: width * 0.8,
        child: ElevatedButton.icon(
          icon: Icon(icon, color: Colors.white),
          label: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
            padding: EdgeInsets.symmetric(vertical: 12.h),
          ),
          onPressed: onPressed,
        ),
      ),
    );
  }

  Future<void> _callOwner(String hotelId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(hotelId)
          .get();
      final phone = (doc.data()?['phone'] ?? '').toString();
      if (phone.isEmpty) {
        Fluttertoast.showToast(msg: 'ไม่พบเบอร์ติดต่อ');
        return;
      }
      final uri = Uri.parse('tel:$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        Fluttertoast.showToast(msg: 'ไม่สามารถโทรได้');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'ผิดพลาด: $e');
    }
  }

  Future<void> _requestCancel() async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ขอยกเลิกการจอง'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('กรุณาระบุเหตุผล เจ้าของจะพิจารณาและติดต่อกลับ'),
            SizedBox(height: 12.h),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'เหตุผล',
                border: OutlineInputBorder(),
                hintText: 'เช่น ติดธุระกะทันหัน',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'ปิด',
              style: styles(
                color: Colors.black54,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('ส่งคำขอ', style: styles(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (reasonController.text.trim().isEmpty) {
      Fluttertoast.showToast(msg: 'กรุณาระบุเหตุผล');
      return;
    }
    EasyLoading.show(status: 'กำลังส่งคำขอ...');
    try {
      await FirebaseFirestore.instance
          .collection('hotel_bookings')
          .doc(widget.bookingId)
          .update({
            'cancelRequested': true,
            'cancelReason': reasonController.text.trim(),
            'cancelRequestedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
      EasyLoading.showSuccess('ส่งคำขอแล้ว');
    } catch (e) {
      EasyLoading.showError('ผิดพลาด: $e');
    }
  }

  void _showSlipDialog(String url, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(12.w),
              child: Text(
                title,
                style: styles(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
            ),
            Flexible(
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                memCacheWidth: 1200,
                placeholder: (_, __) => Container(color: Colors.grey.shade200),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ปิด', style: TextStyle(color: Colors.black54)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTable({required List<MapEntry<String, String>> rows}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
        borderRadius: BorderRadius.circular(12.r),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ...List.generate(rows.length, (i) {
            final isLast = i == rows.length - 1;
            return Container(
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade200,
                          width: 0.5,
                        ),
                      ),
              ),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      rows[i].key,
                      style: styles(fontSize: 13.sp, color: Colors.grey[700]),
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: Text(
                      rows[i].value,
                      textAlign: TextAlign.right,
                      style: styles(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'checked_in':
        return Colors.green;
      case 'completed':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'pending':
        return Icons.schedule;
      case 'confirmed':
        return Icons.check_circle;
      case 'checked_in':
        return Icons.login;
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'pending':
        return 'รอเจ้าของยืนยัน';
      case 'confirmed':
        return 'ยืนยันแล้ว';
      case 'checked_in':
        return 'กำลังเข้าพัก';
      case 'completed':
        return 'เสร็จสิ้น';
      case 'cancelled':
        return 'ยกเลิก';
      default:
        return s;
    }
  }

  String _statusDescription(String s) {
    switch (s) {
      case 'pending':
        return 'เจ้าของจะติดต่อกลับเร็วๆ นี้';
      case 'confirmed':
        return 'เตรียมตัวเข้าพักได้เลย';
      case 'checked_in':
        return 'ขอให้มีความสุขในการพัก';
      case 'completed':
        return 'ขอบคุณที่ใช้บริการ';
      case 'cancelled':
        return 'การจองนี้ถูกยกเลิกแล้ว';
      default:
        return '';
    }
  }
}
