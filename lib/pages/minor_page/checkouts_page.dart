// ignore_for_file: no_leading_underscores_for_local_identifiers, avoid_print, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:colae_cut/models/cart_attributes.dart';
import 'package:colae_cut/pages/minor_page/qr_payment.dart';
import 'package:colae_cut/services/sevice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:colae_cut/providers/cart_provider.dart';
import 'package:colae_cut/pages/minor_page/add_address.dart';

class CheckOutPage extends StatefulWidget {
  const CheckOutPage({super.key});

  @override
  State<CheckOutPage> createState() => _CheckOutPageState();
}

class _CheckoutData {
  final Map<String, double> prices;
  final Map<String, double> shipping;
  const _CheckoutData({required this.prices, required this.shipping});
}

class _CheckOutPageState extends State<CheckOutPage> {
  late String fullName;
  late String phone;
  late String address;
  late final Stream<DocumentSnapshot> _userStream;

  Future<_CheckoutData>? _priceFuture;
  String _lastCartKey = '';

  Future<_CheckoutData> _getCachedPrices(
    CartProvider cartProvider,
    Map<String, List<CartAttr>> groupedItems,
  ) {
    final cartKey =
        '${cartProvider.serviceType}_${groupedItems.keys.join(",")}_'
        '${cartProvider.getCartItem.values.map((e) => "${e.proId}:${e.quantity}").join(",")}';
    if (_priceFuture == null || cartKey != _lastCartKey) {
      _lastCartKey = cartKey;
      _priceFuture = Future(() async {
        final prices = <String, double>{};
        final shipping = <String, double>{};
        for (final vendorId in groupedItems.keys) {
          if (cartProvider.serviceType == 'delivery') {
            final ship = await cartProvider.customerShippingByVendor(vendorId);
            shipping[vendorId] = ship;
            prices[vendorId] = cartProvider.subTotalByVendor(vendorId) + ship;
          } else {
            shipping[vendorId] = 0.0;
            prices[vendorId] = cartProvider.subTotalByVendor(vendorId);
          }
        }
        return _CheckoutData(prices: prices, shipping: shipping);
      });
    }
    return _priceFuture!;
  }

