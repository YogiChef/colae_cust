// ignore_for_file: use_build_context_synchronously, avoid_print, unnecessary_underscores, deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:colae_cut/services/sevice.dart';
import 'package:colae_cut/pages/hotel/hotel_detail_page.dart';
import 'package:colae_cut/pages/hotel/hotel_filter_page.dart';

class HotelSearchTab extends StatefulWidget {
  const HotelSearchTab({super.key});

  @override
  State<HotelSearchTab> createState() => _HotelSearchTabState();
}

class _HotelSearchTabState extends State<HotelSearchTab> {
  GoogleMapController? _mapController;
  final PageController _pageController = PageController(viewportFraction: 1);
  final TextEditingController _searchController = TextEditingController();

  Position? _myPosition;
  List<Map<String, dynamic>> _hotels = [];
  Set<Marker> _markers = {};
  bool _loading = true;

  final Map<String, dynamic> _filters = {
    'mainType': null,
    'province': null,
    'maxGuests': null,
    'minPrice': null,
    'maxPrice': null,
    'amenities': <String>[],
    'minRating': null,
    'sortBy': 'distance',
  };

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _getLocation();
    await _loadHotels();
  }

  Future<void> _getLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) return;
      }
      if (perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      if (mounted) setState(() => _myPosition = pos);
    } catch (e) {
      print('Location error: $e');
    }
  }

  Future<void> _loadHotels() async {
    if (mounted) setState(() => _loading = true);
    try {
      Query query = FirebaseFirestore.instance.collection('hotels');

      if (_filters['mainType'] != null) {
        query = query.where('mainType', isEqualTo: _filters['mainType']);
      }
      if (_filters['province'] != null) {
        query = query.where('province', isEqualTo: _filters['province']);
      }

      final snap = await query.get();
      final list = <Map<String, dynamic>>[];

      for (final doc in snap.docs) {
        final d = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        d['id'] = doc.id;

        // คำนวณ distance
        if (_myPosition != null && d['location'] != null) {
          final loc = d['location'] as GeoPoint;
          d['distance'] =
              Geolocator.distanceBetween(
                _myPosition!.latitude,
                _myPosition!.longitude,
                loc.latitude,
                loc.longitude,
              ) /
              1000;
        } else {
          d['distance'] = 9999.0;
        }

        try {
          final roomsSnap = await FirebaseFirestore.instance
              .collection('hotels')
              .doc(doc.id)
              .collection('rooms')
              .orderBy('basePrice')
              .limit(1)
              .get();
          if (roomsSnap.docs.isNotEmpty) {
            d['minPrice'] =
                (roomsSnap.docs.first.data()['basePrice'] as num?)
                    ?.toDouble() ??
                0.0;
          } else {
            d['minPrice'] = 0.0;
          }
        } catch (_) {
          d['minPrice'] = 0.0;
        }

        final minPrice = _filters['minPrice'];
        final maxPrice = _filters['maxPrice'];
        final minRating = _filters['minRating'];
        if (minPrice != null &&
            (d['minPrice'] as double) < (minPrice as double)) {
          continue;
        }
        if (maxPrice != null &&
            (d['minPrice'] as double) > (maxPrice as double)) {
          continue;
        }
        if (minRating != null &&
            ((d['rating'] as num?) ?? 0) < (minRating as double)) {
          continue;
        }

        final selectedAmenities = List<String>.from(
          _filters['amenities'] ?? [],
        );
        if (selectedAmenities.isNotEmpty) {
          final hotelAmenities = List<String>.from(d['amenities'] ?? []);
          if (!selectedAmenities.every((a) => hotelAmenities.contains(a))) {
            continue;
          }
        }
        final searchText = _searchController.text.trim().toLowerCase();
        if (searchText.isNotEmpty) {
          final name = (d['name'] ?? '').toString().toLowerCase();
          final province = (d['province'] ?? '').toString().toLowerCase();
          if (!name.contains(searchText) && !province.contains(searchText)) {
            continue;
          }
        }

        list.add(d);
      }
      final sortBy = _filters['sortBy'] as String? ?? 'distance';
      list.sort((a, b) {
        switch (sortBy) {
          case 'price_asc':
            return (a['minPrice'] as double).compareTo(b['minPrice'] as double);
          case 'price_desc':
            return (b['minPrice'] as double).compareTo(a['minPrice'] as double);
          case 'rating':
            return ((b['rating'] as num?) ?? 0).compareTo(
              (a['rating'] as num?) ?? 0,
            );
          case 'newest':
            final ta = a['createdAt'] as Timestamp?;
            final tb = b['createdAt'] as Timestamp?;
            if (ta == null || tb == null) return 0;
            return tb.compareTo(ta);
          default:
            return (a['distance'] as double).compareTo(b['distance'] as double);
        }
      });

      final markers = <Marker>{};
      for (int i = 0; i < list.length; i++) {
        final d = list[i];
        if (d['location'] == null) continue;
        final loc = d['location'] as GeoPoint;
        final index = i;
        markers.add(
          Marker(
            markerId: MarkerId(d['id'] as String),
            position: LatLng(loc.latitude, loc.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange,
            ),
            infoWindow: InfoWindow(
              title: d['name'] as String? ?? '',
              snippet: '฿${(d['minPrice'] as double).toStringAsFixed(0)}/คืน',
            ),
            onTap: () {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
          ),
        );
      }

      if (mounted) {
        setState(() {
          _hotels = list;
          _markers = markers;
          _loading = false;
        });
      }
    } catch (e) {
      print('Load hotels error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onCardChanged(int index) {
    if (index >= _hotels.length) return;
    final d = _hotels[index];
    if (d['location'] == null) return;
    final loc = d['location'] as GeoPoint;
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(loc.latitude, loc.longitude), 14),
    );
  }

  Future<void> _openFilter() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => HotelFilterPage(currentFilters: _filters),
      ),
    );
    if (result != null) {
      setState(() => _filters.addAll(result));
      _loadHotels();
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialPos = _myPosition != null
        ? LatLng(_myPosition!.latitude, _myPosition!.longitude)
        : const LatLng(13.7563, 100.5018); // Bangkok default

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 45.h,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'ค้นหาที่พัก...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _loadHotels();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(7.r),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade200,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 16.w,
                    ),
                  ),
                  onSubmitted: (_) => _loadHotels(),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.filter_list_outlined, color: Colors.white),
              onPressed: _openFilter,
            ),
          ],
        ),
        backgroundColor: mainColor,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(12.h),
          child: Container(height: 12.h, color: mainColor),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  _loading
                      ? Center(
                          child: CircularProgressIndicator(color: mainColor),
                        )
                      : GoogleMap(
                          key: const ValueKey('hotel_map'),
                          initialCameraPosition: CameraPosition(
                            target: initialPos,
                            zoom: 12,
                          ),
                          markers: _markers,
                          myLocationEnabled: true,
                          myLocationButtonEnabled: true,
                          zoomControlsEnabled: true,
                          mapType: MapType.normal,
                          onMapCreated: (c) => _mapController = c,
                        ),

                  if (!_loading)
                    Positioned(
                      bottom: 6.h,
                      left: 0,
                      right: 0,
                      height: 190.h,
                      child: _hotels.isEmpty
                          ? Center(
                              child: Container(
                                width: double.infinity,
                                height: 190.h,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 20.w,
                                  vertical: 12.h,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12.r),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Image.asset(
                                      'images/waiting.webp',
                                      width: 170.w,
                                      height: 130.h,
                                      fit: BoxFit.cover,
                                    ),
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(height: 4.h),
                                          Text(
                                            'ไม่พบที่พัก',
                                            style: styles(
                                              color: Colors.red,
                                              fontSize: 20.sp,
                                              fontWeight: FontWeight.w300,
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: _openFilter,
                                            child: Text(
                                              'ลองเปลี่ยนตัวกรอง',
                                              style: styles(
                                                color: Colors.amber,
                                                fontSize: 12.sp,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : PageView.builder(
                              controller: _pageController,
                              itemCount: _hotels.length,
                              onPageChanged: _onCardChanged,
                              itemBuilder: (_, i) => Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6.w),
                                child: _hotelCard(_hotels[i]),
                              ),
                            ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hotelCard(Map<String, dynamic> d) {
    final images = List<String>.from(d['images'] ?? []);
    final rating = (d['rating'] as num?)?.toDouble() ?? 0.0;
    final totalReviews = (d['totalReviews'] as num?)?.toInt() ?? 0;
    final minPrice = (d['minPrice'] as num?)?.toDouble() ?? 0.0;
    final distance = (d['distance'] as num?)?.toDouble() ?? 0.0;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                HotelDetailPage(hotelId: d['id'] as String, hotelData: d),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2.r),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.horizontal(left: Radius.circular(2.r)),
              child: Container(
                padding: EdgeInsets.only(top: 12.h, bottom: 12.h),
                width: 170.w,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(7.r),
                  ),
                ),
                height: double.infinity,
                child: images.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: images.first,
                        fit: BoxFit.cover,
                        memCacheWidth: 800,
                        placeholder: (_, __) => Container(color: Colors.grey.shade200),
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(
                            Icons.hotel,
                            color: Colors.grey,
                            size: 40,
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.grey.shade200,
                        child: const Icon(
                          Icons.hotel,
                          color: Colors.grey,
                          size: 40,
                        ),
                      ),
              ),
            ),
            // ข้อมูล
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(12.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          d['name'] as String? ?? '-',
                          style: styles(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          '${d['mainType'] ?? ''} • ${d['province'] ?? ''}',
                          style: styles(
                            fontSize: 11.sp,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 14.sp),
                            SizedBox(width: 2.w),
                            Text(
                              rating.toStringAsFixed(1),
                              style: styles(fontSize: 11.sp),
                            ),
                            Text(
                              ' ($totalReviews)',
                              style: styles(
                                fontSize: 11.sp,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              ' • ',
                              style: styles(
                                fontSize: 11.sp,
                                color: Colors.grey,
                              ),
                            ),
                            Icon(
                              Icons.location_on,
                              size: 12.sp,
                              color: Colors.grey,
                            ),
                            Text(
                              distance < 9999
                                  ? '${distance.toStringAsFixed(1)} กม.'
                                  : '-',
                              style: styles(
                                fontSize: 11.sp,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'เริ่มต้น',
                          style: styles(fontSize: 10.sp, color: Colors.grey),
                        ),
                        Text(
                          '฿${minPrice.toStringAsFixed(0)}',
                          style: styles(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: mainColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }
}
