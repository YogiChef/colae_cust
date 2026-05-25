// ignore_for_file: unnecessary_underscores

import 'dart:async';

import 'package:colae_cut/models/vendor_model.dart';
import 'package:colae_cut/pages/minor_page/qr_payment.dart';
import 'package:colae_cut/providers/cart_provider.dart';
import 'package:colae_cut/services/deli_service.dart';
import 'package:colae_cut/pages/product_detail.dart';
import 'package:colae_cut/tabs/cart_tab/cart_page.dart';
import 'package:flutter/rendering.dart';
import 'package:badges/badges.dart' as badges;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:colae_cut/services/sevice.dart';
import 'package:provider/provider.dart';

class ProductsTab extends StatefulWidget {
  final VoidCallback? onScrollDown;
  final VoidCallback? onScrollUp;
  const ProductsTab({super.key, this.onScrollDown, this.onScrollUp});
  @override
  State<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<ProductsTab> {
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  late final Stream<QuerySnapshot> _productsStream;

  final Map<String, bool> _vendorOpenStatus = {};
  final Map<String, StreamSubscription<DocumentSnapshot>> _vendorSubs = {};

  void _subscribeVendor(String vendorId) {
    if (vendorId.isEmpty || _vendorSubs.containsKey(vendorId)) return;
    _vendorSubs[vendorId] = FirebaseFirestore.instance
        .collection('vendors')
        .doc(vendorId)
        .snapshots()
        .listen((snap) {
          if (!snap.exists || !mounted) return;
          final vendor = VendorModel.fromJson(
            snap.data() as Map<String, dynamic>,
          );
          final isOpen =
              !vendor.temporarilyClosed &&
              DeliService.isStoreOpenNow(vendor.storeHours);
          if (_vendorOpenStatus[vendorId] != isOpen) {
            _vendorOpenStatus[vendorId] = isOpen;
            if (mounted) setState(() {});
          }
        });
  }

  void _unsubscribeAllVendors() {
    for (final sub in _vendorSubs.values) {
      sub.cancel();
    }
    _vendorSubs.clear();
    _vendorOpenStatus.clear();
  }

  @override
  void initState() {
    super.initState();
    _productsStream = FirebaseFirestore.instance
        .collection('products')
        .where('approved', isEqualTo: true)
        .orderBy('proName')
        .snapshots();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _unsubscribeAllVendors();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.userScrollDirection ==
        ScrollDirection.reverse) {
      widget.onScrollDown?.call();
    } else if (_scrollController.position.userScrollDirection ==
        ScrollDirection.forward) {
      widget.onScrollUp?.call();
    }
  }

  List<QueryDocumentSnapshot> _applyFilter(List<QueryDocumentSnapshot> docs) {
    for (final doc in docs) {
      final vendorId =
          (doc.data() as Map<String, dynamic>)['vendorId'] as String? ?? '';
      _subscribeVendor(vendorId);
    }
    final openDocs = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final vendorId = data['vendorId'] as String? ?? '';
      return _vendorOpenStatus[vendorId] ?? true;
    }).toList();

    if (_searchQuery.isEmpty) return openDocs;
    final q = _searchQuery.toLowerCase();
    return openDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['proName'] ?? '').toString().toLowerCase();
      final store = (data['bussinessName'] ?? '').toString().toLowerCase();
      return name.contains(q) || store.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _productsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('ProductsTab stream error: ${snapshot.error}');
        }
        final allDocs = snapshot.data?.docs ?? [];
        final items = _applyFilter(allDocs);
        return Scaffold(
          backgroundColor: Color(0xFFF5F5F5),
          appBar: AppBar(
            backgroundColor: mainColor,
            elevation: 0,
            centerTitle: true,
            automaticallyImplyLeading: false,
            title: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ค้นหา...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16.w,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(12.h),
              child: Container(height: 12.h, color: mainColor),
            ),
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              _unsubscribeAllVendors();
            },
            color: mainColor,
            child:
                items.isEmpty &&
                    snapshot.connectionState != ConnectionState.waiting
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('images/emptyproduct.png', width: 250.w),

                        Text(
                          _searchQuery.isNotEmpty
                              ? 'ไม่พบสินค้าที่ค้นหา'
                              : 'ยังไม่มีสินค้า',
                          style: styles(
                            fontSize: 20.sp,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.only(
                      bottom: 70.h,
                      right: 1.w,
                      left: 1.w,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 6.w,
                      mainAxisSpacing: 6.h,
                      childAspectRatio: 0.62,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final data = items[index].data() as Map<String, dynamic>;
                      final String proName = data['proName'] ?? 'ไม่มีชื่อ';
                      final double price =
                          (data['price'] as num?)?.toDouble() ?? 0.0;
                      final int pqty = (data['pqty'] as num?)?.toInt() ?? 0;
                      final List imageList = data['imageUrl'] ?? [];
                      final String imageUrl = imageList.isNotEmpty
                          ? imageList.first.toString()
                          : '';
                      final bool outOfStock = pqty <= 0;

                      return GestureDetector(
                        onTap: outOfStock
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ProductDetail(productData: items[index]),
                                ),
                              ),
                        child: Card(
                          margin: EdgeInsets.zero,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(2.r),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 220.h,
                                width: double.infinity,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(2.r),
                                  ),
                                  child: Stack(
                                    children: [
                                      ColorFiltered(
                                        colorFilter: outOfStock
                                            ? const ColorFilter.matrix([
                                                0.2126,
                                                0.7152,
                                                0.0722,
                                                0,
                                                0,
                                                0.2126,
                                                0.7152,
                                                0.0722,
                                                0,
                                                0,
                                                0.2126,
                                                0.7152,
                                                0.0722,
                                                0,
                                                0,
                                                0,
                                                0,
                                                0,
                                                1,
                                                0,
                                              ])
                                            : const ColorFilter.mode(
                                                Colors.transparent,
                                                BlendMode.multiply,
                                              ),
                                        child: imageUrl.isNotEmpty
                                            ? CachedNetworkImage(
                                                imageUrl: imageUrl,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                height: 220.h,
                                                placeholder: (_, __) =>
                                                    Container(
                                                      color:
                                                          Colors.grey.shade200,
                                                    ),
                                                errorWidget: (_, __, ___) =>
                                                    Container(
                                                      color:
                                                          Colors.grey.shade200,
                                                      alignment:
                                                          Alignment.center,
                                                      child: Icon(
                                                        Icons.fastfood,
                                                        size: 60.sp,
                                                        color: Colors
                                                            .grey
                                                            .shade400,
                                                      ),
                                                    ),
                                              )
                                            : Container(
                                                color: Colors.grey.shade200,
                                                alignment: Alignment.center,
                                                child: Icon(
                                                  Icons.fastfood,
                                                  size: 60.sp,
                                                  color: Colors.grey.shade400,
                                                ),
                                              ),
                                      ),
                                      if (outOfStock)
                                        Positioned(
                                          top: 8.h,
                                          right: 8.w,
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8.w,
                                              vertical: 4.h,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              borderRadius:
                                                  BorderRadius.circular(8.r),
                                            ),
                                            child: Text(
                                              'หมด',
                                              style: styles(
                                                fontSize: 10.sp,
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
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10.w,
                                  vertical: 4.h,
                                ),
                                child: Text(
                                  proName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: styles(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: 10.w,
                                    bottom: 4.h,
                                  ),
                                  child: Text(
                                    '฿${price.toStringAsFixed(0)}',
                                    style: styles(
                                      fontSize: 13.sp,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
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
