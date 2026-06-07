// ordered_tab.dart - Full code for Ordered (Completed Orders) - Adapted from Preparing structure for historical display
// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:colae_cut/pages/minor_page/customer_rider_chat_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:colae_cut/services/sevice.dart';

class Ordered extends StatefulWidget {
  const Ordered({super.key});

  @override
  State<Ordered> createState() => _OrderedState();
}

class _OrderedState extends State<Ordered> {
  static const int _pageSize = 20;

  final List<DocumentSnapshot> _docs = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  bool _hasMore = true;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    if (auth.currentUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadMore();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoading || !_hasMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore || auth.currentUser == null) return;
    setState(() => _isLoading = true);

    Query query = firestore
        .collection('orders')
        .where('buyerId', isEqualTo: auth.currentUser!.uid)
        .where('status', isEqualTo: 'delivered')
        .orderBy('timestamp', descending: true)
        .limit(_pageSize);

    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    try {
      final GetOptions options = _docs.isEmpty
          ? const GetOptions(source: Source.cache)
          : const GetOptions(source: Source.server);

      QuerySnapshot snapshot;
      try {
        snapshot = await query.get(options);
        if (_docs.isEmpty && snapshot.docs.isEmpty) {
          snapshot = await query.get(const GetOptions(source: Source.server));
        }
      } catch (_) {
        snapshot = await query.get(const GetOptions(source: Source.server));
      }

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }
      if (snapshot.docs.length < _pageSize) {
        _hasMore = false;
      }
      if (mounted) {
        setState(() {
          _docs.addAll(snapshot.docs);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _docs.clear();
      _lastDocument = null;
      _hasMore = true;
      _cachedRowItems = [];
      _cachedDocsLength = 0;
    });
    await _loadMore();
  }

