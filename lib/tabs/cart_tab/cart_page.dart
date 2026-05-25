// ignore_for_file: use_build_context_synchronously, avoid_print, deprecated_member_use, unnecessary_underscores

import 'package:cart_stepper/cart_stepper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:colae_cut/models/cart_attributes.dart';
import 'package:colae_cut/pages/minor_page/qr_payment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:colae_cut/pages/minor_page/checkouts_page.dart';
import 'package:colae_cut/services/sevice.dart';
import 'package:colae_cut/widgets/dialog.dart';
import '../../../../providers/cart_provider.dart';

class CartPage extends StatefulWidget {
  final bool isParentLoading;
  final VoidCallback? onBackFromCart;

  const CartPage({
    super.key,
    this.isParentLoading = false,
    this.onBackFromCart,
  });

  @override
  State<CartPage> createState() => _CartPageState();
}

class _DistanceInfo {
  final double tooFarDistance;
  final double displayDistance;
  _DistanceInfo(this.tooFarDistance, this.displayDistance);
}

class _CartPageState extends State<CartPage> {
  bool _isChoosingService = false;
  double _calculateGroupSubtotal(List<CartAttr> items) {
    double subtotal = 0.0;
    for (var item in items) {
      final extraPrice = item.extraPrice ?? 0.0;
      final quantitySafe = item.quantity;
      final itemPrice = (item.price + extraPrice) * quantitySafe;
      subtotal += itemPrice;
    }
    return subtotal;
  }

