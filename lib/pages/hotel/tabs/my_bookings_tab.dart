// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:colae_cut/tabs/explore_tab.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:colae_cut/pages/hotel/hotel_booking_detail_page.dart';
import 'package:colae_cut/services/sevice.dart';

class MyBookingsTab extends StatefulWidget {
  const MyBookingsTab({super.key});

  @override
  State<MyBookingsTab> createState() => _MyBookingsTabState();
}

class _MyBookingsTabState extends State<MyBookingsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'การจองของฉัน',
          style: styles(color: Colors.white, fontSize: 18.sp),
        ),
        backgroundColor: mainColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'เปลี่ยนบริการ',
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('buyer_last_mode');
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const ExploreTabPages()),
                (route) => false,
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: styles(fontSize: 14.sp, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'การจองที่พัก'),
            Tab(text: 'ประวัติการจอง'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _bookingList(isUpcoming: true),
          _bookingList(isUpcoming: false),
        ],
      ),
    );
  }

  Widget _bookingList({required bool isUpcoming}) {
    final upcomingStatuses = ['pending', 'confirmed', 'checked_in'];
    final pastStatuses = ['completed', 'cancelled'];

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('hotel_bookings')
          .where('guestId', isEqualTo: _uid)
          .where(
            'status',
            whereIn: isUpcoming ? upcomingStatuses : pastStatuses,
          )
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: mainColor));
        }
        if (snap.hasError) {
          return Center(
            child: Text(
              'Error: ${snap.error}',
              style: styles(color: Colors.red),
            ),
          );
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'images/waiting.webp',
                  width: 250.w,
                  height: 250.h,
                  fit: BoxFit.contain,
                ),
                SizedBox(height: 16.h),
                Text(
                  isUpcoming ? 'ยังไม่มีการจอง' : 'ยังไม่มีประวัติ',
                  style: styles(fontSize: 16.sp, color: Colors.grey),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: EdgeInsets.all(12.w),
          itemCount: docs.length,
          itemBuilder: (_, i) => _bookingCard(docs[i]),
        );
      },
    );
  }

  Widget _bookingCard(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final status = d['status'] as String? ?? '';
    final checkIn = (d['checkIn'] as Timestamp).toDate();
    final checkOut = (d['checkOut'] as Timestamp).toDate();
    final totalPrice = (d['totalPrice'] as num?)?.toDouble() ?? 0;
    final depositPaid = d['depositPaid'] as bool? ?? false;
    final fullyPaid = d['fullyPaid'] as bool? ?? false;

    return Card(
      margin: EdgeInsets.only(bottom: 2.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.r)),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  HotelBookingDetailPage(bookingId: doc.id, bookingData: d),
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // รหัสจอง
              if ((d['bookingCode'] ?? '').toString().isNotEmpty) ...[
                Row(
                  children: [
                    Icon(
                      Icons.confirmation_number,
                      size: 12.sp,
                      color: Colors.grey[500],
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      '#${d['bookingCode']}',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
              ],
              Row(
                children: [
                  Expanded(
                    child: Text(
                      d['hotelName'] ?? '-',
                      style: styles(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(7.r),
                    ),
                    child: Text(
                      _statusLabel(status),
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w400,
                        color: _statusColor(status),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 2.h),
              Text(
                d['roomName'] ?? '-',
                style: styles(fontSize: 13.sp, color: Colors.grey[700]),
              ),
              SizedBox(height: 4.h),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14.sp, color: Colors.grey),
                  SizedBox(width: 4.w),
                  Text(
                    '${DateFormat('d MMM').format(checkIn)} - ${DateFormat('d MMM yyyy').format(checkOut)}',
                    style: styles(fontSize: 11.sp, color: Colors.grey[700]),
                  ),
                  SizedBox(width: 8.w),
                  const Text('•', style: TextStyle(color: Colors.grey)),
                  SizedBox(width: 8.w),
                  Text(
                    '${d['nights']} คืน',
                    style: styles(fontSize: 11.sp, color: Colors.grey[700]),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '฿${totalPrice.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: mainColor,
                    ),
                  ),
                  Row(
                    children: [
                      if (depositPaid)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'มัดจำ ✓',
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: Colors.orange[800],
                            ),
                          ),
                        ),
                      if (fullyPaid) ...[
                        SizedBox(width: 4.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'จ่ายครบ ✓',
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: Colors.green[800],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
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

  String _statusLabel(String s) {
    switch (s) {
      case 'pending':
        return 'รอยืนยัน';
      case 'confirmed':
        return 'ยืนยันแล้ว';
      case 'checked_in':
        return 'เข้าพัก';
      case 'completed':
        return 'เสร็จสิ้น';
      case 'cancelled':
        return 'ยกเลิก';
      default:
        return s;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