  List<Map<String, dynamic>> _processItems(dynamic itemsRaw) {
    if (itemsRaw == null) return [];
    List<Map<String, dynamic>> items = [];
    if (itemsRaw is List<dynamic>) {
      for (int rawIndex = 0; rawIndex < itemsRaw.length; rawIndex++) {
        try {
          final rawItem = itemsRaw[rawIndex];
          final item = Map<String, dynamic>.from(rawItem ?? {});
          if (item.isNotEmpty) {
            item['__rawIndex'] = rawIndex;
            items.add(item);
          }
        } catch (e) {
          print(
            '=== DEBUG SINGLE ITEM CAST ERROR at rawIndex $rawIndex: $e ===',
          );
        }
      }
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
    double fontSize = 12,
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
    required String documentId,
  }) {
    final bool isCancelled = item['cancelled'] ?? false;
    final bool cancelRequested = item['cancelRequested'] ?? false;
    final bool isAccepted = item['accepted'] ?? false;
    final String proName = item['proName'] ?? '';
    final int quantity = (item['quantity'] as num?)?.toInt() ?? 1;
    final double price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final double? extraPrice = (item['extraPrice'] as num?)?.toDouble();
    final String productSize = item['productSize'] ?? '';
    final List<dynamic> selectedOptionsRaw = item['selectedOptions'] ?? [];
    final List<Map<String, dynamic>> selectedOptions = selectedOptionsRaw
        .map((opt) => Map<String, dynamic>.from(opt ?? {}))
        .toList();
    final String optionsText = selectedOptions
        .map(
          (opt) =>
              '${opt['name']?.toString()} (+฿${(opt['price'] as num?)?.toDouble() ?? 0})',
        )
        .join(', ');
    final double itemSubtotal = (price + (extraPrice ?? 0.0)) * quantity;
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            proName,
            style: _getItemTextStyle(
              isCancelled: isCancelled,
              fontSize: 12.sp,
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
                '=  ฿${itemSubtotal.toStringAsFixed(2)}',
                style: _getItemTextStyle(
                  isCancelled: isCancelled,
                  fontSize: 13.sp,
                  color: Colors.deepOrange,
                  decoration: isCancelled ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
          if (extraPrice != null && extraPrice > 0) ...[
            Text(
              'Extra: +฿${extraPrice.toStringAsFixed(2)}',
              style: _getItemTextStyle(
                isCancelled: isCancelled,
                fontSize: 12.sp,
                decoration: TextDecoration.none,
                color: Colors.orange,
              ),
            ),
          ],
          Padding(
            padding: EdgeInsets.only(top: 4.h),
            child: Row(
              children: [
                if (isAccepted && !isCancelled)
                  Icon(Icons.check_circle, size: 16.sp, color: Colors.green)
                else if (isCancelled)
                  Icon(Icons.cancel, size: 16.sp, color: Colors.red)
                else if (cancelRequested)
                  Icon(Icons.hourglass_top, size: 16.sp, color: Colors.orange),
                SizedBox(width: 4.w),
                Text(
                  isAccepted && !isCancelled
                      ? 'ยืนยันแล้ว'
                      : isCancelled
                      ? 'ยกเลิก'
                      : cancelRequested
                      ? 'เคยขอคืน'
                      : 'รอการยืนยัน',
                  style: styles(
                    fontSize: 12.sp,
                    color: isCancelled
                        ? Colors.red
                        : isAccepted
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary({
    required double subTotal,
    required double shippingCharge,
    required String serviceType,
    required double totalPrice,
    String orderType = '',
    double shippingFee = 0.0,
  }) {
    final bool isEcommerce = orderType == 'ecommerce';
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ยอดรวมสินค้า',
                style: styles(fontSize: 12.sp, color: Colors.black54),
              ),
              Text(
                '฿${subTotal.toStringAsFixed(2)}',
                style: styles(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          if (serviceType == 'delivery') ...[
            SizedBox(height: 4.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ค่าส่ง',
                  style: styles(fontSize: 12.sp, color: Colors.black54),
                ),
                Text(
                  '฿${shippingCharge.toStringAsFixed(2)}',
                  style: styles(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
          if (isEcommerce && shippingFee > 0) ...[
            SizedBox(height: 4.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ค่าจัดส่ง (ทั่วประเทศ)',
                  style: styles(fontSize: 12.sp, color: Colors.black54),
                ),
                Text(
                  '฿${shippingFee.toStringAsFixed(2)}',
                  style: styles(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: 20.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'รวมทั้งหมด',
                style: styles(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                '฿${totalPrice.toStringAsFixed(2)}',
                style: styles(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepOrange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVendorDetails({
    required String vendorName,
    required String vendorAddress,
    required String vendorPhone,
    required String vendorEmail,
    required String storeImage,
    required BuildContext context,
    required String orderId,
    required String riderId,
    required String riderName,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(50),
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
              CircleAvatar(
                radius: 20.r,
                backgroundImage: storeImage.isNotEmpty
                    ? NetworkImage(storeImage)
                    : null,
                child: storeImage.isEmpty
                    ? Icon(Icons.store, size: 20.r)
                    : null,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vendorName,
                      style: styles(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    if (vendorAddress.isNotEmpty)
                      Text(
                        vendorAddress,
                        style: styles(fontSize: 12.sp, color: Colors.black54),
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
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CustomerRiderChatPage(
                      orderId: orderId,
                      riderId: riderId,
                      riderName: riderName,
                    ),
                  ),
                );
              },
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20.r,
                    backgroundColor: Colors.green.shade100,
                    child: Icon(
                      Icons.delivery_dining,
                      color: Colors.green,
                      size: 22.r,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      riderName.isNotEmpty ? riderName : 'ไรเดอร์',
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
            ),
          ],
        ],
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
    final Timestamp deliveredTime =
        orderData['deliveredAt'] as Timestamp? ?? timestamp;
    final String serviceType = orderData['serviceType'] ?? 'pickup';
    final String orderType = orderData['orderType'] as String? ?? serviceType;
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
    final String vendorAddress =
        vi['vaddress'] as String? ?? orderData['vaddress'] as String? ?? '';
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
    final String riderId = orderData['riderId']?.toString() ?? '';
    final String riderName = orderData['riderName']?.toString() ?? '';
    final double foodTotal =
        (orderData['foodTotal'] as num?)?.toDouble() ?? 0.0;
    final double vendorSubsidy = foodTotal * 0.07;
    final double customerShippingDisplay = serviceType == 'delivery'
        ? (15.0 - vendorSubsidy).clamp(0.0, 15.0)
        : 0.0;
    double subTotal = 0.0;
    for (var item in items) {
      final bool isCancelled = item['cancelled'] ?? false;
      if (!isCancelled) {
        final double price = (item['price'] as num?)?.toDouble() ?? 0.0;
        final double? extraPrice = (item['extraPrice'] as num?)?.toDouble();
        final int quantity = (item['quantity'] as num?)?.toInt() ?? 1;
        subTotal += (price + (extraPrice ?? 0.0)) * quantity;
      }
    }
    final double totalPrice =
        (orderData['totalPrice'] as num?)?.toDouble() ??
        subTotal + customerShippingDisplay;

    if (items.isEmpty) {
      return Card(
        key: ValueKey(document.id),
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
    final bool isEcommerceOrder = orderType == 'ecommerce';
    final IconData serviceIcon = isEcommerceOrder
        ? Icons.inventory_2_outlined
        : serviceType == 'delivery'
        ? Icons.delivery_dining
        : Icons.store;
    final Color serviceColor = isEcommerceOrder
        ? Colors.blue.shade800
        : serviceType == 'delivery'
        ? Colors.green
        : Colors.blue;
    final Color serviceBgColor = isEcommerceOrder
        ? Colors.blue.shade100
        : serviceType == 'delivery'
        ? Colors.green.shade100
        : Colors.grey.shade100;
    final String serviceLabel = isEcommerceOrder
        ? 'Ecommerce'
        : serviceType.toUpperCase();
    List<Widget> expansionChildren = [];
    for (int i = 0; i < items.length; i++) {
      expansionChildren.add(
        _buildItemBase(item: items[i], itemIndex: i, documentId: document.id),
      );
      if (i < items.length - 1) {
        expansionChildren.add(Divider(height: 1, color: Colors.grey.shade300));
      }
    }
    expansionChildren.add(Divider(height: 1, color: Colors.grey.shade300));
    final double shippingFee =
        (orderData['shippingFee'] as num?)?.toDouble() ?? 0.0;
    expansionChildren.add(
      _buildSummary(
        subTotal: subTotal,
        shippingCharge: customerShippingDisplay,
        serviceType: serviceType,
        totalPrice: totalPrice,
        orderType: orderType,
        shippingFee: shippingFee,
      ),
    );
    if (orderType == 'ecommerce') {
      final String trackingNumber =
          orderData['trackingNumber'] as String? ?? '';
      final String shippingCarrier =
          orderData['shippingCarrier'] as String? ?? '';
      if (trackingNumber.isNotEmpty) {
        expansionChildren.add(
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.local_shipping,
                  size: 14.sp,
                  color: Colors.grey[700],
                ),
                SizedBox(width: 6.w),
                Text(
                  '${shippingCarrier.isNotEmpty ? shippingCarrier : '-'} | $trackingNumber',
                  style: styles(fontSize: 12.sp, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        );
      }
    }
    expansionChildren.add(
      _buildVendorDetails(
        vendorName: vendorName,
        vendorAddress: vendorAddress,
        vendorPhone: vendorPhone,
        vendorEmail: vendorEmail,
        storeImage: storeImage,
        context: context,
        orderId: document.id,
        riderId: riderId,
        riderName: riderName,
      ),
    );

    final Widget expansionTile = ExpansionTile(
      backgroundColor: Colors.grey.shade100,
      collapsedIconColor: Colors.transparent,
      iconColor: Colors.transparent,
      tilePadding: EdgeInsets.only(left: 12.w, right: 12.w),
      showTrailingIcon: false,
      collapsedBackgroundColor: Colors.white,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 6.h),
          Text(
            document.id,
            style: styles(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            vendorName,
            style: styles(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black54,
            ),
          ),
          SizedBox(height: 6.h),
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: serviceBgColor,
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(serviceIcon, size: 11.sp, color: serviceColor),
                    SizedBox(width: 3.w),
                    Text(
                      serviceLabel,
                      style: styles(
                        fontSize: 10.sp,
                        color: serviceColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                '${items.length} รายการ',
                style: styles(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              Spacer(),
              Text(
                '฿${totalPrice.toStringAsFixed(2)}',
                style: styles(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            '${DateFormat('kk:mm').format(timestamp.toDate())} น. → ${DateFormat('kk:mm').format(deliveredTime.toDate())} น.',
            style: styles(
              fontSize: 12.sp,
              color: Colors.deepOrange.shade900,
              fontWeight: FontWeight.w400,
            ),
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
    return orderCardContent;
  }

  List<dynamic> _cachedRowItems = [];
  int _cachedDocsLength = 0;

  List<dynamic> _getRowItems() {
    if (_docs.length == _cachedDocsLength && _cachedRowItems.isNotEmpty) {
      return _cachedRowItems;
    }
    final grouped = _groupByDate(_docs);
    final sortedDates = grouped.keys.toList()
      ..sort((a, b) {
        final dateA = DateFormat('dd/MM/yyyy').parse(a);
        final dateB = DateFormat('dd/MM/yyyy').parse(b);
        return dateB.compareTo(dateA);
      });
    final List<dynamic> rowItems = [];
    for (final dateKey in sortedDates) {
      rowItems.add(dateKey);
      for (final doc in grouped[dateKey]!) {
        rowItems.add(doc);
      }
    }
    _cachedRowItems = rowItems;
    _cachedDocsLength = _docs.length;
    return rowItems;
  }

  Map<String, List<DocumentSnapshot>> _groupByDate(
    List<DocumentSnapshot> docs,
  ) {
    final Map<String, List<DocumentSnapshot>> grouped = {};
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final ts = data['timestamp'] as Timestamp? ?? Timestamp.now();
      final dateStr = DateFormat('dd/MM/yyyy').format(ts.toDate());
      grouped.putIfAbsent(dateStr, () => []);
      grouped[dateStr]!.add(doc);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    if (auth.currentUser == null) {
      return Center(
        child: Text(
          'กรุณาเข้าสู่ระบบก่อน',
          style: styles(fontSize: 16.sp, color: Colors.red),
        ),
      );
    }

    if (_isLoading && _docs.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: Colors.yellow.shade900),
      );
    }

    if (!_isLoading && _docs.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        color: Colors.yellow.shade900,
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SizedBox(height: 100.h),
                  Image.asset('images/waiting.webp', width: 300.w),
                  Text(
                    'ยังไม่มีปวัติการสั่งซื้อ!',
                    textAlign: TextAlign.center,
                    style: styles(
                      fontSize: 20.sp,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final List<dynamic> rowItems = _getRowItems();

    final bool hasFooter = _isLoading || !_hasMore;
    final int totalCount = rowItems.length + (hasFooter ? 1 : 0);

    return RefreshIndicator(
      onRefresh: _refresh,
      color: Colors.yellow.shade900,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: totalCount,
        itemBuilder: (context, index) {
          if (index < rowItems.length) {
            final item = rowItems[index];
            if (item is String) {
              return Container(
                width: double.infinity,
                color: Colors.grey.shade100,
                padding: EdgeInsets.only(top: 12.h),
                child: Text(
                  item,
                  textAlign: TextAlign.center,
                  style: styles(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              );
            }
            return RepaintBoundary(
              child: _buildOrderCard(
                document: item as DocumentSnapshot,
                context: context,
              ),
            );
          }
          // Footer
          if (_isLoading) {
            return Padding(
              padding: EdgeInsets.all(16.h),
              child: Center(
                child: CircularProgressIndicator(
                  color: Colors.yellow.shade900,
                  strokeWidth: 2,
                ),
              ),
            );
          }
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: Center(
              child: Text(
                '— โหลดครบแล้ว ${_docs.length} รายการ —',
                style: styles(fontSize: 12.sp, color: Colors.grey),
              ),
            ),
          );
        },
      ),
    );
  }
}
