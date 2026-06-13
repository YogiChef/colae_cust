// ignore_for_file: use_build_context_synchronously, unnecessary_underscores

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:colae_cut/tabs/explore_tab.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:colae_cut/pages/hotel/hotel_detail_page.dart';
import 'package:colae_cut/pages/hotel/helpers/favorites_helper.dart';
import 'package:colae_cut/services/sevice.dart';

class HotelFavoritesTab extends StatelessWidget {
  const HotelFavoritesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'รายการโปรด',
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
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('buyers')
            .doc(uid)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return Center(child: CircularProgressIndicator(color: mainColor));
          }
          final data = snap.data?.data() as Map<String, dynamic>? ?? {};
          final favIds = List<String>.from(data['favoriteHotels'] ?? []);

          if (favIds.isEmpty) {
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
                    'ยังไม่มีรายการโปรด',
                    style: styles(fontSize: 16.sp, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _loadHotels(favIds),
            builder: (context, hotelsSnap) {
              if (!hotelsSnap.hasData) {
                return Center(
                  child: CircularProgressIndicator(color: mainColor),
                );
              }
              final hotels = hotelsSnap.data!;
              return ListView.builder(
                padding: EdgeInsets.all(12.w),
                itemCount: hotels.length,
                itemBuilder: (_, i) => _hotelCard(context, hotels[i]),
              );
            },
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadHotels(List<String> ids) async {
    final list = <Map<String, dynamic>>[];
    for (final id in ids) {
      final doc = await FirebaseFirestore.instance
          .collection('hotels')
          .doc(id)
          .get();
      if (doc.exists) {
        final d = Map<String, dynamic>.from(doc.data()!);
        d['id'] = id;
        try {
          final roomsSnap = await FirebaseFirestore.instance
              .collection('hotels')
              .doc(id)
              .collection('rooms')
              .orderBy('basePrice')
              .limit(1)
              .get();
          d['minPrice'] = roomsSnap.docs.isNotEmpty
              ? (roomsSnap.docs.first.data()['basePrice'] as num?)
                        ?.toDouble() ??
                    0.0
              : 0.0;
        } catch (_) {
          d['minPrice'] = 0.0;
        }
        list.add(d);
      }
    }
    return list;
  }

  Widget _hotelCard(BuildContext context, Map<String, dynamic> d) {
    final images = List<String>.from(d['images'] ?? []);
    final rating = (d['rating'] as num?)?.toDouble() ?? 0;
    final totalReviews = (d['totalReviews'] as num?)?.toInt() ?? 0;
    final minPrice = (d['minPrice'] as num?)?.toDouble() ?? 0;

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  HotelDetailPage(hotelId: d['id'] as String, hotelData: d),
            ),
          );
        },
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(4),
              ),
              child: SizedBox(
                width: 130.w,
                height: 120.h,
                child: images.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: images.first,
                        fit: BoxFit.cover,
                        memCacheWidth: 400,
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
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(12.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d['name'] as String? ?? '-',
                          style: styles(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          '${d['mainType'] ?? ''} • ${d['province'] ?? ''}',
                          style: styles(
                            fontSize: 11.sp,
                            color: Colors.grey[700],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4.h),
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 14.sp),
                            SizedBox(width: 2.w),
                            Text(
                              '${rating.toStringAsFixed(1)} ($totalReviews)',
                              style: styles(
                                fontSize: 11.sp,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
            IconButton(
              icon: const Icon(Icons.favorite, color: Colors.red),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(
                      'ลบจากรายการโปรด?',
                      style: styles(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w400,
                        color: Colors.black54,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('ยกเลิก'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text('ลบ', style: styles(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await FavoritesHelper.toggleFavorite(d['id'] as String);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
