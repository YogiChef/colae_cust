// ignore_for_file: depend_on_referenced_packages, no_leading_underscores_for_local_identifiers, unnecessary_string_interpolations, avoid_print, use_build_context_synchronously, unused_local_variable, unused_element, avoid_types_as_parameter_names, deprecated_member_use
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import 'package:colae_cut/pages/minor_page/chat_page.dart';
import 'package:colae_cut/providers/cart_provider.dart';
import 'package:colae_cut/services/sevice.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProductDetail extends StatefulWidget {
  const ProductDetail({super.key, this.productData});
  final dynamic productData;
  @override
  State createState() => _ProductDetailState();
}

class _ProductDetailState extends State<ProductDetail> {
  String asHome = 'ที่บ้าน';
  int imageIndex = 0;
  String? selectedSize;
  Map<int, List<Map<String, dynamic>>> selectedOptionsPerGroup = {};
  double extraPrice = 0.0;
  Map<String, dynamic>? selectedSizeOption;
  Map<String, dynamic>? productMap;
  String bussinessName = '';
  int quantity = 1;
  bool isLoading = false;

  String formatedDate(dynamic date) {
    final outputDateFormate = DateFormat('dd/MM/yyyy');
    final ouputDate = outputDateFormate.format(date);
    return ouputDate;
  }

  @override
  void initState() {
    super.initState();
    selectedOptionsPerGroup.clear();
    extraPrice = 0.0;
    imageIndex = 0;
    quantity = 1;
    isLoading = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    productMap = widget.productData.data();
    if (bussinessName.isEmpty) {
      _loadBussinessName();
    }
    final String vendorId = productMap?['vendorId'] ?? '';
    if (vendorId.isNotEmpty) {
      Provider.of<CartProvider>(context, listen: false).preloadVendor(vendorId);
    }
  }

  Future<void> _loadBussinessName() async {
    try {
      final String vendorId = productMap?['vendorId'] ?? '';
      String localBussinessName = productMap?['bussinessName'] ?? '';
      if (localBussinessName.isEmpty && vendorId.isNotEmpty) {
        final vendorDoc = await FirebaseFirestore.instance
            .collection('vendors')
            .doc(vendorId)
            .get();
        if (vendorDoc.exists) {
          final vendorData = vendorDoc.data() as Map;
          localBussinessName =
              vendorData['bussinessName'] ??
              vendorData['businessName'] ??
              vendorData['bussiName'] ??
              'Unknown Vendor';
        } else {
          localBussinessName = 'Vendor Not Found';
        }
      }
      if (mounted) {
        setState(() {
          bussinessName = localBussinessName;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          bussinessName = 'Error Loading Vendor';
        });
      }
    }
  }

  String _getCompositeKey(String proId, List<Map<String, dynamic>> options) {
    final List<String> optParts = options
        .map((opt) => '${opt['name'] ?? ''}_${opt['price'] ?? 0}')
        .toList();
    optParts.sort();
    final String optionStr = optParts.join('|');
    return '$proId-$optionStr';
  }

  void _updateExtraPrice(List<Map<String, dynamic>> optionGroups) {
    extraPrice = selectedOptionsPerGroup.values
        .expand((groupSelected) => groupSelected)
        .fold(0.0, (sum, opt) => sum + (opt['price'] as num? ?? 0).toDouble());
  }

  List<Map<String, dynamic>> get _flattenedSelectedOptions {
    return selectedOptionsPerGroup.values
        .expand((groupSelected) => groupSelected)
        .toList();
  }