  @override
  void initState() {
    super.initState();
    _userStream = firestore
        .collection('buyers')
        .doc(auth.currentUser!.uid)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final CartProvider _cartProvider = Provider.of<CartProvider>(context);

    return StreamBuilder<DocumentSnapshot>(
      stream: _userStream,
      builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("Something went wrong"));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.purple),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text("Document does not exist"));
        }

        Map data = snapshot.data!.data() as Map;
        final Map userDataMap = data;
        bool hasAddress =
            data.containsKey('address') &&
            data['address'] != null &&
            data['address'].toString().isNotEmpty;
        fullName = data['fullName'] ?? '';
        phone = data['phone'] ?? '';
        address = data['address'] ?? '';

        print('hasAddress: $hasAddress address: ${data['address']}');

        final groupedItems = _cartProvider.groupedItems;
        final bool isMultiVendor = _cartProvider.isMultiVendor;

        if (groupedItems.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                'รายการคำสั่งซื้อ­',
                style: styles(
                  fontSize: 20.sp,
                  color: mainColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              centerTitle: true,
              backgroundColor: Colors.transparent,
            ),
            body: const Center(child: Text('ไม่มีสินค้าในตะกร้า')),
          );
        }

        return FutureBuilder<_CheckoutData>(
          future: _getCachedPrices(_cartProvider, groupedItems),
          builder: (context, priceSnapshot) {
            if (priceSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.purple),
              );
            }

            if (priceSnapshot.hasError || !priceSnapshot.hasData) {
              return const Center(child: Text('ไม่สามารถคำนวณราคาได้'));
            }

            final data = priceSnapshot.data!;
            final Map<String, double> prices = data.prices;
            final double globalTotal = prices.values.fold(
              0.0,
              (acc, price) => acc + price,
            );

            Widget itemsListWidget;

            if (isMultiVendor) {
              itemsListWidget = ListView.builder(
                itemCount: groupedItems.length,
                itemBuilder: (context, index) {
                  final vendorId = groupedItems.keys.elementAt(index);
                  final vendorItems = groupedItems[vendorId]!;
                  final double vendorTotal = prices[vendorId] ?? 0.0;
                  final double shippingCost = data.shipping[vendorId] ?? 0.0;
                  final storeName = vendorItems.first.bussinessName;

                  return Card(
                    margin: EdgeInsets.all(8.r),
                    child: ExpansionTile(
                      title: Text(
                        storeName,
                        style: styles(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: mainColor,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'รวม: ฿${vendorTotal.toStringAsFixed(2)} | ชิ้น: ${vendorItems.fold(0, (acc, item) => acc + item.quantity)}',
                          ),
                          if (_cartProvider.serviceType == 'delivery') ...[
                            Text(
                              shippingCost > 0
                                  ? 'ค่าส่ง: ฿${shippingCost.toStringAsFixed(2)}'
                                  : 'ค่าส่งฟรี! 🎉',
                              style: styles(
                                fontSize: 14.sp,
                                color: shippingCost > 0
                                    ? Colors.deepOrange
                                    : Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 8.h,
                          ),
                          child: Column(
                            children: [
                              Text(
                                'รายการสินค้า',
                                style: styles(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: vendorItems.length,
                                separatorBuilder: (context, idx) => Divider(
                                  thickness: 1.0,
                                  color: Colors.grey[300],
                                ),
                                itemBuilder: (context, itemIndex) {
                                  final item = vendorItems[itemIndex];
                                  return ListTile(
                                    title: Text(
                                      item.proName,
                                      style: styles(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                    subtitle: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${item.price.toStringAsFixed(1)} x ${item.quantity}',
                                            style: styles(
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ),
                                        Spacer(),
                                        Text(
                                          '฿${((item.price + (item.extraPrice ?? 0.0)) * item.quantity).toStringAsFixed(1)}',
                                          style: styles(
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              Divider(),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    top: 12.h,
                                    bottom: 12.h,
                                  ),
                                  child: Text(
                                    'รวมร้านนี้: ฿${vendorTotal.toStringAsFixed(2)}',
                                    style: styles(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            } else {
              if (groupedItems.isNotEmpty) {
                final vendorId = groupedItems.keys.first;
                final vendorItems = groupedItems[vendorId]!;
                final double shippingCost = data.shipping[vendorId] ?? 0.0;
                final storeName = vendorItems.first.bussinessName;
                final totalItems = vendorItems.fold(
                  0,
                  (acc, item) => acc + item.quantity,
                );

                itemsListWidget = ListView(
                  children: [
                    Card(
                      color: Colors.grey.shade100,
                      shadowColor: Colors.blueGrey,
                      elevation: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.all(12.r),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  storeName,
                                  style: styles(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Text(
                                  'Items: $totalItems',
                                  style: styles(
                                    fontSize: 16.sp,
                                    color: Colors.black,
                                  ),
                                ),
                                if (_cartProvider.serviceType ==
                                    'delivery') ...[
                                  Text(
                                    shippingCost > 0
                                        ? 'ค่าส่ง: ฿${shippingCost.toStringAsFixed(2)}'
                                        : 'ค่าส่งฟรี! 🎉',
                                    style: styles(
                                      fontSize: 14.sp,
                                      color: shippingCost > 0
                                          ? Colors.blue
                                          : Colors.green,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: vendorItems.length,
                            itemBuilder: (context, index) {
                              final cartData = vendorItems[index];
                              return Padding(
                                padding: EdgeInsets.only(bottom: 12.h),
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                          left: 12.w,
                                          right: 8.w,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              cartData.proName,
                                              style: styles(
                                                fontSize: 14.sp,
                                                color: Colors.black87,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            SizedBox(height: 4.h),
                                            Row(
                                              children: [
                                                Text(
                                                  '${cartData.price.toStringAsFixed(1)} x ${cartData.quantity}',
                                                  style: styles(
                                                    color: Colors.red,
                                                    fontSize: 12.sp,
                                                  ),
                                                ),
                                                Spacer(),
                                                Text(
                                                  '${(cartData.price + (cartData.extraPrice ?? 0.0)) * cartData.quantity}',
                                                  style: styles(
                                                    color: Colors.red,
                                                    fontSize: 12.sp,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 4.h),
                                            if (cartData
                                                .selectedOptions
                                                .isNotEmpty)
                                              Text(
                                                cartData.selectedOptions
                                                    .map((opt) => opt['name'])
                                                    .join(', '),
                                                style: styles(
                                                  fontSize: 12.sp,
                                                  color: Colors.black45,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          SizedBox(height: 20.h),
                        ],
                      ),
                    ),
                  ],
                );
              } else {
                itemsListWidget = const Center(
                  child: Text('ไม่มีสินค้าในตะกร้า'),
                );
              }
            }

            return Scaffold(
              appBar: AppBar(
                title: Text(
                  'รายการคำสั่งซื้อ',
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
                  padding: const EdgeInsets.only(left: 8.0),
                  child: CircleAvatar(
                    backgroundColor: Colors.grey.shade200,
                    radius: 18.r,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.black54),
                    ),
                  ),
                ),
              ),
              body: itemsListWidget,
              bottomNavigationBar: SafeArea(
                child: ColoredBox(
                  color: Colors.white,
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewPadding.bottom + 12.h,
                      left: 10.w,
                      right: 10.w,
                      top: 8.h,
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Total: ฿${globalTotal.toStringAsFixed(2)}',
                          style: styles(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: Colors.red,
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: width / 2,
                          height: 50.h,
                          child: hasAddress
                              ? ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        _cartProvider.serviceType == 'delivery'
                                        ? mainColor
                                        : const Color.fromARGB(
                                            255,
                                            17,
                                            77,
                                            197,
                                          ),
                                    shadowColor: Colors.blueGrey,
                                    elevation: 5,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                  ),
                                  label: Text(
                                    'ชำระเงิน',
                                    style: styles(
                                      color: Colors.white,
                                      fontSize: 14.sp,
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const QrPaymentPage(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.payment,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                )
                              : SizedBox(
                                  width: width / 2,
                                  height: 50.h,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      shadowColor: Colors.blueGrey,
                                      elevation: 5,
                                      backgroundColor: Colors.cyan.shade500,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                    ),
                                    label: Text(
                                      'เพิ่มที่อยู่',
                                      style: styles(
                                        fontSize: 16.sp,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),

                                    onPressed: () {
                                      Navigator.push<bool>(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              Address(userData: userDataMap),
                                        ),
                                      ).then((result) {
                                        if (result == true && mounted) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const QrPaymentPage(),
                                            ),
                                          );
                                        }
                                      });
                                    },
                                    icon: const Icon(
                                      Icons.pin_drop_outlined,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
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
