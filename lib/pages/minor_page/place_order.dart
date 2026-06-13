// ignore_for_file: no_leading_underscores_for_local_identifiers, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:colae_cut/services/sevice.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:colae_cut/providers/cart_provider.dart';
import 'package:get/get.dart';

class PlaceOrderPage extends StatefulWidget {
  const PlaceOrderPage({super.key});

  @override
  State<PlaceOrderPage> createState() => _PlaceOrderPageState();
}

class _PlaceOrderPageState extends State<PlaceOrderPage> {
  late final Future<DocumentSnapshot> _userFuture;
  bool _isPlacing = false;

  @override
  void initState() {
    super.initState();
    _userFuture = firestore
        .collection('buyers')
        .doc(auth.currentUser!.uid)
        .get();
  }

  Future<void> _placeOrder(
    Map<String, dynamic> userData,
    CartProvider cartProvider,
  ) async {
    if (_isPlacing) return;
    setState(() => _isPlacing = true);

    try {
      final batch = firestore.batch();
      final now = Timestamp.now();

      for (final entry in cartProvider.getCartItem.entries) {
        final item = entry.value;
        final orderId = generateOrderId(FirebaseAuth.instance.currentUser!.uid);
        final orderRef = firestore.collection('orders').doc(orderId);

        final vendorDoc = await FirebaseFirestore.instance
            .collection('vendors')
            .doc(item.vendorId)
            .get();
        final vd = vendorDoc.exists
            ? vendorDoc.data() as Map<String, dynamic>
            : <String, dynamic>{};

        batch.set(orderRef, {
          'orderId': orderId,
          'vendorId': item.vendorId,
          'bussName': item.bussinessName,
          'bussinessName': item.bussinessName,
          'vendorInfo': {
            'bussinessName': item.bussinessName,
            'vaddress': vd['address'] ?? '',
            'vsubdistrict': vd['subdistrict'] ?? '',
            'vdistrict': vd['district'] ?? '',
            'vprovince': vd['province'] ?? vd['city'] ?? '',
            'vzipcode': vd['vzipcode'] ?? '',
            'vendorPhone': vd['phone'] ?? '',
            'vendorEmail': vd['email'] ?? '',
            'storeImage': vd['image'] ?? '',
            'vendorLocation': vd['location'] ?? const GeoPoint(0, 0),
          },
          'buyerInfo': {
            'fullName': userData['fullName'] ?? '',
            'custphone': userData['custphone'] ?? '',
            'custemail': userData['custemail'] ?? '',
            'address': userData['address'] ?? '',
            'buyerImage': userData['profileImage'] ?? '',
          },
          'buyerId': userData['buyerId'],
          'proName': item.proName,
          'price': item.price,
          'charge': item.shippingCharge,
          'proId': item.proId,
          'productImage': item.imageUrl,
          'qty': item.quantity,
          'pqty': item.proqty,
          'productSize': item.productSize,
          'date': item.scheduleDate,
          'oderDate': now,
          'timestamp': now,
          'status': 'pending',
          'accepted': false,
          'askme': false,
          'items': [
            {
              'proId': item.proId,
              'proName': item.proName,
              'price': item.price,
              'quantity': item.quantity,
              'productSize': item.productSize,
              'imageUrl': item.imageUrl,
              'vendorId': item.vendorId,
              'bussinessName': item.bussinessName,
              'shippingCharge': item.shippingCharge,
            },
          ],
        });
      }

      try {
        await FirebaseFirestore.instance.enableNetwork();
      } catch (_) {}
      await batch.commit();

      final stockFutures = cartProvider.getCartItem.values.map((item) {
        return firestore.runTransaction((transaction) async {
          final ref = firestore.collection('products').doc(item.proId);
          final snap = await transaction.get(ref);
          if (snap.exists) {
            final productData = snap.data();
            final bool trackStock = productData?['trackStock'] as bool? ?? true;
            if (trackStock) {
              transaction.update(ref, {
                'pqty': (snap['pqty'] as num) - item.quantity,
              });
            }
          }
        });
      }).toList();
      await Future.wait(stockFutures);

      cartProvider.removeAllItem();

      Get.until((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
        setState(() => _isPlacing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final CartProvider _cartProvider = Provider.of<CartProvider>(context);

    return FutureBuilder<DocumentSnapshot>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text("Something went wrong")),
          );
        }
        if (snapshot.hasData && !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: Text("Document does not exist")),
          );
        }
        if (snapshot.connectionState == ConnectionState.done) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          return Scaffold(
            body: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Center(
                  child: Image.asset(
                    'images/delivery.webp',
                    width: MediaQuery.of(context).size.width * 0.8,
                    alignment: Alignment.center,
                  ),
                ),
                Container(
                  padding: EdgeInsets.only(top: 20.w),
                  width: width * 0.7,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      shadowColor: Colors.blueGrey,
                      elevation: 5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 10.w),
                    ),
                    onPressed: _isPlacing
                        ? null
                        : () => _placeOrder(data, _cartProvider),
                    icon: _isPlacing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.check_box_outlined,
                            color: Colors.white,
                          ),
                    label: Text(
                      _isPlacing ? 'กำลังส่งคำสั่งซื้อ...' : 'ยืนยันคำสั่งซื้อ',
                      style: styles(fontSize: 14.sp, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return const Center(
          child: CircularProgressIndicator(color: Colors.teal),
        );
      },
    );
  }
}