  Widget _buildItemCard(CartAttr cartData, CartProvider cartProvider) {
    String optionsText = '';
    if (cartData.selectedOptions.isNotEmpty) {
      optionsText = cartData.selectedOptions
          .map(
            (opt) =>
                '${opt['name']}${opt['price'] != null && (opt['price'] as num) > 0 ? ' (+฿${(opt['price'] as num).toStringAsFixed(0)})' : ''}',
          )
          .join(', ');
    }

    final extraPrice = cartData.extraPrice ?? 0.0;
    final itemPrice = cartData.price + extraPrice;
    final String compositeKey = cartProvider.getCompositeKey(cartData);

    return Dismissible(
      key: ValueKey(compositeKey),
      direction: DismissDirection.startToEnd,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.all(20.w),
        child: Center(
          child: Icon(Icons.delete, color: Colors.white, size: 30.r),
        ),
      ),
      onDismissed: (direction) async {
        cartProvider.removeItem(compositeKey);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${cartData.proName} removed from cart')),
        );
      },
      child: Card(
        color: Colors.grey.shade100,
        shadowColor: Colors.blueGrey.shade500,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
        margin: EdgeInsets.symmetric(vertical: 4.h),
        child: Padding(
          padding: EdgeInsets.all(8.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
                    child: SizedBox(
                      height: 60.h,
                      width: 80.w,
                      child: cartData.imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: cartData.imageUrl[0],
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                height: 60.h,
                                width: 80.w,
                                color: Colors.grey.shade200,
                              ),
                              errorWidget: (_, __, ___) => Container(
                                height: 60.h,
                                width: 80.w,
                                color: Colors.grey.shade200,
                                child: const Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : Container(
                              height: 60.h,
                              width: 80.w,
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.image_not_supported,
                                color: Colors.grey,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          cartData.proName,
                          style: styles(
                            fontSize: 14.sp,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Stock: ${cartData.proqty}',
                              style: styles(
                                fontSize: 14.sp,
                                color: Colors.grey.shade700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '฿${itemPrice.toStringAsFixed(2)}',
                              style: styles(
                                fontSize: 13.sp,
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4.h),
              if (optionsText.isNotEmpty) ...[
                Text(
                  optionsText,
                  style: styles(fontSize: 11.sp, color: Colors.black54),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ] else if (cartData.productSize.isNotEmpty) ...[
                Text(
                  'Size: ${cartData.productSize}',
                  style: styles(fontSize: 11.sp, color: Colors.grey.shade600),
                ),
              ],
              SizedBox(height: 4.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '฿${(itemPrice * cartData.quantity).toStringAsFixed(2)}',
                    style: styles(
                      fontSize: 13.sp,
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  CartStepperInt(
                    value: cartData.quantity,
                    didChangeCount: (int value) {
                      if (value == 0) {
                        cartProvider.removeItem(compositeKey);
                        return;
                      }
                      if (value > cartData.proqty) {
                        Fluttertoast.showToast(
                          msg:
                              '${cartData.proName} All inventories ${cartData.proqty} pcs.',
                          fontSize: 12.sp,
                          gravity: ToastGravity.BOTTOM,
                          timeInSecForIosWeb: 4,
                          toastLength: Toast.LENGTH_LONG,
                        );
                        return;
                      }
                      cartProvider.updateQuantity(compositeKey, value);
                    },
                    size: 36.w,
                    style: CartStepperTheme.of(context).copyWith(
                      activeForegroundColor:
                          cartData.quantity >= cartData.proqty - 10
                          ? Colors.red
                          : Colors.black87,
                      activeBackgroundColor: Colors.white,
                      textStyle: styles(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                      border: Border.all(color: Colors.grey.shade400),
                      radius: const Radius.circular(4),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
            ],
          ),
        ),
      ),
    );
  }

  Future<double?> _getDistanceToVendor(String vendorId) async {
    try {
      final vendorDoc = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(vendorId)
          .get();

      if (!vendorDoc.exists || vendorDoc['location'] == null) return null;

      final GeoPoint vendorGeo = vendorDoc['location'] as GeoPoint;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      double meters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        vendorGeo.latitude,
        vendorGeo.longitude,
      );

      return meters / 1000;
    } catch (e) {
      return null;
    }
  }

  bool _isWrongOrder = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);

      cartProvider.addListener(_onCartChanged);

      await _checkWrongOrder(cartProvider);
    });
  }

  @override
  void dispose() {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    cartProvider.removeListener(_onCartChanged);
    super.dispose();
  }

  void _onCartChanged() {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    _checkWrongOrder(cartProvider);
  }

  Future<void> _checkWrongOrder(CartProvider cartProvider) async {
    final vendorIds = cartProvider.groupedItems.keys.toList();
    if (vendorIds.length < 2) {
      if (mounted) setState(() => _isWrongOrder = false);
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );
      final docs = await Future.wait(
        vendorIds
            .take(2)
            .map(
              (id) => FirebaseFirestore.instance
                  .collection('vendors')
                  .doc(id)
                  .get(),
            ),
      );
      final g0 = docs[0]['location'] as GeoPoint?;
      final g1 = docs[1]['location'] as GeoPoint?;
      if (g0 == null || g1 == null) return;
      final d0 = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        g0.latitude,
        g0.longitude,
      );
      final d1 = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        g1.latitude,
        g1.longitude,
      );
      if (mounted) setState(() => _isWrongOrder = d0 < d1);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isParentLoading) {
      return const SizedBox.shrink();
    }

    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Cart',
          style: styles(
            fontSize: 20.sp,
            color: mainColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: Padding(
          padding: EdgeInsets.only(left: 10.w),
          child: CircleAvatar(
            radius: 16.r,
            backgroundColor: Colors.grey.shade50,
            child: IconButton(
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  widget.onBackFromCart?.call();
                }
              },
              icon: const Icon(Icons.arrow_back, color: Colors.black54),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 10.w),
            child: Consumer<CartProvider>(
              builder: (context, cartProvider, child) {
                return cartProvider.getCartItem.isEmpty
                    ? const SizedBox()
                    : CircleAvatar(
                        radius: 24.r,
                        backgroundColor: Colors.grey.shade200,
                        child: IconButton(
                          onPressed: cartProvider.getCartItem.isEmpty
                              ? null
                              : () {
                                  MyAlertDialog.showMyDialog(
                                    context: context,
                                    img: const AssetImage('images/delete.png'),
                                    title: 'Delete All',
                                    contant:
                                        'Are you sure you want to delete all items?',
                                    tabNo: () => Navigator.pop(context),
                                    tabYes: () {
                                      cartProvider.removeAllItem();
                                      Navigator.pop(context);
                                    },
                                  );
                                },
                          icon: Icon(
                            IconlyLight.delete,
                            color: Colors.yellow.shade900,
                            size: 20.w,
                          ),
                        ),
                      );
              },
            ),
          ),
        ],
      ),
      body: Consumer<CartProvider>(
        builder: (context, cartProvider, child) {
          if (cartProvider.getCartItem.isEmpty) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: SizedBox(
                height:
                    MediaQuery.of(context).size.height -
                    kToolbarHeight -
                    kBottomNavigationBarHeight,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'images/empty_cart.png',
                        width: screenWidth * 0.6,
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        'Your Cart Is Empty!',
                        style: styles(
                          color: Colors.red,
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 30.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mainColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: 32.w,
                              vertical: 12.h,
                            ),
                          ),
                          onPressed: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            } else {
                              widget.onBackFromCart?.call();
                            }
                          },
                          child: Text(
                            'เลือกสินค้าใหม่',
                            style: styles(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final Map<String, List<CartAttr>> groupedItems =
              cartProvider.groupedItems;

          return ListView.separated(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.only(bottom: 20.h),
            itemCount: groupedItems.length,
            separatorBuilder: (context, index) => const Divider(height: 16),
            itemBuilder: (context, groupIndex) {
              final vendorId = groupedItems.keys.elementAt(groupIndex);
              final List<CartAttr> groupItems = groupedItems[vendorId]!;
              if (groupItems.isEmpty) {
                return const SizedBox.shrink();
              }
              final CartAttr firstItem = groupItems.first;
              final String restaurantName = firstItem.bussinessName;
              final double groupSubtotal = _calculateGroupSubtotal(groupItems);
              print(
                '=== VENDOR $vendorId sub=${cartProvider.subTotalByVendor(vendorId)} ===',
              );

              return Card(
                margin: EdgeInsets.only(
                  left: 6.w,
                  right: 6.w,
                  bottom: 12.h,
                  top: groupIndex == 0 ? 8.h : 0,
                ),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              restaurantName.isEmpty
                                  ? 'ไม่มีชื่อร้าน'
                                  : restaurantName,
                              style: styles(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                          Text(
                            '฿${groupSubtotal.toStringAsFixed(2)}',
                            style: styles(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...groupItems.map(
                      (cartData) => _buildItemCard(cartData, cartProvider),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewPadding.bottom + 12.h,
          ),
          child: Consumer<CartProvider>(
            builder: (context, cartProvider, child) {
              if (cartProvider.getCartItem.isEmpty) {
                return const SizedBox.shrink();
              }
              String buttonText = 'รับบริการ';
              if (cartProvider.serviceType == 'dine-in') {
                buttonText = 'ออร์เดอร์';
              }

              return Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withAlpha(20),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Total:',
                            style: styles(
                              fontSize: 16.sp,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            '฿${cartProvider.subTotal.toStringAsFixed(2)}',
                            style: styles(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      height: 55.h,
                      width: screenWidth * 0.45,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mainColor,
                          shadowColor: Colors.blueGrey,
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        label: Text(
                          buttonText,
                          style: styles(color: Colors.white, fontSize: 14.sp),
                        ),
                        icon: Icon(
                          cartProvider.serviceType == 'dine-in'
                              ? Icons.table_restaurant_sharp
                              : Icons.pin_drop_outlined,
                          color: Colors.white,
                          size: 20.sp,
                        ),
                        onPressed: () {
                          if (cartProvider.serviceType == 'dine-in') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const QrPaymentPage(),
                              ),
                            );
                            return;
                          }
                          if (_isChoosingService) return;
                          _isChoosingService = true;
                          chooseService(context, screenWidth).whenComplete(() {
                            if (mounted) {
                              setState(() => _isChoosingService = false);
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<dynamic> chooseService(BuildContext context, double screenWidth) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final grouped = cartProvider.groupedItems;

    if (grouped.isEmpty) {
      Fluttertoast.showToast(msg: 'ไม่มีสินค้าในตะกร้า');
      return Future.value(null);
    }

    final bool isMultiVendor = cartProvider.isMultiVendor;

    final Future<_DistanceInfo?> distanceFuture = _getDistanceInfo(
      isMultiVendor,
      grouped.keys.toList(),
    );
    return showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            'เลือกรับบริการ',
            textAlign: TextAlign.center,
            style: styles(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade900,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: FutureBuilder<_DistanceInfo?>(
                future: distanceFuture,
                builder: (_, snapshot) {
                  final bool isLoading =
                      snapshot.connectionState == ConnectionState.waiting;
                  final _DistanceInfo? distanceInfo = snapshot.data;
                  final bool tooFar =
                      !isLoading &&
                      distanceInfo != null &&
                      distanceInfo.tooFarDistance > 10.0;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: 10.h),
                      Image.asset(
                        'images/service.png',
                        width: screenWidth * 0.5,
                        height: screenWidth * 0.35,
                      ),
                      SizedBox(height: 20.h),
                      if (isLoading) ...[
                        const SizedBox(
                          height: 40,
                          width: 40,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'กำลังตรวจสอบระยะทาง...',
                          style: styles(fontSize: 12.sp, color: Colors.grey),
                        ),
                      ] else if (tooFar)
                        Padding(
                          padding: EdgeInsets.all(16.w),
                          child: Text(
                            'ให้บริการในระยะ 10 กม.\n(${distanceInfo.tooFarDistance.toStringAsFixed(1)} กม.) ไม่มีบริการส่ง',
                            style: styles(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.sp,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mainColor,
                            minimumSize: Size(double.infinity, 60.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                          label: Text(
                            'จัดส่งถึงที่อยู่',
                            style: styles(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          icon: Icon(
                            Icons.delivery_dining_outlined,
                            color: Colors.white,
                            size: 26.r,
                          ),
                          onPressed: () async {
                            Navigator.pop(dialogContext);
                            EasyLoading.show(status: 'กำลังคำนวณค่าจัดส่ง...');
                            final cp = Provider.of<CartProvider>(
                              context,
                              listen: false,
                            );
                            final double shippingFee =
                                await cp.deliveryShipping;
                            EasyLoading.dismiss();

                            if (shippingFee > 0) {
                              final double foodTotal = cp.subTotal;

                              MyAlertDialog.showMyDialog(
                                context: context,
                                img: const AssetImage('images/product.webp'),
                                title: 'ยืนยันค่าจัดส่ง',
                                contant: shippingFee > 0
                                    ? 'ยอดสั่ง ฿${foodTotal.toStringAsFixed(0)}'
                                    : 'ค่าส่งฟรี!',

                                widget: Column(
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    if (cartProvider.isMultiVendor) ...[
                                      Text(
                                        _isWrongOrder
                                            ? '💡 เพื่อค่าส่งถูกลง ควรสั่งร้านที่อยู่ไกลจากคุณก่อน'
                                            : '',
                                        textAlign: TextAlign.center,
                                        style: styles(
                                          fontSize: 12.sp,
                                          color: Colors.amber.shade800,
                                        ),
                                      ),
                                    ],
                                    _isWrongOrder
                                        ? Divider(height: 16.h)
                                        : SizedBox(height: 10.h),
                                    Text(
                                      isMultiVendor
                                          ? 'ระยะทาง A→B + 📍: ${distanceInfo?.displayDistance.toStringAsFixed(1) ?? "?"} กม.'
                                          : 'ระยะทาง ${distanceInfo?.displayDistance.toStringAsFixed(1) ?? "?"} กม.',
                                      style: styles(
                                        fontSize: isMultiVendor ? 12.sp : 14.sp,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.blue.shade800,
                                      ),
                                    ),
                                    Text(
                                      'ค่าส่ง: ฿${shippingFee.toStringAsFixed(2)}',
                                      style: styles(
                                        fontSize: 14.sp,
                                        color: Colors.amber.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'รวมทั้งสิ้น: ฿${(foodTotal + shippingFee).toStringAsFixed(2)}',
                                      style: styles(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                    SizedBox(height: 10.h),
                                  ],
                                ),
                                tabNo: () => Navigator.pop(context),
                                tabYes: () {
                                  cp.setServiceType('delivery');
                                  cp.deliveryShipping.then(
                                    (value) => Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const CheckOutPage(),
                                      ),
                                    ),
                                  );
                                },
                              );
                            } else {
                              cp.setServiceType('delivery');
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CheckOutPage(),
                                ),
                              );
                            }
                          },
                        ),
                      SizedBox(height: 20.h),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(
                            255,
                            17,
                            77,
                            197,
                          ),
                          minimumSize: Size(double.infinity, 60.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        label: Text(
                          'รับที่ร้าน',
                          style: styles(
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        icon: const Icon(
                          Icons.home_filled,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: () {
                          Provider.of<CartProvider>(
                            context,
                            listen: false,
                          ).setServiceType('pickup');
                          Navigator.pop(dialogContext);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const QrPaymentPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ยกเลิก'),
            ),
          ],
        );
      },
    );
  }

  Future<double?> _getFarthestVendorDistance(List<String> vendorIds) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      double maxDistance = 0.0;

      for (final vendorId in vendorIds) {
        final vendorDoc = await FirebaseFirestore.instance
            .collection('vendors')
            .doc(vendorId)
            .get();

        if (!vendorDoc.exists || vendorDoc['location'] == null) continue;

        final GeoPoint geo = vendorDoc['location'] as GeoPoint;
        final double dist =
            Geolocator.distanceBetween(
              position.latitude,
              position.longitude,
              geo.latitude,
              geo.longitude,
            ) /
            1000;

        if (dist > maxDistance) maxDistance = dist;
      }

      return maxDistance;
    } catch (e) {
      return null;
    }
  }

  Future<_DistanceInfo?> _getDistanceInfo(
    bool isMultiVendor,
    List<String> vendorIds,
  ) async {
    if (isMultiVendor) {
      final farthest = await _getFarthestVendorDistance(vendorIds);
      final total = await _getTotalDistanceMultiVendor(vendorIds);
      if (farthest == null || total == null) return null;
      return _DistanceInfo(farthest, total);
    } else {
      final dist = await _getDistanceToVendor(vendorIds.first);
      if (dist == null) return null;
      return _DistanceInfo(dist, dist);
    }
  }

  Future<double?> _getTotalDistanceMultiVendor(List<String> vendorIds) async {
    if (vendorIds.length < 2) return _getDistanceToVendor(vendorIds.first);
    try {
      final docs = await Future.wait(
        vendorIds.map(
          (id) =>
              FirebaseFirestore.instance.collection('vendors').doc(id).get(),
        ),
      );

      final List<GeoPoint?> locations = docs.map((doc) {
        if (!doc.exists || doc['location'] == null) return null;
        return doc['location'] as GeoPoint;
      }).toList();

      double totalInterVendorDistance = 0.0;
      for (int i = 0; i < locations.length - 1; i++) {
        final a = locations[i];
        final b = locations[i + 1];
        if (a != null && b != null) {
          totalInterVendorDistance +=
              Geolocator.distanceBetween(
                a.latitude,
                a.longitude,
                b.latitude,
                b.longitude,
              ) /
              1000;
        }
      }
      final lastGeo = locations.lastWhere((g) => g != null, orElse: () => null);
      if (lastGeo == null) return null;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      final distanceToCustomer =
          Geolocator.distanceBetween(
            lastGeo.latitude,
            lastGeo.longitude,
            position.latitude,
            position.longitude,
          ) /
          1000;

      return totalInterVendorDistance + distanceToCustomer;
    } catch (e) {
      return null;
    }
  }
}
