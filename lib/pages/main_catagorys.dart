// ignore_for_file: no_leading_underscores_for_local_identifiers, deprecated_member_use, unnecessary_underscores

import 'dart:math' as math; // ใหม่: สำหรับ Haversine formula

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:colae_cut/models/vendor_model.dart';
import 'package:colae_cut/services/deli_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart'; // ใหม่: สำหรับดึงตำแหน่ง
import 'package:colae_cut/pages/main_products.dart';
import 'package:colae_cut/services/sevice.dart';

class CategoryHome extends StatefulWidget {
  final String? bussinessName;
  final bool isParentLoading;
  const CategoryHome({
    super.key,
    this.bussinessName,
    this.isParentLoading = false,
  });

  @override
  State<CategoryHome> createState() => _CategoryHomeState();
}

class _CategoryHomeState extends State<CategoryHome> {
  double? userLat, userLng;
  bool _isLoadingLocation = true;
  Stream<QuerySnapshot>? _vendorStream;

  @override
  void initState() {
    super.initState();
    _initFast();
  }

  @override
  void didUpdateWidget(CategoryHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bussinessName != widget.bussinessName) {
      setState(() {
        _vendorStream = FirebaseFirestore.instance
            .collection('vendors')
            .where('category', isEqualTo: widget.bussinessName)
            .where('approved', isEqualTo: true)
            .snapshots();
      });
    }
  }

  Future<void> _initFast() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && mounted) {
        setState(() {
          userLat = last.latitude;
          userLng = last.longitude;
          _isLoadingLocation = false;
          _vendorStream = FirebaseFirestore.instance
              .collection('vendors')
              .where('category', isEqualTo: widget.bussinessName)
              .where('approved', isEqualTo: true)
              .snapshots();
        });
        return;
      }
    } catch (_) {}
    await _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _isLoadingLocation = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _isLoadingLocation = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _isLoadingLocation = false);
      return;
    }

    Position? lastPos = await Geolocator.getLastKnownPosition();
    if (lastPos != null && mounted) {
      setState(() {
        userLat = lastPos.latitude;
        userLng = lastPos.longitude;
        _isLoadingLocation = false;
        _vendorStream = FirebaseFirestore.instance
            .collection('vendors')
            .where('category', isEqualTo: widget.bussinessName)
            .where('approved', isEqualTo: true)
            .snapshots();
      });
    }
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
      if (mounted) {
        setState(() {
          userLat = position.latitude;
          userLng = position.longitude;
          _isLoadingLocation = false;
          _vendorStream = FirebaseFirestore.instance
              .collection('vendors')
              .where('category', isEqualTo: widget.bussinessName)
              .where('approved', isEqualTo: true)
              .snapshots();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadius = 6371; // รัศมีโลก (กม.)

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLng = _degreesToRadians(lng2 - lng1);
    double lat1Rad = _degreesToRadians(lat1);
    double lat2Rad = _degreesToRadians(lat2);

    double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isParentLoading) {
      return const SizedBox.shrink();
    }

    if (_isLoadingLocation) {
      return const Center(child: SizedBox.shrink());
    }
    if (userLat == null || userLng == null) {
      return const Center(child: Text('ไม่สามารถดึงตำแหน่งได้ กรุณาเปิด GPS'));
    }

    return StreamBuilder(
      stream: _vendorStream,
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Something went wrong'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.red),
          );
        }

        final filteredDocs = snapshot.data!.docs
            .map((doc) {
              final vendor = VendorModel.fromJson(
                doc.data() as Map<String, dynamic>,
              );
              if (vendor.location == null) {
                return null;
              }
              final distance = _calculateDistance(
                userLat!,
                userLng!,
                vendor.location!.latitude,
                vendor.location!.longitude,
              );
              return distance <= 10.0 ? doc : null;
            })
            .whereType<QueryDocumentSnapshot>()
            .toList();

        if (filteredDocs.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                userLat = null;
                userLng = null;
                _isLoadingLocation = true;
                _vendorStream = null;
              });
              await _getCurrentLocation();
            },
            color: Colors.red,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 20.h),
                    Image.asset('images/waiting.webp', width: 200.w),
                    Center(
                      child: Text(
                        'ไม่มีร้านค้าในหมวดนี้\nในรัศมี 10 กม.',
                        textAlign: TextAlign.center,
                        style: styles(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: 110.h, top: 10.h),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final storeData = filteredDocs[index];
            final VendorModel vendor = VendorModel.fromJson(
              storeData.data() as Map<String, dynamic>,
            );
            final bool isOpen = DeliService.isStoreOpenNow(vendor.storeHours);
            final String formattedHours = DeliService.formatStoreHours(
              vendor.storeHours,
            );

            final double distance = _calculateDistance(
              userLat!,
              userLng!,
              vendor.location!.latitude,
              vendor.location!.longitude,
            );

            return GestureDetector(
              onTap: isOpen
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              MainProductPage(vendorid: storeData['vendorId']),
                        ),
                      );
                    }
                  : null,
              child: Card(
                margin: EdgeInsets.only(left: 8.w, right: 8.w, bottom: 12.h),
                color: Colors.white,
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: SizedBox(
                  height: 190.h,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w),
                        height: 170.h,
                        width: 170.w,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6.r),
                          child: CachedNetworkImage(
                            imageUrl: storeData['image'],
                            fit: BoxFit.cover,
                            maxWidthDiskCache: 300,
                            maxHeightDiskCache: 300,
                            placeholder: (_, __) =>
                                Container(color: Colors.grey.shade200),
                            errorWidget: (_, __, ___) =>
                                const Icon(Icons.store, color: Colors.grey),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0.w),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  storeData['bussinessName'],
                                  overflow: TextOverflow.ellipsis,
                                  style: styles(
                                    fontSize: 16.sp,
                                    height: 1,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              SizedBox(height: 6.h),
                              Flexible(
                                child: Text(
                                  '${storeData['address']}, ${storeData['district']}',
                                  overflow: TextOverflow.ellipsis,
                                  style: styles(
                                    color: Colors.grey,
                                    height: 1,
                                    fontSize: 11.sp,
                                  ),
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  '${storeData['province']} ${storeData['vzipcode']}',
                                  overflow: TextOverflow.ellipsis,
                                  style: styles(
                                    color: Colors.grey,
                                    height: 1,
                                    fontSize: 11.sp,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.only(top: 4.h, bottom: 4.h),
                                child: Text(
                                  '${distance.toStringAsFixed(1)} km',
                                  style: styles(
                                    color: Colors.blue.shade600,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 2.h,
                                ),
                                decoration: BoxDecoration(
                                  color: isOpen ? mainColor : Colors.orange,
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!isOpen) ...[
                                      Icon(
                                        Icons.lock_outline,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 4.w),
                                    ],
                                    Text(
                                      isOpen ? 'เปิด' : 'ปิด',
                                      style: styles(
                                        fontSize: 10.sp,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.only(top: 2.h),
                                child: Text(
                                  formattedHours,
                                  style: styles(
                                    fontSize: 12.sp,
                                    color: Colors.deepOrange,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