  Future<bool> _checkStock(String proId, int quantity) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .doc(proId)
          .get();
      if (!snapshot.exists) return false;
      final data = snapshot.data() as Map;
      int currentQty = (data['pqty'] as num?)?.toInt() ?? 0;
      return currentQty >= quantity;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _showInCartDialog(String proName) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.amber,
                    size: 40.r,
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    '$proName',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                    textAlign: TextAlign.center,
                    style: styles(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
              content: Text(
                'มีในตะกร้าแล้ว ต้องการเพิ่มจำอีกหรือไม่?',
                textAlign: TextAlign.center,
                style: styles(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.red,
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text(
                    'ยกเลิก',
                    style: styles(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.orange,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
                TextButton(
                  child: Text(
                    'เพิ่มจำนวน',
                    style: styles(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.green,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                ),
              ],
            );
          },
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.of(context).size.height;
    final CartProvider _cartProvider = Provider.of<CartProvider>(
      context,
      listen: false,
    );

    if (productMap == null) {
      return const Scaffold(body: Center(child: Text('ไม่พบข้อมูลสินค้า')));
    }
    final dynamic imageUrlRaw = productMap!['imageUrl'] ?? [];
    final List<String> imageUrls = imageUrlRaw is List
        ? imageUrlRaw.cast<String>()
        : [];
    final String proName = productMap!['proName'] ?? 'ไม่ทราบชื่อสินค้า';
    final String proId = productMap!['proId'] ?? '';
    final double basePrice = (productMap!['price'] as num?)?.toDouble() ?? 0.0;
    final String description = productMap!['description'] ?? '';
    final int pqty = (productMap!['pqty'] as num?)?.toInt() ?? 0;
    final double shippingCharge =
        (productMap!['shippingCharge'] as num?)?.toDouble() ?? 0.0;
    final String email = productMap!['email'] ?? '';
    final String storeImage = productMap!['storeImage'] ?? '';
    final String vendorId = productMap!['vendorId'] ?? '';
    final String city = productMap!['city'] ?? '';
    final String state = productMap!['state'] ?? '';
    final String country = productMap!['country'] ?? '';
    final String vzipcode = productMap!['vzipcode'] ?? '';
    final String vaddress = productMap!['vaddress'] ?? '';
    final String phone = productMap!['phone'] ?? '';
    final dynamic date = productMap!['date'];
    final String displayBussinessName = bussinessName.isNotEmpty
        ? bussinessName
        : 'กำลังโหลดชื่อร้าน...';
    final String currentCompositeKey = _getCompositeKey(
      proId,
      _flattenedSelectedOptions,
    );
    final bool isInCart = _cartProvider.getCartItem.containsKey(
      currentCompositeKey,
    );
    final dynamic optionGroupsRaw = productMap!['optionGroups'] ?? [];
    final List<Map<String, dynamic>> optionGroups = optionGroupsRaw is List
        ? optionGroupsRaw.cast<Map<String, dynamic>>()
        : [];

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: height * 0.45,
                  width: double.infinity,
                  child: Hero(
                    tag: 'proName$proName',
                    child: ClipRect(
                      child: imageUrls.isNotEmpty
                          ? PhotoView(
                              imageProvider: CachedNetworkImageProvider(
                                imageUrls[imageIndex],
                              ),
                              initialScale: PhotoViewComputedScale.covered,
                            )
                          : const Icon(Icons.image_not_supported),
                    ),
                  ),
                ),
                Positioned(
                  top: 40.w,
                  left: 18.w,
                  child: CircleAvatar(
                    backgroundColor: Colors.yellow.shade50,
                    radius: 20.sp,
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        size: 24.sp,
                        color: Colors.black54,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  child: SizedBox(
                    height: 50.w,
                    width: MediaQuery.of(context).size.width,
                    child: imageUrls.isNotEmpty
                        ? ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: imageUrls.length,
                            itemBuilder: (context, index) {
                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    imageIndex = index;
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Container(
                                    height: 60.w,
                                    width: 70.w,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.purple),
                                    ),
                                    child: CachedNetworkImage(
                                      imageUrl: imageUrls[index],
                                      fit: BoxFit.cover,
                                      memCacheWidth: 140,
                                      memCacheHeight: 120,
                                      placeholder: (context, url) =>
                                          const Center(
                                            child: SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 1.5,
                                              ),
                                            ),
                                          ),
                                      errorWidget: (context, url, error) =>
                                          const Icon(Icons.image_not_supported),
                                    ),
                                  ),
                                ),
                              );
                            },
                          )
                        : const SizedBox(),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          proName,
                          style: styles(
                            fontSize: 18.sp,
                            color: Colors.cyan[900],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Builder(
                        builder: (context) {
                          final foodTotal = (basePrice + extraPrice) * quantity;

                          return Center(
                            child: Text(
                              '฿${foodTotal.toStringAsFixed(2)}',
                              style: styles(
                                fontSize: 16.sp,
                                color: Colors.deepOrange[900],
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        description,
                        textAlign: TextAlign.center,
                        style: styles(fontSize: 14.sp, color: Colors.grey),
                      ),
                      Padding(
                        padding: EdgeInsets.only(
                          left: 20.w,
                          top: 12.h,
                          right: 20.w,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quantity',
                              textAlign: TextAlign.start,
                              style: styles(
                                color: pqty <= 10
                                    ? Colors.red
                                    : Colors.blueGrey,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Spacer(),
                            Container(
                              padding: EdgeInsets.all(8.h),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  width: 1,
                                  color: pqty <= 10 ? Colors.red : Colors.blue,
                                ),
                              ),
                              child: Text(
                                '$pqty',
                                style: styles(
                                  color: pqty <= 10 ? Colors.red : Colors.grey,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 24.sp,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 24.sp,
                            backgroundColor: Colors.amber.withAlpha(90),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                if (quantity > 1) {
                                  setState(() {
                                    quantity--;
                                  });
                                }
                              },
                              icon: Icon(
                                Icons.remove,
                                color: Colors.red,
                                size: 32.sp,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            width: width * 0.3.w,
                            padding: EdgeInsets.symmetric(
                              horizontal: 20.w,
                              vertical: 10.h,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(5.r),
                            ),
                            child: Text(
                              '$quantity',
                              textAlign: TextAlign.center,
                              style: styles(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                                color: pqty <= 10 ? Colors.red : mainColor,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          CircleAvatar(
                            radius: 24.sp,
                            backgroundColor: Colors.blue.withAlpha(90),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                if (quantity < pqty) {
                                  setState(() {
                                    quantity++;
                                  });
                                }
                              },
                              icon: Icon(
                                Icons.add,
                                color: Colors.green,
                                size: 32.sp,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10.h),
                      if (optionGroups.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'ตัวเลือกเมนู',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...optionGroups.asMap().entries.map((groupEntry) {
                          int groupIndex = groupEntry.key;
                          Map<String, dynamic> group = groupEntry.value;
                          final String groupType =
                              group['type'] ?? 'multiSelect';
                          final String? groupName = group['name'];
                          final List<Map<String, dynamic>> groupOptions =
                              (group['options'] as List?)
                                  ?.cast<Map<String, dynamic>>() ??
                              [];
                          final List<Map<String, dynamic>> selectedInGroup =
                              selectedOptionsPerGroup[groupIndex] ?? [];
                          final Map<String, String> _typeLabels = {
                            'multiSelect': 'เลือกได้หลายอย่าง',
                            'free': 'ฟรี',
                            'size': 'ขนาด',
                            'singleSelect': 'เลือกได้อย่างเดียว',
                            'radio': 'เลือกอย่างเดียว',
                          };
                          final String typeDisplay =
                              _typeLabels[groupType] ?? groupType;
                          IconData groupIcon = _getGroupIcon(groupType);
                          Color groupColor = _getGroupColor(groupType);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ExpansionTile(
                              title: Text(groupName ?? typeDisplay),
                              subtitle: Text(
                                '$typeDisplay • ${groupOptions.length} ตัวเลือก',
                              ),
                              leading: Icon(groupIcon, color: groupColor),
                              children: [
                                if (groupOptions.isEmpty)
                                  const ListTile(
                                    title: Text('ไม่มีตัวเลือกในกลุ่มนี้'),
                                  )
                                else ...[
                                  if (groupType == 'free' ||
                                      groupType == 'multiSelect') ...[
                                    ...groupOptions.map(
                                      (opt) => CheckboxListTile(
                                        activeColor: mainColor,
                                        checkColor: Colors.white,
                                        title: Text(
                                          '${opt['name']} ${groupType != 'free' ? '+฿${opt['price']}' : '(ฟรี)'}',
                                        ),
                                        value: selectedInGroup.any(
                                          (sel) => sel['name'] == opt['name'],
                                        ),
                                        onChanged: (bool? val) {
                                          setState(() {
                                            final currentSelected =
                                                selectedInGroup.toList();
                                            if (val == true) {
                                              if (!currentSelected.any(
                                                (sel) =>
                                                    sel['name'] == opt['name'],
                                              )) {
                                                currentSelected.add(
                                                  Map<String, dynamic>.from(
                                                    opt,
                                                  ),
                                                );
                                              }
                                            } else {
                                              currentSelected.removeWhere(
                                                (sel) =>
                                                    sel['name'] == opt['name'],
                                              );
                                            }
                                            selectedOptionsPerGroup[groupIndex] =
                                                currentSelected;
                                            extraPrice = selectedOptionsPerGroup
                                                .values
                                                .expand((g) => g)
                                                .fold(
                                                  0.0,
                                                  (s, o) =>
                                                      s +
                                                      (o['price'] as num? ?? 0)
                                                          .toDouble(),
                                                );
                                          });
                                        },
                                      ),
                                    ),
                                  ] else ...[
                                    ...groupOptions.map(
                                      (opt) => RadioListTile<String>(
                                        title: Text(
                                          '${opt['name']} ${groupType == 'size' ? '+฿${opt['price']}' : ''}',
                                        ),
                                        value: opt['name'],
                                        groupValue: selectedInGroup.isNotEmpty
                                            ? selectedInGroup.first['name']
                                            : '',
                                        activeColor: mainColor,
                                        onChanged: (String? val) {
                                          setState(() {
                                            if (val != null &&
                                                val == opt['name']) {
                                              selectedOptionsPerGroup[groupIndex] =
                                                  [
                                                    Map<String, dynamic>.from(
                                                      opt,
                                                    ),
                                                  ];
                                              selectedSizeOption = opt;
                                            } else {
                                              selectedOptionsPerGroup.remove(
                                                groupIndex,
                                              );
                                              selectedSizeOption = null;
                                            }
                                            extraPrice = selectedOptionsPerGroup
                                                .values
                                                .expand((g) => g)
                                                .fold(
                                                  0.0,
                                                  (s, o) =>
                                                      s +
                                                      (o['price'] as num? ?? 0)
                                                          .toDouble(),
                                                );
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ],
                                if (groupOptions.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      'เลือกแล้ว: ${selectedInGroup.length} ตัวเลือก • ราคาเพิ่ม: ฿${selectedInGroup.fold(0.0, (sum, opt) => sum + (opt['price'] as num? ?? 0).toDouble()).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        Text(
                          'ราคารวมจากตัวเลือกทั้งหมด: ฿${extraPrice.toStringAsFixed(2)}',
                          style: styles(fontSize: 14, color: Colors.green),
                        ),
                      ],
                      SizedBox(height: 10.h),
                      if (shippingCharge > 0)
                        Text(
                          'Shipping Charge: ฿${shippingCharge.toStringAsFixed(2)}',
                          style: styles(fontSize: 14.sp, color: Colors.blue),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: 20.w, bottom: 10.h, top: 20.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20.r,
                    backgroundImage: storeImage.isNotEmpty
                        ? CachedNetworkImageProvider(storeImage)
                        : null,
                    child: storeImage.isEmpty ? const Icon(Icons.store) : null,
                  ),
                  Padding(
                    padding: EdgeInsets.only(left: 12.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bussinessName.isNotEmpty
                              ? bussinessName
                              : 'ร้านค้าไม่ระบุชื่อ',
                          style: styles(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          email,
                          style: styles(fontSize: 12.sp, color: Colors.grey),
                        ),
                        Padding(
                          padding: EdgeInsets.only(top: 8.0.w),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  if (phone.isNotEmpty) {
                                    callVendor(phone);
                                  }
                                },
                                child: Container(
                                  height: 45.r,
                                  width: 45.r,
                                  decoration: BoxDecoration(
                                    color: Colors.blue[600],
                                    borderRadius: BorderRadius.circular(16.r),
                                  ),
                                  child: Icon(
                                    Icons.phone,
                                    color: Colors.white,
                                    size: 24.r,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              GestureDetector(
                                onTap: () {
                                  if (vendorId.isNotEmpty &&
                                      proId.isNotEmpty &&
                                      proName.isNotEmpty) {
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
                                  }
                                },
                                child: Container(
                                  height: 45.r,
                                  width: 45.r,
                                  decoration: BoxDecoration(
                                    color: mainColor,
                                    borderRadius: BorderRadius.circular(16.r),
                                  ),
                                  child: Icon(
                                    IconlyLight.chat,
                                    color: Colors.white,
                                    size: 24.r,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 100.h),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: ColoredBox(
          color: Colors.white,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewPadding.bottom + 12.h,
              left: 20.w,
              right: 20.w,
              top: 8.h,
            ),
            child: SizedBox(
              height: height * .06.h,
              width: MediaQuery.of(context).size.width * 0.7,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5.r),
                  ),
                ),
                icon: isLoading
                    ? const SizedBox.shrink()
                    : Icon(
                        Icons.shopping_cart_outlined,
                        size: 20.sp,
                        color: Colors.white,
                      ),
                label: isLoading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20.w,
                            height: 20.h,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Text(
                            'กำลังเพิ่ม...',
                            style: styles(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Builder(
                        builder: (context) {
                          final foodTotal = (basePrice + extraPrice) * quantity;
                          return Text(
                            '฿${foodTotal.toStringAsFixed(2)}',
                            style: styles(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                      ),
                onPressed: isLoading
                    ? null
                    : () async {
                        if (mounted) setState(() => isLoading = true);
                        await _handleAddToCart();
                      },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleAddToCart() async {
    if (productMap == null) return;
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    final String proName = productMap!['proName'] ?? '';
    final String proId = productMap!['proId'] ?? '';
    final double basePrice = (productMap!['price'] as num?)?.toDouble() ?? 0.0;
    final int pqty = (productMap!['pqty'] as num?)?.toInt() ?? 0;
    final double shippingCharge =
        (productMap!['shippingCharge'] as num?)?.toDouble() ?? 0.0;
    final String email = productMap!['email'] ?? '';
    final String storeImage = productMap!['storeImage'] ?? '';
    final String vendorId = productMap!['vendorId'] ?? '';
    final String city = productMap!['city'] ?? '';
    final String state = productMap!['state'] ?? '';
    final String country = productMap!['country'] ?? '';
    final String vzipcode = productMap!['vzipcode'] ?? '';
    final String vaddress = productMap!['vaddress'] ?? '';
    final String vsubdistrict = productMap!['vsubdistrict'] ?? '';
    final String vdistrict = productMap!['vdistrict'] ?? '';
    final String vprovince = productMap!['vprovince'] ?? '';
    final String phone = productMap!['phone'] ?? '';
    final dynamic date = productMap!['date'];
    final dynamic imageUrlRaw = productMap!['imageUrl'] ?? [];
    final List<String> imageUrls = imageUrlRaw is List
        ? imageUrlRaw.cast<String>()
        : [];

    try {
      if (quantity > pqty) {
        Fluttertoast.showToast(
          msg: 'สต็อกไม่พอ: เหลือ $pqty ชิ้น',
          backgroundColor: Colors.red,
        );
        if (mounted) setState(() => isLoading = false);
        return;
      }

      _checkStock(proId, quantity).then((hasStock) {
        if (!hasStock && mounted) {
          Fluttertoast.showToast(msg: 'สต็อกเปลี่ยนแปลง กรุณาลองใหม่อีกครั้ง');
        }
      });

      final String currentKey = _getCompositeKey(
        proId,
        _flattenedSelectedOptions,
      );
      final bool inCart = cartProvider.getCartItem.containsKey(currentKey);
      if (inCart) {
        final bool confirmed = await _showInCartDialog(proName);
        if (!confirmed) {
          if (mounted) setState(() => isLoading = false);
          return;
        }
      }

      await cartProvider.addProductToCart(
        proName,
        proId,
        bussinessName,
        imageUrls,
        quantity,
        pqty,
        basePrice,
        shippingCharge,
        vendorId,
        selectedSizeOption?['name'] ?? '',
        date,
        _flattenedSelectedOptions,
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'ไม่สามารถเพิ่มสินค้าได้ กรุณาลองใหม่',
        backgroundColor: Colors.red,
        toastLength: Toast.LENGTH_LONG,
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  IconData _getGroupIcon(String type) {
    switch (type) {
      case 'free':
        return Icons.free_breakfast;
      case 'singleSelect':
      case 'size':
        return Icons.radio_button_checked;
      case 'multiSelect':
        return Icons.check_box;
      default:
        return Icons.menu;
    }
  }

  Color _getGroupColor(String type) {
    switch (type) {
      case 'free':
        return Colors.green;
      case 'singleSelect':
      case 'size':
        return Colors.purple;
      case 'multiSelect':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
