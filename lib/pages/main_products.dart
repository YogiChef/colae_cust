// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:colae_cut/services/deli_service.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:colae_cut/tabs/cart_tab/cart_page.dart';
import 'package:colae_cut/pages/minor_page/qr_payment.dart';
import 'package:colae_cut/pages/product_detail.dart';
import 'package:colae_cut/providers/cart_provider.dart';
import 'package:colae_cut/services/sevice.dart';
import 'package:badges/badges.dart' as badges;
import 'package:cached_network_image/cached_network_image.dart';

class MainProductPage extends StatefulWidget {
  final String vendorid;
  final String? tableNumber;
  final bool fromQr;

  const MainProductPage({
    super.key,
    required this.vendorid,
    this.tableNumber,
    this.fromQr = false,
  });

  @override
  State<MainProductPage> createState() => _MainProductPageState();
}

class _MainProductPageState extends State<MainProductPage> {
  bool following = false;
  late final Future<DocumentSnapshot> _vendorFuture;
  late final Stream<QuerySnapshot> _productsStream;

  double? _buyerLat;
  double? _buyerLng;
  bool _locationChecked = false;

  @override
  void initState() {
    super.initState();
    _vendorFuture = firestore.collection('vendors').doc(widget.vendorid).get();
    _productsStream = firestore
        .collection('products')
        .where('vendorId', isEqualTo: widget.vendorid)
        .snapshots();
    _loadBuyerLocation();
    if (widget.tableNumber != null && widget.tableNumber!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Provider.of<CartProvider>(
            context,
            listen: false,
          ).setTableId(widget.tableNumber!);
        }
      });
    } else if (widget.fromQr) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Provider.of<CartProvider>(
            context,
            listen: false,
          ).setServiceType('dine-in');
        }
      });
    }
  }

  Future<void> _loadBuyerLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedLat = prefs.getDouble('buyer_lat');
      final cachedLng = prefs.getDouble('buyer_lng');
      if (cachedLat != null && cachedLng != null && mounted) {
        setState(() {
          _buyerLat = cachedLat;
          _buyerLng = cachedLng;
          _locationChecked = true;
        });
      }
    } catch (_) {}

    _updateLocationInBackground();
  }

  Future<void> _updateLocationInBackground() async {
    try {
      LocationPermission p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) {
        if (mounted && !_locationChecked) {
          setState(() => _locationChecked = true);
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('buyer_lat', pos.latitude);
      await prefs.setDouble('buyer_lng', pos.longitude);
      if (mounted) {
        setState(() {
          _buyerLat = pos.latitude;
          _buyerLng = pos.longitude;
          _locationChecked = true;
        });
      }
    } catch (_) {
      if (mounted && !_locationChecked) {
        setState(() => _locationChecked = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: _vendorFuture,
      builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'เกิดข้อผิดพลาดในการโหลดร้าน\n(อาจเพราะร้านยังไม่ผ่านการตรวจสอบ)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18.sp, color: Colors.red),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator(color: mainColor)),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            body: Center(
              child: Text(
                'ไม่พบข้อมูลร้านค้า',
                style: TextStyle(fontSize: 18.sp),
              ),
            ),
          );
        }

        Map<String, dynamic> data =
            snapshot.data!.data() as Map<String, dynamic>;

        if (!(data['approved'] ?? false)) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 80.sp, color: Colors.orange),
                  SizedBox(height: 20.h),
                  Text(
                    'ร้านนี้ยังไม่เปิดให้บริการ\n(รอ admin ตรวจสอบ)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18.sp, color: Colors.red),
                  ),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(120.w),
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(),
                    color: mainColor,
                  ),
                  child: ClipRRect(
                    child: Hero(
                      tag: 'proName${data['bussiName']}',
                      child: CachedNetworkImage(
                        imageUrl: data['image'],
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            Container(color: Colors.grey.shade300),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.store),
                      ),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.only(
                              top: 50.h,
                              right: 8.w,
                              left: 12.w,
                            ),
                            child: Text(
                              data['bussinessName'].toUpperCase(),
                              style: styles(
                                color: Colors.white,
                                fontSize: 20.sp,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: 40.h,
                  left: 18.w,
                  child: CircleAvatar(
                    radius: 18.r,
                    backgroundColor: Colors.yellow.shade50,
                    child: IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: Icon(
                        Icons.arrow_back,
                        size: 20.r,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          body: !_locationChecked
              ? Center(child: CircularProgressIndicator(color: mainColor))
              : StreamBuilder<QuerySnapshot>(
                  stream: _productsStream,
                  builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                    if (snapshot.hasError) {
                      debugPrint('Products stream error: ${snapshot.error}');
                      return Center(
                        child: Text(
                          'เกิดข้อผิดพลาดในการโหลดสินค้า\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14.sp, color: Colors.red),
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final vendorLocation = data['location'] as GeoPoint?;
                    final approvedDocs = snapshot.data!.docs
                        .where((doc) => doc['approved'] == true)
                        .where((doc) {
                          final pdata = doc.data() as Map<String, dynamic>;
                          final saleMode =
                              pdata['saleMode'] as String? ?? 'delivery';
                          return DeliService.isProductVisibleByDistance(
                            saleMode: saleMode,
                            vendorLocation: vendorLocation,
                            buyerLat: _buyerLat,
                            buyerLng: _buyerLng,
                          );
                        })
                        .toList();
                    if (approvedDocs.isEmpty) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: 20.h),
                          Image.asset('images/waiting.webp', width: 200.w),
                          Center(
                            child: Text(
                              'ยังไม่มีสินค้าในร้านนี้',
                              textAlign: TextAlign.center,
                              style: styles(
                                fontSize: 20.sp,
                                color: Colors.yellow.shade900,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    return GridView.builder(
                      itemCount: approvedDocs.length,
                      padding: EdgeInsets.only(
                        left: 2.w,
                        right: 2.w,
                        top: 6.h,
                        bottom: 80.h,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        mainAxisExtent: 290.h,
                        crossAxisCount: 2,
                        crossAxisSpacing: 6.w,
                        mainAxisSpacing: 6.h,
                        childAspectRatio: 0.82,
                      ),
                      itemBuilder: (BuildContext context, int index) {
                        final productData = approvedDocs[index];
                        final List<dynamic> imageList =
                            productData['imageUrl'] ?? [];
                        final String imageUrl = imageList.isNotEmpty
                            ? imageList[0].toString()
                            : '';
                        final bool trackStock = (productData.data() as Map<String, dynamic>)['trackStock'] as bool? ?? true;
                        final bool isOutOfStock = trackStock && (productData['pqty'] <= 0);
                        final bool lowStock =
                            trackStock &&
                            (productData['pqty'] > 0) &&
                            (productData['pqty'] <= 10);

                        return GestureDetector(
                          onTap: isOutOfStock
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ProductDetail(
                                        productData: productData,
                                      ),
                                    ),
                                  );
                                },
                          child: Card(
                            elevation: 2,
                            color: Colors.white,
                            margin: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(2.r),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 210.h,
                                  width: double.infinity,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(4.r),
                                    ),
                                    child: Stack(
                                      children: [
                                        Hero(
                                          tag: 'product_${productData.id}',
                                          child: CachedNetworkImage(
                                            imageUrl: imageUrl,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: 210.h,
                                            placeholder: (context, url) =>
                                                Container(
                                                  color: Colors.grey.shade200,
                                                ),
                                            errorWidget:
                                                (
                                                  context,
                                                  url,
                                                  error,
                                                ) => Container(
                                                  color: Colors.grey.shade200,
                                                  alignment: Alignment.center,
                                                  child: Icon(
                                                    Icons.image_not_supported,
                                                    size: 60.sp,
                                                  ),
                                                ),
                                          ),
                                        ),

                                        if (isOutOfStock)
                                          Positioned.fill(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.black.withAlpha(
                                                  165,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.vertical(
                                                      top: Radius.circular(4),
                                                    ),
                                              ),
                                              child: const Center(
                                                child: Text(
                                                  'สินค้ารอเติม',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          )
                                        else if (lowStock)
                                          Positioned(
                                            top: 8.h,
                                            right: 8.w,
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 10.w,
                                                vertical: 4.h,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.orange,
                                                borderRadius:
                                                    BorderRadius.circular(2.r),
                                              ),
                                              child: Text(
                                                'เหลือน้อย',
                                                textAlign: TextAlign.center,
                                                style: styles(
                                                  fontSize: 13.sp,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: 6.h),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10.w,
                                    vertical: 6.h,
                                  ),
                                  child: Text(
                                    productData['proName'] ?? 'ไม่มีชื่อสินค้า',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: styles(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w600,
                                      color: isOutOfStock
                                          ? Colors.deepOrange[900]
                                          : Colors.black54,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.only(
                                    right: 10.w,
                                    left: 10.w,
                                    bottom: 4.h,
                                  ),
                                  child: Text(
                                    '฿${(productData['price'] ?? 0).toStringAsFixed(0)}',
                                    style: styles(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w600,
                                      color: isOutOfStock
                                          ? Colors.grey
                                          : (lowStock
                                                ? Colors.deepOrange[900]
                                                : Colors.black54),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
          floatingActionButton: SafeArea(
            child: Consumer<CartProvider>(
              builder: (context, cartProvider, _) {
                if (cartProvider.getCartItem.isEmpty) return const SizedBox();
                return FloatingActionButton(
                  backgroundColor: mainColor,
                  child: badges.Badge(
                    showBadge: cartProvider.getCartItem.isNotEmpty,
                    badgeStyle: badges.BadgeStyle(
                      shape: badges.BadgeShape.circle,
                      borderSide: BorderSide(color: Colors.white, width: 1.5),
                      borderRadius: BorderRadius.circular(100),
                      badgeColor: Colors.redAccent,
                      padding: EdgeInsetsGeometry.all(6),
                    ),
                    badgeContent: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Text(
                        cartProvider.getCartItem.length.toString(),
                        style: styles(color: Colors.white, fontSize: 12.sp),
                      ),
                    ),
                    child: Icon(
                      Icons.shopping_cart,
                      color: Colors.white,
                      size: 35.sp,
                    ),
                  ),
                  onPressed: () {
                    if (cartProvider.isDineIn) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const QrPaymentPage(),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CartPage()),
                      );
                    }
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}
