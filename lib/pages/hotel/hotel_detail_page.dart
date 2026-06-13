// ignore_for_file: use_build_context_synchronously, deprecated_member_use, unnecessary_underscores

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:colae_cut/pages/hotel/helpers/rooms_availability_helper.dart';
import 'package:colae_cut/pages/hotel/helpers/favorites_helper.dart';
import 'package:colae_cut/pages/hotel/hotel_booking_page.dart';
import 'package:colae_cut/services/sevice.dart';

class HotelDetailPage extends StatefulWidget {
  final String hotelId;
  final Map<String, dynamic> hotelData;

  const HotelDetailPage({
    super.key,
    required this.hotelId,
    required this.hotelData,
  });

  @override
  State<HotelDetailPage> createState() => _HotelDetailPageState();
}

class _HotelDetailPageState extends State<HotelDetailPage> {
  final PageController _imageController = PageController();
  int _currentImage = 0;

  late DateTime _checkIn;
  late DateTime _checkOut;

  List<Map<String, dynamic>> _availableRooms = [];
  bool _loadingRooms = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _checkIn = DateTime(now.year, now.month, now.day);
    _checkOut = _checkIn.add(const Duration(days: 1));
    _loadAvailableRooms();
  }

  Future<void> _loadAvailableRooms() async {
    if (mounted) setState(() => _loadingRooms = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('hotels')
          .doc(widget.hotelId)
          .collection('rooms')
          .get();

      final list = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final d = Map<String, dynamic>.from(doc.data());
        d['id'] = doc.id;

        final totalRooms = (d['totalRooms'] as num?)?.toInt() ?? 0;
        final basePrice = (d['basePrice'] as num?)?.toDouble() ?? 0;

        final available = await RoomAvailability.getAvailableRooms(
          hotelId: widget.hotelId,
          roomId: doc.id,
          totalRooms: totalRooms,
          checkIn: _checkIn,
          checkOut: _checkOut,
        );

        if (available <= 0) continue;

        final totalPrice = await RoomAvailability.calculateTotalPrice(
          hotelId: widget.hotelId,
          roomId: doc.id,
          basePrice: basePrice,
          checkIn: _checkIn,
          checkOut: _checkOut,
        );

        d['availableCount'] = available;
        d['totalPriceForStay'] = totalPrice;
        list.add(d);
      }

      if (mounted) {
        setState(() {
          _availableRooms = list;
          _loadingRooms = false;
        });
      }
    } catch (e) {
      debugPrint('Load rooms error: $e');
      if (mounted) setState(() => _loadingRooms = false);
    }
  }

  Future<void> _pickDates() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _checkIn, end: _checkOut),
      builder: (context, child) {
        return Theme(
          data: Theme.of(
            context,
          ).copyWith(colorScheme: ColorScheme.light(primary: mainColor)),
          child: child!,
        );
      },
    );
    if (result != null) {
      setState(() {
        _checkIn = result.start;
        _checkOut = result.end;
      });
      _loadAvailableRooms();
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.hotelData;
    final images = List<String>.from(d['images'] ?? []);
    final amenities = List<String>.from(d['amenities'] ?? []);
    final services = List<String>.from(d['services'] ?? []);
    final rating = (d['rating'] as num?)?.toDouble() ?? 0;
    final totalReviews = (d['totalReviews'] as num?)?.toInt() ?? 0;
    final nights = _checkOut.difference(_checkIn).inDays;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280.h,
            pinned: true,
            backgroundColor: mainColor,
            foregroundColor: Colors.white,
            leading: Padding(
              padding: EdgeInsets.only(left: 12.w),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            actions: [
              StreamBuilder<bool>(
                stream: FavoritesHelper.isFavoriteStream(widget.hotelId),
                builder: (context, snap) {
                  final isFav = snap.data ?? false;
                  return IconButton(
                    icon: Icon(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      color: isFav ? Colors.red : Colors.white,
                    ),
                    onPressed: () async {
                      final added = await FavoritesHelper.toggleFavorite(
                        widget.hotelId,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              added
                                  ? 'เพิ่มในรายการโปรดแล้ว'
                                  : 'ลบจากรายการโปรดแล้ว',
                              style: styles(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: images.isEmpty
                  ? Container(
                      color: Colors.grey.shade300,
                      child: const Icon(
                        Icons.hotel,
                        size: 80,
                        color: Colors.white,
                      ),
                    )
                  : Stack(
                      children: [
                        PageView.builder(
                          controller: _imageController,
                          itemCount: images.length,
                          onPageChanged: (i) =>
                              setState(() => _currentImage = i),
                          itemBuilder: (_, i) => CachedNetworkImage(
                            imageUrl: images[i],
                            fit: BoxFit.cover,
                            memCacheWidth: 1200,
                            placeholder: (_, __) => Container(color: Colors.grey.shade300),
                            errorWidget: (_, __, ___) => Container(
                              color: Colors.grey.shade300,
                              child: const Icon(
                                Icons.broken_image,
                                color: Colors.white,
                                size: 60,
                              ),
                            ),
                          ),
                        ),
                        if (images.length > 1)
                          Positioned(
                            bottom: 16,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(images.length, (i) {
                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _currentImage == i
                                        ? Colors.white
                                        : Colors.white54,
                                  ),
                                );
                              }),
                            ),
                          ),
                        Positioned(
                          bottom: 12,
                          right: 16,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_currentImage + 1}/${images.length}',
                              style: styles(color: Colors.white, fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d['name'] as String? ?? '',
                    style: styles(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.purple[900],
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Row(
                    children: [
                      Text(
                        '${d['mainType'] ?? ''} • ',
                        style: styles(fontSize: 13.sp, color: Colors.grey[600]),
                      ),
                      Icon(Icons.star, color: Colors.amber, size: 18.sp),
                      SizedBox(width: 2.w),
                      Text(
                        '${rating.toStringAsFixed(1)} ($totalReviews รีวิว)',
                        style: styles(fontSize: 13.sp, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14.sp, color: Colors.grey),
                      SizedBox(width: 4.w),
                      Expanded(
                        child: Text(
                          [
                            d['address'],
                            d['district'],
                            d['province'],
                          ].where((v) => v != null && v != '').join(', '),
                          style: styles(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                    child: InkWell(
                      onTap: _pickDates,
                      borderRadius: BorderRadius.circular(2.r),
                      child: Padding(
                        padding: EdgeInsets.all(14.w),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: mainColor),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'วันที่เข้าพัก ($nights คืน)',
                                    style: styles(
                                      fontSize: 12.sp,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    '${DateFormat('d MMM').format(_checkIn)}  →  ${DateFormat('d MMM yyyy').format(_checkOut)}',
                                    style: styles(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.edit, size: 18.sp, color: mainColor),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  ExpansionTile(
                    initiallyExpanded: true,
                    title: Row(
                      children: [
                        Container(
                          width: 4.w,
                          height: 20.h,
                          decoration: BoxDecoration(
                            color: mainColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'รายละเอียด',
                          style: styles(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple[900],
                          ),
                        ),
                      ],
                    ),
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.only(bottom: 8.h),
                    shape: const Border(),
                    collapsedShape: const Border(),
                    children: [
                      if ((d['description'] as String? ?? '').isNotEmpty) ...[
                        Text(
                          d['description'] as String,
                          style: styles(
                            fontSize: 13.sp,
                            color: Colors.black87,
                            height: 1.2,
                          ),
                        ),
                        SizedBox(height: 6.h),
                      ],
                      if (amenities.isNotEmpty) ...[
                        _sectionTitle('สิ่งอำนวยความสะดวก'),
                        Wrap(
                          spacing: 6,
                          runSpacing: 0,
                          children: amenities.map((a) {
                            final display = a.startsWith('custom:')
                                ? a.substring(7)
                                : a;
                            return Chip(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6.w,
                                vertical: 2.h,
                              ),
                              label: Text(
                                display,
                                style: styles(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.black54,
                                ),
                              ),
                              backgroundColor: Colors.pink.shade50,
                            );
                          }).toList(),
                        ),
                        SizedBox(height: 6.h),
                      ],
                      if (services.isNotEmpty) ...[
                        _sectionTitle('บริการ'),
                        Wrap(
                          spacing: 6,
                          runSpacing: 0,
                          children: services.map((s) {
                            final display = s.startsWith('custom:')
                                ? s.substring(7)
                                : s;
                            return Chip(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6.w,
                                vertical: 2.w,
                              ),
                              label: Text(
                                display,
                                style: styles(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.black54,
                                ),
                              ),
                              backgroundColor: Colors.blue.shade50,
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),

                  SizedBox(height: 16.h),
                  _sectionTitle('เลือกห้องพัก'),
                  SizedBox(height: 16.h),
                  if (_loadingRooms)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.h),
                        child: CircularProgressIndicator(color: mainColor),
                      ),
                    )
                  else if (_availableRooms.isEmpty)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.h),
                        child: Column(
                          children: [
                            Icon(
                              Icons.event_busy,
                              size: 48.sp,
                              color: Colors.grey.shade300,
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              'ไม่มีห้องว่างในช่วงนี้',
                              style: styles(
                                color: Colors.grey,
                                fontSize: 14.sp,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            TextButton(
                              onPressed: _pickDates,
                              child: Text(
                                'เปลี่ยนวันที่',
                                style: styles(
                                  color: mainColor,
                                  fontSize: 13.sp,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Column(
                      children: _availableRooms
                          .map((r) => _roomCard(r, nights))
                          .toList(),
                    ),

                  Divider(thickness: 8.h, color: Colors.grey.shade100),
                  _buildReviewsSection(),

                  SizedBox(height: 40.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        children: [
          Container(
            width: 4.w,
            height: 18.h,
            decoration: BoxDecoration(
              color: mainColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            text,
            style: styles(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: Colors.purple[900],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roomCard(Map<String, dynamic> r, int nights) {
    final images = List<String>.from(r['images'] ?? []);
    final basePrice = (r['basePrice'] as num?)?.toDouble() ?? 0;
    final totalPrice = (r['totalPriceForStay'] as num?)?.toDouble() ?? 0;
    final available = (r['availableCount'] as int?) ?? 0;
    final maxGuests = (r['maxGuests'] as num?)?.toInt() ?? 0;
    final size = r['size'];

    return Card(
      margin: EdgeInsets.only(bottom: 16.h),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (images.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
              child: SizedBox(
                width: double.infinity,
                height: 140.h,
                child: GestureDetector(
                  onTap: () => _showImageGallery(images, 0),
                  child: CachedNetworkImage(
                    imageUrl: images.first,
                    fit: BoxFit.cover,
                    memCacheWidth: 800,
                    placeholder: (_, __) => Container(color: Colors.grey.shade200),
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.grey.shade200,
                      child: const Icon(
                        Icons.bed,
                        color: Colors.grey,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.all(14.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r['name'] as String? ?? '',
                  style: styles(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  [
                    r['roomType'],
                    if (size != null && size != '') '$size ตร.ม.',
                    'พัก $maxGuests คน',
                  ].where((v) => v != null).join(' • '),
                  style: styles(fontSize: 12.sp, color: Colors.grey[600]),
                ),
                if ((r['description'] as String? ?? '').isNotEmpty) ...[
                  SizedBox(height: 6.h),
                  Text(
                    r['description'] as String,
                    style: styles(fontSize: 12.sp, color: Colors.grey[700]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                SizedBox(height: 10.h),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: available <= 3
                        ? Colors.orange.shade50
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6.r),
                    border: Border.all(
                      color: available <= 3
                          ? Colors.orange.shade300
                          : Colors.green.shade300,
                    ),
                  ),
                  child: Text(
                    available <= 3
                        ? 'เหลือ $available ห้อง!'
                        : 'ว่าง $available ห้อง',
                    style: styles(
                      fontSize: 11.sp,
                      color: available <= 3
                          ? Colors.orange[800]
                          : Colors.green[800],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '฿${basePrice.toStringAsFixed(0)}/คืน',
                          style: styles(fontSize: 11.sp, color: Colors.grey),
                        ),
                        Text(
                          '฿${totalPrice.toStringAsFixed(0)}',
                          style: styles(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: mainColor,
                          ),
                        ),
                        Text(
                          'รวม $nights คืน',
                          style: styles(fontSize: 10.sp, color: Colors.grey),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mainColor,
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 12.h,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HotelBookingPage(
                              hotelId: widget.hotelId,
                              hotelData: widget.hotelData,
                              roomData: r,
                              checkIn: _checkIn,
                              checkOut: _checkOut,
                              totalPrice: totalPrice,
                            ),
                          ),
                        );
                      },
                      child: Text(
                        'เลือกห้องนี้',
                        style: styles(
                          color: Colors.white,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showImageGallery(List<String> images, int initialIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) {
        final controller = PageController(initialPage: initialIndex);
        int currentIndex = initialIndex;

        return Dialog.fullscreen(
          backgroundColor: Colors.transparent,
          child: StatefulBuilder(
            builder: (ctx, setSt) => Stack(
              children: [
                PageView.builder(
                  controller: controller,
                  itemCount: images.length,
                  onPageChanged: (i) => setSt(() => currentIndex = i),
                  itemBuilder: (_, i) => InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 10,
                    boundaryMargin: const EdgeInsets.all(double.infinity),
                    child: Center(
                      child: CachedNetworkImage(
                        imageUrl: images[i],
                        fit: BoxFit.contain,
                        memCacheWidth: 1200,
                        placeholder: (_, __) => const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                        errorWidget: (_, __, ___) => const Center(
                          child: Icon(
                            Icons.broken_image,
                            size: 80,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                Positioned(
                  top: MediaQuery.of(ctx).padding.top + 8,
                  left: 8,
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),

                Positioned(
                  top: MediaQuery.of(ctx).padding.top + 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${currentIndex + 1} / ${images.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

                if (images.length > 1 && images.length <= 8)
                  Positioned(
                    bottom: 32,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(images.length, (i) {
                        return Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == currentIndex
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.4),
                          ),
                        );
                      }),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReviewsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('hotel_reviews')
          .where('hotelId', isEqualTo: widget.hotelId)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.hasData ? snap.data!.docs : <QueryDocumentSnapshot>[];

        return ExpansionTile(
          initiallyExpanded: false,
          title: Row(
            children: [
              Container(
                width: 4.w,
                height: 20.h,
                decoration: BoxDecoration(
                  color: mainColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                'รีวิวจากผู้เข้าพัก (${docs.length})',
                style: styles(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.purple[900],
                ),
              ),
            ],
          ),
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.only(bottom: 8.h),
          shape: const Border(),
          collapsedShape: const Border(),
          children: [
            if (!snap.hasData)
              const SizedBox.shrink()
            else if (docs.isEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: Text(
                  'ยังไม่มีรีวิว',
                  style: styles(color: Colors.grey, fontSize: 13.sp),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.grey.shade200),
                itemBuilder: (_, i) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  final ratings = d['ratings'] as Map<String, dynamic>? ?? {};
                  final images = List<String>.from(d['images'] ?? []);
                  final createdAt = (d['createdAt'] as Timestamp?)?.toDate();

                  return Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 12.h,
                      horizontal: 4.w,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18.r,
                              backgroundImage:
                                  (d['guestImage'] ?? '').toString().isNotEmpty
                                  ? CachedNetworkImageProvider(d['guestImage'])
                                  : null,
                              child: (d['guestImage'] ?? '').toString().isEmpty
                                  ? Icon(Icons.person, size: 20.sp)
                                  : null,
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    d['guestName'] ?? '-',
                                    style: styles(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black45,
                                    ),
                                  ),
                                  if (createdAt != null)
                                    Text(
                                      '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                                      style: styles(
                                        fontSize: 10.sp,
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 16.sp,
                                ),
                                SizedBox(width: 2.w),
                                Text(
                                  (d['averageRating'] as num?)?.toStringAsFixed(
                                        1,
                                      ) ??
                                      '0',
                                  style: styles(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 6.h),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            _ratingChip('ความสะอาด', ratings['cleanliness']),
                            _ratingChip('การบริการ', ratings['service']),
                            _ratingChip('ความคุ้มค่า', ratings['value']),
                            _ratingChip('ทำเล', ratings['location']),
                          ],
                        ),
                        Text(
                          d['comment'] ?? '',
                          style: styles(
                            fontSize: 11.sp,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 4.h),
                        if (images.isNotEmpty) ...[
                          SizedBox(height: 4.h),
                          SizedBox(
                            height: 70.h,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: images.length,
                              separatorBuilder: (_, __) => SizedBox(width: 6.w),
                              itemBuilder: (_, idx) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(6.r),
                                  child: CachedNetworkImage(
                                    imageUrl: images[idx],
                                    width: 70.h,
                                    height: 70.h,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 400,
                                    placeholder: (_, __) => Container(color: Colors.grey.shade200),
                                    errorWidget: (_, __, ___) => Container(
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.broken_image, color: Colors.grey),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            if (docs.length >= 5)
              Padding(
                padding: EdgeInsets.only(top: 4.h),
                child: Center(
                  child: TextButton(
                    onPressed: () {},
                    child: Text('ดูทั้งหมด', style: styles(color: mainColor)),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _ratingChip(String label, dynamic value) {
    final v = (value as num?)?.toInt() ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: styles(fontSize: 10.sp, color: Colors.grey[700]),
        ),
        SizedBox(width: 2.w),
        Icon(Icons.star, color: Colors.amber, size: 10.sp),
        Text(
          ' $v',
          style: styles(fontSize: 10.sp, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _imageController.dispose();
    super.dispose();
  }
}
