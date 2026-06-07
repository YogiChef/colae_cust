// ignore_for_file: use_build_context_synchronously, unnecessary_underscores

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:colae_cut/services/sevice.dart';
import 'package:colae_cut/pages/minor_page/downline_detail_page.dart';
import 'package:colae_cut/pages/minor_page/referral_qr_page.dart';

class ReferralDashboardPage extends StatefulWidget {
  const ReferralDashboardPage({super.key});

  @override
  State<ReferralDashboardPage> createState() => _ReferralDashboardPageState();
}

class _ReferralDashboardPageState extends State<ReferralDashboardPage> {
  final String _uid = FirebaseAuth.instance.currentUser!.uid;
  bool _isWithdrawing = false;

  Future<void> _requestWithdrawal(double amount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการถอนเงิน'),
        content: Text('ถอนเงิน ฿${amount.toStringAsFixed(2)} ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('ยืนยัน', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isWithdrawing = true);
    try {
      await FirebaseFirestore.instance.collection('withdrawal_requests').add({
        'userId': _uid,
        'amount': amount,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ส่งคำขอถอนเงินแล้ว รอการตรวจสอบ'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    } finally {
      if (mounted) setState(() => _isWithdrawing = false);
    }
  }

  Future<List<int>> _getDownlineCounts() async {
    final db = FirebaseFirestore.instance;
    final List<int> counts = [];

    for (int i = 0; i < 5; i++) {
      int total = 0;
      for (final col in ['buyers', 'vendors', 'riders']) {
        final snap = await db
            .collection(col)
            .where('uplineIds', arrayContains: _uid)
            .get();
        total += snap.docs.where((doc) {
          final ids = List<String>.from(doc.data()['uplineIds'] ?? []);
          return ids.length > i && ids[i] == _uid;
        }).length;
      }
      counts.add(total);
    }
    return counts;
  }

  Future<double> _calculatePendingThisMonth() async {
    final now = DateTime.now();
    final monthKey =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';

    final snap = await FirebaseFirestore.instance
        .collection('referral_transactions')
        .where('toUserId', isEqualTo: _uid)
        .where('month', isEqualTo: monthKey)
        .where('status', isEqualTo: 'pending_payout')
        .get();

    double total = 0;
    for (final doc in snap.docs) {
      total += (doc.data()['amount'] as num?)?.toDouble() ?? 0;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ธุรกรรม',
          style: styles(
            fontSize: 20.sp,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: mainColor,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('buyers')
            .doc(_uid)
            .snapshots(),
        builder: (context, buyerSnap) {
          final buyerData =
              buyerSnap.data?.data() as Map<String, dynamic>? ?? {};
          final String code = buyerData['referralCode'] as String? ?? '-';

          if (buyerSnap.hasData &&
              (buyerData['referralCode'] as String? ?? '').isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              try {
                final functions = FirebaseFunctions.instanceFor(
                  region: 'asia-southeast1',
                );
                await functions
                    .httpsCallable('generateReferralCodeForUser')
                    .call({'userId': _uid, 'userType': 'customer'});
              } catch (e) {
                debugPrint('[REFERRAL] generate code error: $e');
              }
            });
          }
          final int count = (buyerData['referralCount'] as num?)?.toInt() ?? 0;
          final bool qualified =
              buyerData['referralQualified'] as bool? ?? false;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('referral_transactions')
                .where('toUserId', isEqualTo: _uid)
                .snapshots(),
            builder: (context, txSnap) {
              if (buyerSnap.connectionState == ConnectionState.waiting &&
                  !buyerSnap.hasData) {
                return Center(
                  child: CircularProgressIndicator(color: mainColor),
                );
              }

              double pending = 0;
              double withdrawn = 0;

              if (txSnap.hasData) {
                for (final doc in txSnap.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final amount = (data['amount'] as num?)?.toDouble() ?? 0;
                  final status = data['status']?.toString() ?? '';
                  if (status == 'pending_payout') {
                    pending += amount;
                  } else if (status == 'paid') {
                    withdrawn += amount;
                  }
                }
              }

              final double total = pending + withdrawn;

              return RefreshIndicator(
                onRefresh: () async {
                  setState(() {});
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _codeCard(code),
                      _mySpendingCard(),
                      _downlineChart(qualified, count),
                      _earningsCard(pending, total, withdrawn),
                      SizedBox(height: 20.h),
                      _withdrawButton(pending),
                      SizedBox(height: 32.h),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _codeCard(String code) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'รหัสแนะนำ',
              style: styles(
                fontSize: 14.sp,
                color: Colors.deepPurple.shade900,
                fontWeight: FontWeight.w500,
              ),
            ),
            Spacer(),
            IconButton(
              icon: Icon(Icons.copy, color: Colors.grey, size: 20.sp),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('คัดลอกลิงก์แล้ว')),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.share, color: Colors.grey, size: 20.sp),
              onPressed: () => Share.share(
                'สมัครใช้งาน Colae แอปสั่งอาหาร ด้วยรหัสแนะนำ: $code',
              ),
            ),
            IconButton(
              icon: Icon(Icons.qr_code_2, color: Colors.purple, size: 22.sp),
              tooltip: 'สร้าง QR Code',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReferralQrPage(referralCode: code),
                  ),
                );
              },
            ),
          ],
        ),
        Text(
          code,
          style: styles(
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: Colors.black54,
            letterSpacing: 2,
          ),
        ),
        SizedBox(height: 12.h),
        Divider(color: Colors.grey.shade300, thickness: 0.5),
      ],
    );
  }

  Widget _earningsCard(double pending, double total, double withdrawn) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ประวัติรายได้',
            style: styles(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: Colors.deepPurple[900],
            ),
          ),
          SizedBox(height: 12.h),

          FutureBuilder<double>(
            future: _calculatePendingThisMonth(),
            builder: (context, snap) {
              final monthAmount = snap.data ?? 0;
              return Container(
                padding: EdgeInsets.all(12.w),
                margin: EdgeInsets.only(bottom: 12.h),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event, color: Colors.green, size: 20.sp),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'รายได้เดือนนี้',
                            style: styles(
                              fontSize: 11.sp,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            '฿${monthAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.green,
                            ),
                          ),
                          Text(
                            'จ่ายวันที่ 5 ของเดือนถัดไป',
                            style: styles(fontSize: 10.sp, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          Row(
            children: [
              _earningsItem('พร้อมถอน', pending, Colors.orange),
              _earningsItem('ทั้งหมด', total, Colors.blue),
              _earningsItem('ถอนแล้ว', withdrawn, Colors.green),
            ],
          ),
          SizedBox(height: 16.h),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('referral_transactions')
                .where('toUserId', isEqualTo: _uid)
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Padding(
                  padding: EdgeInsets.all(12.w),
                  child: Text(
                    'Error: ${snap.error}',
                    style: TextStyle(color: Colors.red, fontSize: 11.sp),
                  ),
                );
              }

              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return Padding(
                  padding: EdgeInsets.all(16.w),
                  child: const Center(child: CircularProgressIndicator()),
                );
              }

              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  child: Center(
                    child: Text(
                      'ยังไม่มีรายการ',
                      style: styles(color: Colors.grey, fontSize: 13.sp),
                    ),
                  ),
                );
              }

              final monthMap = <String, Map<String, dynamic>>{};

              for (final doc in snap.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final month = data['month']?.toString() ?? 'unknown';
                final amount = (data['amount'] as num?)?.toDouble() ?? 0;
                final status = data['status']?.toString() ?? 'pending_payout';

                if (!monthMap.containsKey(month)) {
                  monthMap[month] = {
                    'total': 0.0,
                    'count': 0,
                    'hasPending': false,
                  };
                }

                monthMap[month]!['total'] =
                    (monthMap[month]!['total'] as double) + amount;
                monthMap[month]!['count'] =
                    (monthMap[month]!['count'] as int) + 1;
                if (status == 'pending_payout') {
                  monthMap[month]!['hasPending'] = true;
                }
              }

              final months = monthMap.keys.toList()
                ..sort((a, b) => b.compareTo(a));

              return Column(
                children: months.map((month) {
                  final info = monthMap[month]!;
                  return _monthlyEarningItem(
                    month,
                    info['total'] as double,
                    info['count'] as int,
                    info['hasPending'] as bool,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _mySpendingCard() {
    return Padding(
      padding: EdgeInsets.only(top: 12.h, bottom: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 8.w),
          Text(
            'ค่าใช้จ่ายของฉัน',
            style: styles(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: Colors.deepPurple[900],
            ),
          ),
          FutureBuilder<Map<String, dynamic>>(
            future: _calculateMySpending(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: EdgeInsets.all(16.w),
                  child: const Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return Padding(
                  padding: EdgeInsets.all(8.w),
                  child: Text(
                    'Error: ${snap.error}',
                    style: styles(color: Colors.red, fontSize: 11.sp),
                  ),
                );
              }
              final data = snap.data ?? {};
              final monthly = (data['monthly'] as Map<String, dynamic>?) ?? {};

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (monthly.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      child: Center(
                        child: Text(
                          'ยังไม่มีรายการ',
                          style: TextStyle(color: Colors.grey, fontSize: 13.sp),
                        ),
                      ),
                    )
                  else
                    ...(() {
                      final months = monthly.keys.toList()
                        ..sort((a, b) => b.compareTo(a));
                      return months.map((month) {
                        final m = monthly[month] as Map<String, dynamic>;
                        return _mySpendingMonthItem(
                          month,
                          (m['total'] as double?) ?? 0,
                          (m['orderCount'] as int?) ?? 0,
                          (m['orderTotal'] as double?) ?? 0,
                          (m['bookingCount'] as int?) ?? 0,
                          (m['bookingTotal'] as double?) ?? 0,
                        );
                      }).toList();
                    })(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _mySpendingMonthItem(
    String month,
    double total,
    int orderCount,
    double orderTotal,
    int bookingCount,
    double bookingTotal,
  ) {
    final parts = month.split('-');
    const monthNames = [
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.',
    ];
    String displayMonth = month;
    if (parts.length == 2) {
      final monthIdx = int.tryParse(parts[1]);
      final year = int.tryParse(parts[0]);
      if (monthIdx != null && monthIdx >= 1 && monthIdx <= 12 && year != null) {
        displayMonth = '${monthNames[monthIdx - 1]} ${year + 543}';
      }
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  displayMonth,
                  style: styles(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                    color: Colors.black87,
                  ),
                ),
              ),
              Text(
                '฿${total.toStringAsFixed(2)}',
                style: styles(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: total < 5000 ? Colors.orange : Colors.green[700],
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          if (orderCount > 0)
            Padding(
              padding: EdgeInsets.only(left: 8.w, top: 2.h),
              child: Row(
                children: [
                  Icon(
                    Icons.restaurant,
                    size: 18.sp,
                    color: Colors.orange[700],
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      '$orderCount',
                      style: styles(
                        fontSize: 12.sp,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '฿${orderTotal.toStringAsFixed(2)}',
                    style: styles(
                      fontSize: 12.sp,
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          if (bookingCount > 0)
            Padding(
              padding: EdgeInsets.only(left: 8.w, top: 2.h),
              child: Row(
                children: [
                  Icon(Icons.hotel, size: 18.sp, color: Colors.indigo[700]),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      '$bookingCount',
                      style: styles(
                        fontSize: 12.sp,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '฿${bookingTotal.toStringAsFixed(2)}',
                    style: styles(
                      fontSize: 12.sp,
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _calculateMySpending() async {
    final db = FirebaseFirestore.instance;

    final ordersSnap = await db
        .collection('orders')
        .where('buyerId', isEqualTo: _uid)
        .where('status', isEqualTo: 'delivered')
        .get();

    final bookingsSnap = await db
        .collection('hotel_bookings')
        .where('guestId', isEqualTo: _uid)
        .where('status', isEqualTo: 'completed')
        .get();

    double totalAll = 0;
    final monthly = <String, Map<String, dynamic>>{};

    for (final doc in ordersSnap.docs) {
      final data = doc.data();
      final amount = (data['totalPrice'] as num?)?.toDouble() ?? 0;
      final ts =
          (data['timestamp'] as Timestamp?) ??
          (data['createdAt'] as Timestamp?);
      if (ts == null) continue;
      final date = ts.toDate();
      final month = '${date.year}-${date.month.toString().padLeft(2, '0')}';

      totalAll += amount;
      if (!monthly.containsKey(month)) {
        monthly[month] = {
          'total': 0.0,
          'orderCount': 0,
          'orderTotal': 0.0,
          'bookingCount': 0,
          'bookingTotal': 0.0,
        };
      }
      monthly[month]!['total'] = (monthly[month]!['total'] as double) + amount;
      monthly[month]!['orderCount'] =
          (monthly[month]!['orderCount'] as int) + 1;
      monthly[month]!['orderTotal'] =
          (monthly[month]!['orderTotal'] as double) + amount;
    }

    for (final doc in bookingsSnap.docs) {
      final data = doc.data();
      final totalPrice = (data['totalPrice'] as num?)?.toDouble() ?? 0;
      final refundAmount = (data['refundAmount'] as num?)?.toDouble() ?? 0;
      final amount = totalPrice - refundAmount;
      if (amount <= 0) continue;
      final ts = data['createdAt'] as Timestamp?;
      if (ts == null) continue;
      final date = ts.toDate();
      final month = '${date.year}-${date.month.toString().padLeft(2, '0')}';

      totalAll += amount;
      if (!monthly.containsKey(month)) {
        monthly[month] = {
          'total': 0.0,
          'orderCount': 0,
          'orderTotal': 0.0,
          'bookingCount': 0,
          'bookingTotal': 0.0,
        };
      }
      monthly[month]!['total'] = (monthly[month]!['total'] as double) + amount;
      monthly[month]!['bookingCount'] =
          (monthly[month]!['bookingCount'] as int) + 1;
      monthly[month]!['bookingTotal'] =
          (monthly[month]!['bookingTotal'] as double) + amount;
    }

    return {'totalAll': totalAll, 'monthly': monthly};
  }

  Widget _earningsItem(String label, double amount, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '฿${amount.toStringAsFixed(2)}',
            style: styles(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: styles(fontSize: 12.sp, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _downlineChart(bool qualified, int count) {
    final levels = ['1', '2', '3', '4', '5'];
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                qualified ? Icons.check_circle : Icons.info_outline,
                color: qualified
                    ? Colors.deepPurple[900]
                    : Colors.deepOrange[900],
                size: 24.sp,
              ),
              SizedBox(width: 8.w),
              Text(
                '${qualified ? 'รับรายได้!' : 'ภารกิจ'} 5 ชั้น $count/12',
                style: styles(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: qualified
                      ? Colors.deepPurple[900]
                      : Colors.deepOrange[900],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          FutureBuilder<List<int>>(
            future: _getDownlineCounts(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return SizedBox(
                  height: 220.h,
                  child: const Center(child: CircularProgressIndicator()),
                );
              }
              final counts = snap.data ?? [0, 0, 0, 0, 0];
              final maxY = counts.fold(0, (a, b) => a > b ? a : b).toDouble();

              return SizedBox(
                height: 220.h,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    backgroundColor: Colors.deepOrange.shade50,
                    maxY: maxY > 0 ? maxY + 5 : 10,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxY > 20 ? 10 : 5,
                      getDrawingHorizontalLine: (value) =>
                          FlLine(color: Colors.grey.shade300, strokeWidth: 0.5),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= levels.length) {
                              return const SizedBox();
                            }
                            return Padding(
                              padding: EdgeInsets.only(top: 4.h),
                              child: Text(
                                levels[i],
                                style: styles(
                                  fontSize: 9.sp,
                                  color: Colors.grey[700],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          interval: maxY > 20 ? 10 : 5,
                          getTitlesWidget: (value, meta) => Text(
                            value.toInt().toString(),
                            style: styles(
                              fontSize: 9.sp,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border(
                        left: BorderSide(
                          color: Colors.grey.shade300,
                          width: 0.5,
                        ),
                        bottom: BorderSide(
                          color: Colors.grey.shade300,
                          width: 0.5,
                        ),
                      ),
                    ),
                    barGroups: List.generate(5, (i) {
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: counts[i].toDouble(),
                            color: Colors.deepOrange.shade400,
                            width: 24.w,
                            borderRadius: BorderRadius.circular(2.r),
                          ),
                        ],
                      );
                    }),
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => Colors.black87,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                            BarTooltipItem(
                              '${counts[groupIndex]} คน',
                              styles(
                                color: Colors.white,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                      ),
                      touchCallback: (event, response) {
                        if (event is FlTapUpEvent && response?.spot != null) {
                          final levelIdx = response!.spot!.touchedBarGroupIndex;
                          if (levelIdx < 0 || levelIdx >= counts.length) return;
                          if (counts[levelIdx] > 0) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DownlineDetailPage(
                                  uid: _uid,
                                  level: levelIdx,
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _monthlyEarningItem(
    String month,
    double total,
    int count,
    bool hasPending,
  ) {
    final parts = month.split('-');
    const monthNames = [
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.',
    ];
    String displayMonth = month;
    if (parts.length == 2) {
      final monthIdx = int.tryParse(parts[1]);
      final year = int.tryParse(parts[0]);
      if (monthIdx != null && monthIdx >= 1 && monthIdx <= 12 && year != null) {
        displayMonth = '${monthNames[monthIdx - 1]} ${year + 543}';
      }
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayMonth,
                  style: styles(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '$count รายการ',
                  style: styles(fontSize: 11.sp, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '฿${total.toStringAsFixed(2)}',
                style: styles(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[700],
                ),
              ),
              SizedBox(height: 2.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: hasPending
                      ? Colors.orange.shade50
                      : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  hasPending ? 'รอจ่าย' : 'จ่ายแล้ว',
                  style: styles(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w600,
                    color: hasPending ? Colors.orange[800] : Colors.green[800],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _withdrawButton(double pending) {
    final bool canWithdraw = pending >= 5000;
    return SizedBox(
      width: double.infinity,
      height: 60.h,
      child: ElevatedButton.icon(
        icon: _isWithdrawing
            ? SizedBox(
                width: 20.w,
                height: 20.h,
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Icon(
                Icons.account_balance_wallet,
                color: Colors.white,
                size: 20.sp,
              ),
        label: Text(
          canWithdraw
              ? 'ถอนเงิน ฿${pending.toStringAsFixed(2)}'
              : 'ถอนขั้นต่ำ ฿5,000',
          style: styles(
            fontSize: 15.sp,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: canWithdraw ? Colors.amber : Colors.grey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7.r),
          ),
        ),
        onPressed: canWithdraw && !_isWithdrawing
            ? () => _requestWithdrawal(pending)
            : null,
      ),
    );
  }
}
