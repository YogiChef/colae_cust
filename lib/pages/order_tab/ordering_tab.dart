// ignore_for_file: avoid_print, use_build_context_synchronously, empty_catches

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:colae_cut/pages/minor_page/chat_page.dart';
import 'package:colae_cut/pages/minor_page/customer_rider_chat_page.dart';
import 'package:colae_cut/services/sevice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

class Ordering extends StatefulWidget {
  const Ordering({super.key});

  @override
  State<Ordering> createState() => _OrderingState();
}

class _OrderingState extends State<Ordering> {
  late final Stream<QuerySnapshot> _ordersStream;
  final Map<String, bool> _localCancelOverrides = {};

  final Map<String, bool> _localItemCancelOverrides = {};

  final Map<String, Stream<QuerySnapshot>> _chatStreamCache = {};

  Stream<QuerySnapshot>? _getChatStream(String vendorId, String orderId) {
    if (vendorId.isEmpty || orderId.isEmpty) return null;
    final key = '\${vendorId}_\$orderId';
    return _chatStreamCache.putIfAbsent(
      key,
      () => firestore
          .collection('chats')
          .where('buyerId', isEqualTo: auth.currentUser!.uid)
          .where('vendorId', isEqualTo: vendorId)
          .where('orderId', isEqualTo: orderId)
          .where('senderId', isEqualTo: vendorId)
          .where('read', isEqualTo: false)
          .snapshots(),
    );
  }

  @override
  void initState() {
    super.initState();
    if (auth.currentUser != null) {
      _ordersStream = firestore
          .collection('orders')
          .where('buyerId', isEqualTo: auth.currentUser!.uid)
          .where(
            'status',
            whereIn: [
              'pending',
              'paid',
              'preparing',
              'pending_rider',
              'self_delivering',
              'rider_accepted',
              'picked_up',
              'shipped',
            ],
          )
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots();
    }
  }

  @override
  void dispose() {
    _chatStreamCache.clear();
    super.dispose();
  }

  List<Map<String, dynamic>> _processItems(dynamic itemsRaw) {
    if (itemsRaw == null) return [];
    List<Map<String, dynamic>> items = [];
    if (itemsRaw is List<dynamic>) {
      items = itemsRaw
          .map((item) {
            if (item is! Map<String, dynamic>) {
              return {
                'proName': item.toString(),
                'quantity': 1,
                'price': 0.0,
                'imageUrl': [],
              };
            }
            return item;
          })
          .where((item) => item.isNotEmpty)
          .toList();
    } else if (itemsRaw is Map) {
      final List<dynamic> rawKeys = itemsRaw.keys
          .where((k) => int.tryParse(k.toString()) != null)
          .toList();
      final List<String> keys = rawKeys.map((k) => k.toString()).toList();
      keys.sort((a, b) => int.parse(a).compareTo(int.parse(b)));
      for (String key in keys) {
        final dynamic subItem = itemsRaw[key];
        if (subItem is Map<String, dynamic> && subItem.isNotEmpty) {
          items.add(subItem);
        } else {
          items.add({
            'proName': subItem.toString(),
            'quantity': 1,
            'price': 0.0,
            'imageUrl': [],
          });
        }
      }
    } else {
      items = [
        {
          'proName': itemsRaw.toString(),
          'quantity': 1,
          'price': 0.0,
          'imageUrl': [],
        },
      ];
    }
    return items;
  }

  TextStyle _getItemTextStyle({
    required bool isCancelled,
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    TextDecoration? decoration,
  }) {
    final baseStyle = styles(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? (isCancelled ? Colors.grey : Colors.black87),
    );
    if (isCancelled) {
      return baseStyle.copyWith(decoration: TextDecoration.lineThrough);
    }
    return baseStyle;
  }

  Widget _buildItemBase({
    required Map<String, dynamic> item,
    required int itemIndex,
    required BuildContext context,
    required String documentId,
    required bool cancelRequested,
  }) {
    final bool isCancelled = item['cancelled'] ?? false;
    final String proName = item['proName'] ?? '';
    final int quantity = item['quantity'] ?? 1;
    final double price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final double? optionPrice = (item['extraPrice'] as num?)?.toDouble();
    final double extraPrice =
        ((item['extraPrice'] as num?)?.toDouble() ?? 00) * quantity;
    final String productSize = item['productSize'] ?? '';
    final List<dynamic> selectedOptionsRaw = item['selectedOptions'] ?? [];
    final List<Map<String, dynamic>> selectedOptions = selectedOptionsRaw
        .map((opt) => opt as Map<String, dynamic>)
        .toList();
    final String optionsText = selectedOptions
        .map(
          (opt) =>
              '${opt['name']} (+฿${(opt['price'] as num?)?.toDouble() ?? 0})',
        )
        .join(', ');
    final double itemSubtotal = price * quantity;
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            proName,
            style: _getItemTextStyle(
              isCancelled: isCancelled,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (productSize.isNotEmpty) ...[
            SizedBox(height: 2.h),
            Text(
              'Size: $productSize',
              style: _getItemTextStyle(
                isCancelled: isCancelled,
                fontSize: 12.sp,
                decoration: TextDecoration.none,
                color: Colors.grey,
              ),
            ),
          ],
          if (optionsText.isNotEmpty) ...[
            SizedBox(height: 2.h),
            Text(
              optionsText,
              style: _getItemTextStyle(
                isCancelled: isCancelled,
                fontSize: 11.sp,
                decoration: TextDecoration.none,
                color: Colors.grey,
              ),
            ),
          ],
          SizedBox(height: 4.h),
          Row(
            children: [
              Text(
                '฿${price.toStringAsFixed(2)} x $quantity',
                style: _getItemTextStyle(
                  isCancelled: isCancelled,
                  fontSize: 12.sp,
                  decoration: TextDecoration.none,
                  color: Colors.grey,
                ),
              ),
              Spacer(),
              Text(
                '= ฿${itemSubtotal.toStringAsFixed(2)}',
                style: _getItemTextStyle(
                  isCancelled: isCancelled,
                  fontSize: 13.sp,
                  color: Colors.deepOrange,
                  decoration: isCancelled ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
          if (extraPrice > 0) ...[
            Row(
              children: [
                Text(
                  'Extra: +฿$optionPrice x $quantity',
                  style: _getItemTextStyle(
                    isCancelled: isCancelled,
                    fontSize: 12.sp,
                    decoration: TextDecoration.none,
                    color: Colors.grey,
                  ),
                ),
                Spacer(),
                Text(
                  '= ฿${extraPrice.toStringAsFixed(2)}',
                  style: _getItemTextStyle(
                    isCancelled: isCancelled,
                    fontSize: 12.sp,
                    decoration: TextDecoration.none,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ],
          cancelRequested
              ? Text(
                  'รอการตอบกลับ',
                  style: styles(
                    fontSize: 13.sp,
                    color: Colors.red,
                    fontWeight: FontWeight.w400,
                  ),
                )
              : SizedBox.shrink(),
        ],
      ),
    );
  }

  Future<void> _toggleItemCancelRequest({
    required String documentId,
    required int itemIndex,
    required bool currentRequested,
    required List<Map<String, dynamic>> currentItems,
    required BuildContext context,
  }) async {
    final bool newValue = !currentRequested;
    final String overrideKey = '${documentId}_$itemIndex';

    if (mounted) {
      setState(() {
        _localItemCancelOverrides[overrideKey] = newValue;
      });
    }

    try {
      final List<Map<String, dynamic>> items = currentItems
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      if (itemIndex < 0 || itemIndex >= items.length) {
        throw Exception('Invalid item index: \$itemIndex');
      }
      items[itemIndex]['cancelRequested'] = newValue;

      await firestore.collection('orders').doc(documentId).update({
        'items': items,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(currentRequested ? 'ถอนคำขอแล้ว' : 'ขอคืนรายการแล้ว'),
            backgroundColor: currentRequested ? Colors.green : Colors.orange,
          ),
        );
      }
      if (mounted) {
        setState(() {
          _localItemCancelOverrides.remove(overrideKey);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _localItemCancelOverrides[overrideKey] = currentRequested;
        });
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: \$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildItemWidget({
    required Map<String, dynamic> item,
    required int itemIndex,
    required BuildContext context,
    required String documentId,
    required List<Map<String, dynamic>> currentItems,
  }) {
    final bool isCancelled = item['cancelled'] ?? false;
    final String overrideKey = '${documentId}_$itemIndex';
    final bool cancelRequested =
        _localItemCancelOverrides.containsKey(overrideKey)
        ? _localItemCancelOverrides[overrideKey]!
        : (item['cancelRequested'] ?? false);

    Widget itemWidget = _buildItemBase(
      item: item,
      itemIndex: itemIndex,
      context: context,
      documentId: documentId,
      cancelRequested: cancelRequested,
    );
    if (!isCancelled) {
      itemWidget = Slidable(
        key: ValueKey('${documentId}_item_$itemIndex'),
        startActionPane: ActionPane(
          motion: const ScrollMotion(),
          children: [
            SlidableAction(
              flex: 3,
              onPressed: (context) async {
                await _toggleItemCancelRequest(
                  documentId: documentId,
                  itemIndex: itemIndex,
                  currentRequested: cancelRequested,
                  currentItems: currentItems,
                  context: context,
                );
              },
              backgroundColor: cancelRequested
                  ? Colors.green
                  : const Color(0xFFFE4A49),
              foregroundColor: Colors.grey.shade100,
              icon: cancelRequested ? Icons.undo : Icons.cancel,
              label: cancelRequested ? 'ยกเลิกคำขอ' : 'ขอยกเลิกทั้งหมด',
            ),
          ],
        ),
        child: itemWidget,
      );
    }
    return itemWidget;
  }

  Future<void> _markChatsAsRead({
    required String vendorId,
    required String proId,
  }) async {
    try {
      final batch = firestore.batch();
      final unreadSnapshot = await firestore
          .collection('chats')
          .where('buyerId', isEqualTo: auth.currentUser!.uid)
          .where('vendorId', isEqualTo: vendorId)
          .where('proId', isEqualTo: proId)
          .where('senderId', isEqualTo: vendorId)
          .where('read', isEqualTo: false)
          .get();

      for (var doc in unreadSnapshot.docs) {
        batch.update(doc.reference, {'read': true});
      }
      try {
        await FirebaseFirestore.instance.enableNetwork();
      } catch (_) {}
      await batch.commit();
    } catch (e) {}
  }

  Widget _buildVendorDetails({
    required String vendorName,
    required String vendorAddress,
    required String vendorSubdistrict,
    required String vendorDistrict,
    required String vendorProvince,
    required String vendorZipcode,
    required String vendorPhone,
    required String vendorEmail,
    required String storeImage,
    required String vendorId,
    required List<Map<String, dynamic>> items,
    required BuildContext context,
    required String orderId,
    required String riderId,
    required String riderName,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border(top: BorderSide(color: Colors.orange.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ข้อมูลร้านค้า',
            style: styles(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () async {
                  if (items.isNotEmpty && vendorId.isNotEmpty) {
                    final firstItem = items.first;
                    final proId = firstItem['proId']?.toString() ?? '';
                    final proName = firstItem['proName'] ?? '';
                    if (proId.isNotEmpty) {
                      await _markChatsAsRead(vendorId: vendorId, proId: proId);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatPage(
                            vendorId: vendorId,
                            buyerId: auth.currentUser!.uid,
                            proId: proId,
                            proName: proName,
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('ไม่พบข้อมูลสินค้าเพื่อเริ่มแชท'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: CircleAvatar(
                  radius: 20.r,
                  backgroundImage: storeImage.isNotEmpty
                      ? NetworkImage(storeImage)
                      : null,
                  child: storeImage.isEmpty
                      ? Icon(Icons.store, size: 20.r)
                      : null,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vendorName,
                      style: styles(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    if (vendorAddress.isNotEmpty)
                      Row(
                        children: [
                          Text(
                            '$vendorAddress, ต.$vendorSubdistrict,',
                            style: styles(
                              fontSize: 12.sp,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    Row(
                      children: [
                        Text(
                          'อ.$vendorDistrict, จ.$vendorProvince $vendorZipcode',
                          style: styles(fontSize: 12.sp, color: Colors.black54),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.phone, color: Colors.green, size: 16.sp),
                        SizedBox(width: 4.w),
                        Text(
                          vendorPhone,
                          style: styles(fontSize: 12.sp, color: Colors.black54),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.email, color: mainColor, size: 16.sp),
                        SizedBox(width: 4.w),
                        Text(
                          vendorEmail,
                          overflow: TextOverflow.ellipsis,
                          style: styles(fontSize: 12.sp, color: Colors.black54),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (riderId.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Divider(height: 1, color: Colors.grey.shade300),
            SizedBox(height: 8.h),
            Text(
              'ไรเดอร์',
              style: styles(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            SizedBox(height: 8.h),
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('riders')
                  .doc(riderId)
                  .get(),
              builder: (context, snapshot) {
                String riderPhoto = '';
                String displayName = riderName.isNotEmpty
                    ? riderName
                    : 'ไรเดอร์';
                if (snapshot.hasData && snapshot.data!.exists) {
                  final riderData =
                      snapshot.data!.data() as Map<String, dynamic>;
                  riderPhoto =
                      riderData['facePhotoUrl'] as String? ??
                      riderData['image'] as String? ??
                      '';
                  final fetchedName =
                      riderData['fullName'] as String? ??
                      riderData['name'] as String? ??
                      '';
                  if (fetchedName.isNotEmpty) displayName = fetchedName;
                }
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CustomerRiderChatPage(
                          orderId: orderId,
                          riderId: riderId,
                          riderName: displayName,
                        ),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20.r,
                        backgroundColor: Colors.green.shade100,
                        backgroundImage: riderPhoto.isNotEmpty
                            ? NetworkImage(riderPhoto)
                            : null,
                        child: riderPhoto.isEmpty
                            ? Icon(
                                Icons.delivery_dining,
                                color: Colors.green,
                                size: 22.r,
                              )
                            : null,
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          displayName,
                          style: styles(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chat_bubble_outline,
                        color: Colors.green,
                        size: 20.sp,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _toggleOrderCancelRequest({
    required String documentId,
    required bool currentRequested,
    required BuildContext context,
  }) async {
    final bool newValue = !currentRequested;

    if (mounted) {
      setState(() {
        _localCancelOverrides[documentId] = newValue;
      });
    }

    try {
      await firestore.collection('orders').doc(documentId).update({
        'orderCancelRequested': newValue,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentRequested
                  ? 'ถอนคำขอแล้ว'
                  : 'ขอยกเลิกคำสั่งซื้อทั้งหมดแล้ว',
            ),
            backgroundColor: currentRequested ? Colors.green : Colors.orange,
          ),
        );
      }
      if (mounted) {
        setState(() {
          _localCancelOverrides.remove(documentId);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _localCancelOverrides[documentId] = currentRequested;
        });
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmReceived(String orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันได้รับของ'),
        content: const Text(
          'ยืนยันว่าได้รับของและตรวจสอบสินค้าเรียบร้อยแล้ว?\nหลังยืนยันจะไม่สามารถแก้ไขได้',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ยืนยัน', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    EasyLoading.show(status: 'กำลังบันทึก...');
    try {
      await firestore.collection('orders').doc(orderId).update({
        'status': 'delivered',
        'confirmedByBuyer': true,
        'deliveredAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      EasyLoading.showSuccess('ยืนยันแล้ว ขอบคุณค่ะ');
    } catch (e) {
      EasyLoading.showError('เกิดข้อผิดพลาด: $e');
    }
  }

  Widget _buildUnreadBadge(int unreadCount) {
    if (unreadCount == 0) return const SizedBox.shrink();
    return Positioned(
      right: 0,
      top: 0,
      child: Container(
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
        child: Text(
          '$unreadCount',
          style: styles(
            fontSize: 10.sp,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard({
    required DocumentSnapshot document,
    required BuildContext context,
  }) {
    final Map<String, dynamic> orderData =
        document.data() as Map<String, dynamic>;

    final List<Map<String, dynamic>> items = _processItems(orderData['items']);

    final Timestamp timestamp = orderData['timestamp'] ?? Timestamp.now();
    final String serviceType = orderData['serviceType'] ?? 'pickup';
    final String orderType = orderData['orderType'] as String? ?? serviceType;
    final String vendorId =
        orderData['vendorId']?.toString() ??
        (items.isNotEmpty ? items.first['vendorId']?.toString() ?? '' : '');
    final String riderId = orderData['riderId']?.toString() ?? '';
    final String riderName = orderData['riderName']?.toString() ?? '';
    final Map<String, dynamic> vi =
        (orderData['vendorInfo'] as Map<String, dynamic>?) ?? {};
    final String vendorNameFromOrder =
        vi['bussinessName'] as String? ??
        orderData['bussinessName'] as String? ??
        '';
    final String vendorName = vendorNameFromOrder.isNotEmpty
        ? vendorNameFromOrder
        : (items.isNotEmpty
              ? items.first['bussinessName'] ?? 'ผู้ขายไม่ทราบ'
              : 'ผู้ขายไม่ทราบ');
    final String status = orderData['status'] ?? 'pending';
    String statusText = '';
    Color statusColor = Colors.grey;

    switch (status) {
      case 'pending':
        statusText = 'ยังไม่จ่าย';
        statusColor = Colors.orange;
        break;
      case 'paid':
        statusText = 'ชำระแล้ว';
        statusColor = Colors.green;
        break;
      case 'preparing':
        statusText = 'กำลังเตรียม';
        statusColor = Colors.blue;
        break;
      case 'pending_rider':
        statusText = 'รอ Rider';
        statusColor = Colors.amber;
        break;
      case 'self_delivering':
        statusText = 'ร้านส่งเอง';
        statusColor = Colors.teal;
        break;
      case 'rider_accepted':
        statusText = 'Rider รับงาน';
        statusColor = Colors.green;
        break;
      case 'picked_up':
        statusText = 'Rider รับอาหารแล้ว';
        statusColor = Colors.green.shade700;
        break;
      case 'shipped':
        statusText = 'จัดส่งแล้ว';
        statusColor = Colors.blue;
        break;
      default:
        statusText = '';
        statusColor = Colors.transparent;
        break;
    }
    final String vendorAddress =
        vi['vaddress'] as String? ?? orderData['vaddress'] as String? ?? '';
    final String vendorSubdistrict =
        vi['vsubdistrict'] as String? ??
        orderData['vsubdistrict'] as String? ??
        '';
    final String vendorDistrict =
        vi['vdistrict'] as String? ?? orderData['vdistrict'] as String? ?? '';
    final String vendorProvince =
        vi['vprovince'] as String? ?? orderData['vprovince'] as String? ?? '';
    final String vendorZipcode =
        vi['vzipcode'] as String? ?? orderData['vzipcode'] as String? ?? '';
    final String vendorPhone =
        vi['vendorPhone'] as String? ??
        orderData['phone'] as String? ??
        (items.isNotEmpty ? items.first['phone'] ?? '' : '');
    final String vendorEmail =
        vi['vendorEmail'] as String? ??
        orderData['email'] as String? ??
        (items.isNotEmpty ? items.first['email'] ?? '' : '');
    final String storeImage =
        vi['storeImage'] as String? ?? orderData['storeImage'] as String? ?? '';
    final double shippingCharge =
        (orderData['shippingCharge'] as num?)?.toDouble() ?? 0.0;
    final double storedTotalPrice =
        (orderData['totalPrice'] as num?)?.toDouble() ?? 0.0;
    final bool orderCancelRequested =
        _localCancelOverrides.containsKey(document.id)
        ? _localCancelOverrides[document.id]!
        : (orderData['orderCancelRequested'] ?? false);

    double subTotal = 0.0;
    for (var item in items) {
      final bool isCancelled = item['cancelled'] ?? false;
      if (!isCancelled) {
        final double price = (item['price'] as num?)?.toDouble() ?? 0.0;
        final double? extraPrice = (item['extraPrice'] as num?)?.toDouble();
        final int quantity = item['quantity'] ?? 1;
        subTotal += (price + (extraPrice ?? 0.0)) * quantity;
      }
    }
    final double totalPrice = storedTotalPrice > 0
        ? storedTotalPrice
        : subTotal + shippingCharge;
    final double customerShippingDisplay = serviceType == 'delivery'
        ? (totalPrice - subTotal).clamp(0.0, double.infinity)
        : 0.0;

    if (items.isEmpty) {
      return Card(
        key: ValueKey(document.id),
        margin: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
        color: Colors.white,
        child: ListTile(
          title: Text(
            'ข้อมูลคำสั่งซื้อไม่ถูกต้อง',
            style: styles(fontSize: 14.sp, color: Colors.red),
          ),
          subtitle: Text('ไม่พบรายการสินค้า'),
        ),
      );
    }
    final IconData serviceIcon = serviceType == 'delivery'
        ? Icons.delivery_dining
        : Icons.store;
    final Color serviceColor = serviceType == 'delivery'
        ? Colors.green
        : Colors.blue;
    final String serviceLabel = serviceType.toUpperCase();
    final bool hasShipping = serviceType == 'delivery';
    List<Widget> expansionChildren = [];
    for (int i = 0; i < items.length; i++) {
      expansionChildren.add(
        _buildItemWidget(
          item: items[i],
          itemIndex: i,
          context: context,
          documentId: document.id,
          currentItems: items,
        ),
      );
      if (i < items.length - 1) {
        expansionChildren.add(Divider(height: 1, color: Colors.grey.shade300));
      }
    }
    expansionChildren.add(Divider(height: 1, color: Colors.grey.shade300));

    expansionChildren.add(
      _buildVendorDetails(
        vendorName: vendorName,
        vendorAddress: vendorAddress,
        vendorSubdistrict: vendorSubdistrict,
        vendorDistrict: vendorDistrict,
        vendorProvince: vendorProvince,
        vendorZipcode: vendorZipcode,
        vendorPhone: vendorPhone,
        vendorEmail: vendorEmail,
        storeImage: storeImage,
        vendorId: vendorId,
        items: items,
        context: context,
        orderId: document.id,
        riderId: riderId,
        riderName: riderName,
      ),
    );

    if (orderType == 'ecommerce' && status == 'shipped') {
      final String trackingNumber =
          orderData['trackingNumber'] as String? ?? '';
      final String shippingCarrier =
          orderData['shippingCarrier'] as String? ?? '';
      expansionChildren.add(
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            border: Border(top: BorderSide(color: Colors.blue.shade200)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.local_shipping,
                    color: Colors.blue[800],
                    size: 18.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'ร้านส่งของแล้ว',
                    style: styles(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
              if (trackingNumber.isNotEmpty) ...[
                SizedBox(height: 6.h),
                Text(
                  'ขนส่ง: ${shippingCarrier.isNotEmpty ? shippingCarrier : '-'}',
                  style: styles(fontSize: 12.sp, color: Colors.blue.shade800),
                ),
                Text(
                  'พัสดุ: $trackingNumber',
                  style: styles(
                    fontSize: 12.sp,
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              SizedBox(height: 4.h),
              Text(
                'กรุณาตรวจสอบสินค้าก่อนกดยืนยัน',
                style: styles(fontSize: 11.sp, color: Colors.grey.shade700),
              ),
              SizedBox(height: 12.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  label: Text(
                    'ได้รับของแล้ว',
                    style: styles(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                  ),
                  onPressed: () => _confirmReceived(document.id),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _getChatStream(vendorId, document.id),
      builder: (context, chatSnapshot) {
        int unreadCount = 0;
        if (chatSnapshot.hasData) {
          unreadCount = chatSnapshot.data!.docs.length;
        }
        final Widget vendorNameWithBadge = Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 6.h),
                Row(
                  children: [
                    Text(
                      document.id,
                      style: styles(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Spacer(),
                    Text(
                      '$statusText ${items.length}',
                      style: styles(
                        color: statusColor,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  vendorName,
                  style: styles(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            _buildUnreadBadge(unreadCount),
          ],
        );
        final Widget expansionTile = ExpansionTile(
          backgroundColor: Colors.grey.shade100,
          collapsedIconColor: Colors.transparent,
          iconColor: Colors.transparent,
          tilePadding: EdgeInsets.only(left: 12.w, right: 12),
          showTrailingIcon: false,
          collapsedBackgroundColor: Colors.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              vendorNameWithBadge,
              orderCancelRequested
                  ? Text(
                      'รอการตอบกลับ',
                      style: styles(
                        fontSize: 13.sp,
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Icon(serviceIcon, size: 20.w, color: serviceColor),
                        SizedBox(width: 4.w),
                        Text(
                          serviceLabel,
                          style: styles(
                            fontSize: 12.sp,
                            color: serviceColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Spacer(),
                        if (hasShipping)
                          Text(
                            customerShippingDisplay == 0
                                ? ' 🎉ค่าส่งฟรี!'
                                : '฿${customerShippingDisplay.toStringAsFixed(2)}',
                            style: styles(
                              fontSize: 14.sp,
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
              SizedBox(height: 4.h),
              if (statusText.isNotEmpty)
                Text(
                  '฿${totalPrice.toStringAsFixed(2)}',
                  style: styles(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              SizedBox(height: 4.h),
              Text(
                DateFormat('dd/MM/yy - kk:mm').format(timestamp.toDate()),
                style: styles(fontSize: 10.sp, color: Colors.grey),
              ),
              SizedBox(height: 4.h),
            ],
          ),
          childrenPadding: EdgeInsets.zero,
          children: expansionChildren,
        );
        final Widget orderCardContent = Card(
          key: ValueKey(document.id),
          margin: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
          color: Colors.white,
          child: expansionTile,
        );
        return Slidable(
          key: ValueKey('order_${document.id}'),
          endActionPane: ActionPane(
            motion: const ScrollMotion(),
            children: [
              SlidableAction(
                flex: 3,
                onPressed: (context) async {
                  await _toggleOrderCancelRequest(
                    documentId: document.id,
                    currentRequested: orderCancelRequested,
                    context: context,
                  );
                },
                backgroundColor: orderCancelRequested
                    ? Colors.green
                    : const Color(0xFFFE4A49),
                foregroundColor: Colors.grey.shade100,
                icon: orderCancelRequested ? Icons.restore : Icons.cancel,
                label: orderCancelRequested ? 'ถอนคำขอ' : 'ยกเลิกคำสั่งซื้อ',
              ),
            ],
          ),
          child: orderCardContent,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (auth.currentUser == null) {
      return Center(
        child: Text(
          'กรุณาเข้าสู่ระบบก่อน',
          style: styles(fontSize: 14.sp, color: Colors.red),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {},
      color: Colors.yellow.shade900,
      child: StreamBuilder<QuerySnapshot>(
        stream: _ordersStream,
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64.sp, color: Colors.red),
                  SizedBox(height: 16.h),
                  Text(
                    'เกิดข้อผิดพลาดในการโหลดรายการสั่งซื้อ: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: styles(fontSize: 14.sp, color: Colors.red),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'กรุณาสร้าง Composite Index ใน Firebase Console',
                    textAlign: TextAlign.center,
                    style: styles(fontSize: 14.sp, color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: Colors.yellow.shade900),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(height: 100.h),
                      Image.asset('images/waiting.webp', width: 300.w),
                      Center(
                        child: Text(
                          'ยังไม่มีคำสั่งซื้อ!',
                          textAlign: TextAlign.center,
                          style: styles(
                            fontSize: 20.sp,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) => _buildOrderCard(
              document: snapshot.data!.docs[index],
              context: context,
            ),
          );
        },
      ),
    );
  }
}
