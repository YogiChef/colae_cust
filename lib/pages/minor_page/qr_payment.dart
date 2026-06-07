// ignore_for_file: avoid_print, invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member, no_leading_underscores_for_local_identifiers, duplicate_ignore, use_build_context_synchronously, unused_local_variable, empty_catches, unnecessary_cast, deprecated_member_use, unnecessary_underscores
import 'dart:async';
import 'dart:convert'; // สำหรับ UTF-8 hex encode
import 'dart:io'; // สำหรับ File path
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:colae_cut/models/cart_attributes.dart';
import 'package:colae_cut/models/vendor_model.dart';
import 'package:colae_cut/providers/cart_provider.dart';
import 'package:colae_cut/services/sevice.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // BackgroundIsolateBinaryMessenger, RootIsolateToken
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gal/gal.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';

class QrPaymentPage extends StatefulWidget {
  const QrPaymentPage({super.key});
  @override
  State createState() => _QrPaymentPageState();
}

class _QrPaymentPageState extends State<QrPaymentPage>
    with WidgetsBindingObserver {
  late String docId;
  late String fullName;
  late String phone;
  late String address;
  VendorModel? _currentVendor;
  String? selectedVendorId;
  String? selectedPaymentMethod;
  bool isProcessing = false;
  late Map<String, dynamic> _userData;
  late ScreenshotController _screenshotController;
  // ✅ Cache ผล future ใน state — ไม่สร้าง future ใหม่ทุก rebuild
  Future<Map<String, dynamic>>? _userDataFuture;
  Future<Map<String, double>>? _pricesFuture;
  final Map<String, VendorModel> _loadedVendors = {};
  bool _isNavigating = false;
  Position? _currentPosition;
  String? _multiVendorGroupId;
  final Map<String, String> _bankCodes = {
    'ธนาคารกสิกรไทย (Kasikorn Bank)': '002',
    'ธนาคารกรุงไทย (Krungthai Bank)': '004',
    'ธนาคารไทยพาณิชย์ (SCB)': '014',
    'ธนาคารกรุงศรีอยุธยา (Krungsri)': '006',
    'ธนาคารทหารไทยธนชาต (TMBThanachart)': '011',
    'ธนาคารกรุงเทพ (Bangkok Bank)': '003',
    'ธนาคารออมสิน (Government Savings Bank)': '017',
    'ธนาคารอาคารสงเคราะห์ (Government Housing Bank)': '016',
  };
  @override
  void initState() {
    super.initState();
    _screenshotController = ScreenshotController();
    _initLocation();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final groupedItems = cartProvider.groupedItems;

      if (groupedItems.isEmpty) {
        if (!_isNavigating) _navigateToHome();
        return;
      }

      if (cartProvider.isMultiVendor &&
          cartProvider.serviceType == 'delivery') {
        await cartProvider.deliveryShipping;
        // สร้าง groupId ครั้งเดียวสำหรับทุก vendor ในกลุ่ม
        _multiVendorGroupId =
            'group_${FirebaseAuth.instance.currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}';
      }

      if (!mounted) return;

      final firstVendorId = groupedItems.keys.first;
      setState(() {
        selectedVendorId =
            firstVendorId; // ← ทั้ง single และ multi ใช้ firstVendorId
        _userDataFuture = FirebaseFirestore.instance
            .collection('buyers')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .get()
            .then((doc) => doc.data() ?? {});
        _pricesFuture = _calculatePricesForAllVendors(
          cartProvider,
          groupedItems,
        );
      });
      _loadVendor(firstVendorId);
    });
  }

  StreamSubscription<Position>? _positionStream;
  @override
  void dispose() {
    _positionStream?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
      if (mounted) _currentPosition = pos;
      print(
        '[QrPayment] _initLocation OK — lat=${pos.latitude} lng=${pos.longitude}',
      );
    } catch (e) {}
  }

  void _navigateToHome() {
    if (!mounted || _isNavigating) return;
    _isNavigating = true;
    Get.until((route) => route.isFirst);
  }

  Future<void> _loadVendor(String vendorId) async {
    if (_loadedVendors.containsKey(vendorId)) {
      _currentVendor = _loadedVendors[vendorId];
      if (mounted) setState(() {});
      return;
    }
    try {
      final vendorDoc = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(vendorId)
          .get();
      if (vendorDoc.exists) {
        final vendorData = VendorModel.fromJson(vendorDoc.data()!);
        setState(() {
          _loadedVendors[vendorId] = vendorData;
          if (selectedVendorId == vendorId) {
            _currentVendor = vendorData;
          }
        });
      }
    } catch (e) {}
  }

  Future<bool> _setOrderWithRetry(
    DocumentReference orderRef,
    Map<String, dynamic> orderData, {
    int maxRetries = 3,
  }) async {
    int retryCount = 0;
    while (retryCount < maxRetries) {
      try {
        await orderRef.set(orderData);

        return true;
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          retryCount++;

          if (retryCount >= maxRetries) {
            return false;
          }
          await Future.delayed(const Duration(seconds: 1));
        } else {
          rethrow;
        }
      } catch (e) {
        rethrow;
      }
    }
    return false;
  }

  Future<void> _processCashPayment({
    required CartProvider cartProvider,
    required Map<String, dynamic> userData,
    required String vendorId,
    required Map<String, dynamic> orderDataTemplate,
    required String orderId,
    required DocumentReference orderRef,
  }) async {
    print(
      '[Cash] _processCashPayment start — orderId=$orderId vendorId=$vendorId',
    );
    EasyLoading.show(status: 'กำลังสร้างออร์เดอร์...');
    try {
      final notifRef = await FirebaseFirestore.instance
          .collection('notifications')
          .add({
            'to': vendorId,
            'type': 'new_order_cash',
            'orderId': orderId,
            'message': 'มีออร์เดอร์ใหม่ (ชำระเงินสด)',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
          });

      cartProvider.clearItemsByVendor(vendorId);

      _handleNextVendorOrHome(cartProvider);
    } catch (e) {
    } finally {
      EasyLoading.dismiss();
    }
  }

  void _selectPaymentMethod(
    String method,
    CartProvider cartProvider,
    Map<String, dynamic> userData,
  ) async {
    if (cartProvider.isMultiVendor && selectedVendorId == null) {
      return;
    }
    if (!mounted) return;
    setState(() => isProcessing = true);
    try {
      final String buyerId = FirebaseAuth.instance.currentUser!.uid;
      final String vendorId =
          selectedVendorId ?? cartProvider.groupedItems.keys.first;
      final double foodSubtotal = cartProvider.subTotalByVendor(vendorId);
      final double customerShip;
      if (cartProvider.serviceType == 'delivery') {
        customerShip = cartProvider.isMultiVendor
            ? cartProvider.getCustomerShippingForVendor(vendorId)
            : await cartProvider.customerShippingByVendor(vendorId);
      } else if (cartProvider.serviceType == 'ecommerce') {
        customerShip = cartProvider.ecommerceShippingForVendor(vendorId);
      } else {
        customerShip = 0.0;
      }
      final double vendorTotal = foodSubtotal + customerShip;
      final List<CartAttr> vendorItems =
          cartProvider.groupedItems[vendorId] ?? [];
      if (vendorItems.isEmpty) {
        setState(() => isProcessing = false);
        return;
      }
      if (method == 'qr') {
        await _loadVendor(vendorId);
        if (_currentVendor == null) {
          setState(() => isProcessing = false);
          return;
        }
        final bool hasPromptPay =
            _currentVendor!.promptPayId.isNotEmpty &&
            _currentVendor!.promptPayId != 'null';
        final bool hasBankAccount =
            _currentVendor!.bankAccount.isNotEmpty &&
            _currentVendor!.bankAccount != 'null' &&
            _currentVendor!.bankName.isNotEmpty;
        final bool hasQrImage =
            _currentVendor!.qrCodeImage != null &&
            _currentVendor!.qrCodeImage!.isNotEmpty;
        if (!hasPromptPay && !hasBankAccount && !hasQrImage) {
          setState(() => isProcessing = false);
          return;
        }
        _showQrDialog(
          vendorTotal: vendorTotal,
          cartProvider: cartProvider,
          userData: userData,
          vendorId: vendorId,
          vendorItems: vendorItems,
          pageContext: context,
        );
        return;
      }

      print(
        '[SelectPayment] method=$method vendorId=$vendorId vendorTotal=$vendorTotal items=${vendorItems.length}',
      );

      final String orderId = generateOrderId(
        FirebaseAuth.instance.currentUser!.uid,
      );

      final DocumentReference orderRef = FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId);
      GeoPoint? vendorLocation;
      Map<String, dynamic> vendorDocData = {};
      try {
        final vendorDoc = await FirebaseFirestore.instance
            .collection('vendors')
            .doc(vendorId)
            .get();
        if (vendorDoc.exists) {
          vendorDocData = vendorDoc.data() as Map<String, dynamic>;
          vendorLocation = vendorDocData['location'] as GeoPoint?;
        }
      } catch (e) {
        vendorLocation = GeoPoint(0, 0);
      }
      if (_currentPosition == null) {
        try {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 15),
          );
          if (mounted) _currentPosition = pos;
        } catch (e) {}
      }
      if (_currentPosition == null && cartProvider.serviceType != 'ecommerce') {
        setState(() => isProcessing = false);
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('ไม่สามารถระบุตำแหน่งได้'),
              content: const Text(
                'กรุณาเปิด GPS และลองใหม่อีกครั้ง\nระบบต้องการตำแหน่งของคุณ',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ตกลง'),
                ),
              ],
            ),
          );
        }
        return;
      }

      final double foodTotal = vendorItems.fold(
        0.0,
        (acc, item) =>
            acc + (item.price + (item.extraPrice ?? 0.0)) * item.quantity,
      );
      final double distanceKm = vendorLocation != null
          ? Geolocator.distanceBetween(
                  vendorLocation.latitude,
                  vendorLocation.longitude,
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                ) /
                1000
          : 0.0;
      final bool isDelivery = cartProvider.serviceType == 'delivery';
      final bool isEcommerce = cartProvider.serviceType == 'ecommerce';
      final double customerShipping;
      final double riderEarnings;
      if (isDelivery) {
        if (cartProvider.isMultiVendor) {
          customerShipping = cartProvider.getCustomerShippingForVendor(
            vendorId,
          );
          riderEarnings = cartProvider.getRiderEarningsForVendor(vendorId);
          print('=== QR ORDER SHIPPING ===');
          print('vendorId: $vendorId');
          print('customerShipping from cache: $customerShipping');
          print('riderEarnings from cache: $riderEarnings');
        } else {
          customerShipping = CartProvider.calcCustomerShipping(
            foodTotal,
            distanceKm: distanceKm,
          );
          riderEarnings = CartProvider.calcRiderEarnings(foodTotal, distanceKm);
        }
      } else if (isEcommerce) {
        customerShipping = cartProvider.ecommerceShippingForVendor(vendorId);
        riderEarnings = 0.0;
      } else {
        customerShipping = 0.0;
        riderEarnings = 0.0;
      }

      // คำนวณระยะ vendor ↔ customer (เฉพาะ ecommerce, บันทึกทุกค่า)
      double? orderDistance;
      if (isEcommerce && vendorLocation != null && _currentPosition != null) {
        if (vendorLocation.latitude != 0 && _currentPosition!.latitude != 0) {
          final dist = Geolocator.distanceBetween(
            vendorLocation.latitude, vendorLocation.longitude,
            _currentPosition!.latitude, _currentPosition!.longitude,
          ) / 1000.0;
          orderDistance = double.parse(dist.toStringAsFixed(1));
        }
      }

      final double platformCommission = isDelivery
          ? CartProvider.calcPlatformCommission(foodTotal)
          : 0.0;
      final double vendorEarningsCalc = isDelivery
          ? CartProvider.calcVendorEarnings(foodTotal)
          : foodTotal;

      final CartAttr? firstItem = vendorItems.isNotEmpty
          ? vendorItems.first
          : null;
      final user = FirebaseAuth.instance.currentUser!;
      Map<String, dynamic> orderDataTemplate = {
        'orderId': orderId,
        'buyerId': buyerId,
        'serviceType': cartProvider.serviceType,
        'orderType': isEcommerce ? 'ecommerce' : (isDelivery ? 'delivery' : 'pickup'),
        'paymentMethod': method,
        'totalPrice': foodTotal + customerShipping,
        'shippingCharge': customerShipping,
        'shippingFee': isEcommerce ? customerShipping : 0,
        'riderEarnings': riderEarnings,
        'isMultiVendor': cartProvider.isMultiVendor,
        'platformCommission': platformCommission,
        'vendorEarnings': vendorEarningsCalc,
        'items': vendorItems.map((item) => item.toJson()).toList(),
        'vendorId': vendorId,
        'status': 'pending',
        'slipStatus': null,
        'slipChatId': null,
        'timestamp': FieldValue.serverTimestamp(),
        'askme': false,
        'customerLocation': _currentPosition != null
            ? GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude)
            : const GeoPoint(0, 0),
        'multiVendorGroupId': _multiVendorGroupId,
        'vendorInfo': {
          'bussinessName':
              vendorDocData['bussinessName'] ?? firstItem?.bussinessName ?? '',
          'vaddress': vendorDocData['address'] ?? '',
          'vsubdistrict': vendorDocData['subdistrict'] ?? '',
          'vdistrict': vendorDocData['district'] ?? '',
          'vprovince': vendorDocData['province'] ?? vendorDocData['city'] ?? '',
          'vzipcode': vendorDocData['vzipcode'] ?? '',
          'vendorPhone': vendorDocData['phone'] ?? '',
          'vendorEmail': vendorDocData['email'] ?? '',
          'storeImage': vendorDocData['image'] ?? '',
          'vendorLocation': vendorLocation ?? GeoPoint(0, 0),
        },
        'buyerInfo': {
          'fullName': userData['fullName'] ?? user.displayName ?? '',
          'custphone': userData['phone'] ?? '',
          'custemail': userData['email'] ?? user.email ?? '',
          'address': userData['address'] ?? '',
          'buyerImage': userData['profileImage'] ?? user.photoURL ?? '',
        },
      };
      if (cartProvider.isDineIn && cartProvider.tableId != null) {
        orderDataTemplate['tableId'] = cartProvider.tableId;
      }
      if (orderDistance != null) {
        orderDataTemplate['orderDistance'] = orderDistance;
      }
      if (isEcommerce) {
        orderDataTemplate['shippingAddress'] = {
          'name': userData['fullName'] ?? '',
          'phone': userData['phone'] ?? '',
          'address': userData['address'] ?? '',
          'city': userData['city'] ?? '',
          'state': userData['state'] ?? '',
          'country': userData['country'] ?? '',
          'zipcode': userData['zipcode'] ?? '',
        };
      }

      final bool setSuccess = await _setOrderWithRetry(
        orderRef,
        orderDataTemplate,
      );
      if (!setSuccess) {
        setState(() => isProcessing = false);
        return;
      }

      if (method == 'cash') {
        await _processCashPayment(
          cartProvider: cartProvider,
          userData: userData,
          vendorId: vendorId,
          orderDataTemplate: orderDataTemplate,
          orderId: orderId,
          orderRef: orderRef,
        );
      } else if (method == 'stripe') {
        // await _processStripePayment(
        //   vendorTotal,
        //   cartProvider,
        //   userData,
        //   vendorId,
        //   orderId,
        //   orderRef,
        // );
      }
    } catch (e) {
    } finally {
      if (mounted) {
        setState(() => isProcessing = false);
      }
    }
  }

  void _showQrDialog({
    required double vendorTotal,
    required CartProvider cartProvider,
    required Map<String, dynamic> userData,
    required String vendorId,
    required List<CartAttr> vendorItems,
    required BuildContext pageContext,
  }) {
    if (!mounted) return;
    final vendorModel = _loadedVendors[vendorId];
    if (vendorModel == null) {
      setState(() => isProcessing = false);
      return;
    }
    _currentVendor = vendorModel;
    final String storeName = _currentVendor!.bussinessName;
    final bool hasPromptPay =
        _currentVendor!.promptPayId.isNotEmpty &&
        _currentVendor!.promptPayId != 'null';
    final bool hasBankAccount =
        _currentVendor!.bankAccount.isNotEmpty &&
        _currentVendor!.bankAccount != 'null' &&
        _currentVendor!.bankName.isNotEmpty;
    final bool hasQrImage =
        _currentVendor!.qrCodeImage != null &&
        _currentVendor!.qrCodeImage!.isNotEmpty;
    final bool hasBank = hasPromptPay || hasBankAccount || hasQrImage;
    if (!hasPromptPay && !hasBankAccount && !hasQrImage) {
      if (mounted) setState(() => isProcessing = false);
      return;
    }
    final String bankAccount = hasBankAccount
        ? _currentVendor!.bankAccount.replaceAll(RegExp(r'[^\d]'), '')
        : '';
    final String bankName = _currentVendor!.bankName;
    final String promptPayId = hasPromptPay ? _currentVendor!.promptPayId : '';
    try {
      showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'QR Dialog barrier',
        barrierColor: Colors.black.withOpacity(0.5),
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder:
            (
              BuildContext dialogContext,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) {
              bool _isConfirming = false;
              return StatefulBuilder(
                builder: (context, setDialogState) {
                  Widget qrWidget;
                  if (hasPromptPay) {
                    final String promptPayPayload = _generatePromptPayPayload(
                      promptPayId: promptPayId,
                      amount: vendorTotal,
                    );
                    qrWidget = QrImageView(
                      data: promptPayPayload,
                      version: QrVersions.auto,
                      size: 250.h,
                      backgroundColor: Colors.white,
                    );
                  } else if (hasQrImage) {
                    qrWidget = ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: _currentVendor!.qrCodeImage!,
                        width: 250.w,
                        height: 250.h,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(
                            Icons.error,
                            size: 50,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    );
                  } else if (hasBankAccount && bankName.isNotEmpty) {
                    final String bankCode = _bankCodes[bankName] ?? '002';
                    final String payload = generateThaiQRPayload(
                      bankCode: bankCode,
                      accountNumber: bankAccount,
                      amount: vendorTotal,
                      merchantName: _currentVendor!.bussinessName,
                    );
                    qrWidget = QrImageView(
                      data: payload,
                      version: QrVersions.auto,
                      size: 250.h,
                      backgroundColor: Colors.white,
                    );
                  } else {
                    qrWidget = Container(
                      color: Colors.red.shade50,
                      padding: EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_scanner_outlined,
                            size: 50,
                            color: Colors.red,
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            'ไม่พบ QR Code สำหรับร้านนี้\nกรุณาติดต่อร้านค้าเพื่อชำระเงิน',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.red,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }
                  return Scaffold(
                    appBar: AppBar(
                      title: Text(
                        'สแกน QR Code',
                        style: styles(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      leading: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                      backgroundColor: mainColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      actions: [],
                      centerTitle: true,
                    ),
                    body: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Screenshot(
                              controller: _screenshotController,
                              child: RepaintBoundary(
                                child: SizedBox(
                                  width: 240.w,
                                  height: 240.h,
                                  child: Center(child: qrWidget),
                                ),
                              ),
                            ),
                            SizedBox(height: 24.h),
                            Text(
                              'ยอดที่ต้องชำระ: ฿${vendorTotal.toStringAsFixed(2)}',
                              style: styles(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              'ชื่อผู้รับ: ${_currentVendor!.accountName}',
                              style: styles(
                                fontSize: 14.sp,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (!hasPromptPay && !hasQrImage) ...[
                              SizedBox(height: 6.h),
                              Text(
                                bankName,
                                style: styles(
                                  fontSize: 12.sp,
                                  color: Colors.black45,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'เลขบัญชี: $bankAccount',
                                style: styles(
                                  fontSize: 12.sp,
                                  color: Colors.black45,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ] else if (hasPromptPay) ...[
                              SizedBox(height: 12.h),
                              Text(
                                'PromptPay ID: $promptPayId',
                                style: styles(
                                  fontSize: 12.sp,
                                  color: Colors.indigo,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 14.h),
                              SizedBox(height: 20.h),
                            ] else if (hasQrImage) ...[
                              SizedBox(height: 4.h),
                              Text(
                                'QR Code จากร้านค้า',
                                style: styles(
                                  fontSize: 12.sp,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    bottomNavigationBar: SafeArea(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: 16.w,
                          right: 16.w,
                          bottom:
                              MediaQuery.of(context).viewPadding.bottom + 12.h,
                          top: 10.h,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  if (!mounted || !dialogContext.mounted) {
                                    return;
                                  }

                                  try {
                                    final Uint8List? imageBytes =
                                        await _screenshotController.capture();
                                    if (imageBytes != null &&
                                        imageBytes.isNotEmpty) {
                                      await Gal.putImageBytes(imageBytes);
                                      if (dialogContext.mounted) {
                                        ScaffoldMessenger.of(
                                          dialogContext,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('บันทึกรูปสำเร็จ'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    } else {
                                      if (dialogContext.mounted) {
                                        ScaffoldMessenger.of(
                                          dialogContext,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('ไม่สามารถจับภาพได้'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  } catch (e) {
                                    if (dialogContext.mounted) {
                                      ScaffoldMessenger.of(
                                        dialogContext,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('บันทึกไม่สำเร็จ: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber.shade100,
                                  foregroundColor: Colors.white,
                                  minimumSize: Size(double.infinity, 50.h),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(7.r),
                                  ),
                                ),
                                label: Text(
                                  'บันทึก',
                                  style: styles(
                                    fontSize: 14.sp,
                                    color: Colors.indigo,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                icon: Icon(
                                  Icons.save_alt_rounded,
                                  color: Colors.indigo,
                                  size: 20.r,
                                ),
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: ElevatedButton(
                                onPressed:
                                    (hasPromptPay ||
                                            hasQrImage ||
                                            (hasBankAccount &&
                                                bankName.isNotEmpty &&
                                                bankAccount.isNotEmpty)) &&
                                        !_isConfirming
                                    ? () async {
                                        if (_isConfirming) {
                                          return;
                                        }

                                        setDialogState(
                                          () => _isConfirming = true,
                                        );
                                        try {
                                          Position? _gpsPos = _currentPosition;
                                          if (_gpsPos == null) {
                                            try {
                                              _gpsPos =
                                                  await Geolocator.getCurrentPosition(
                                                    desiredAccuracy:
                                                        LocationAccuracy.medium,
                                                    timeLimit: const Duration(
                                                      seconds: 10,
                                                    ),
                                                  );
                                              _currentPosition = _gpsPos;
                                            } catch (_) {}
                                          }
                                          if (_gpsPos == null) {
                                            showDialog(
                                              context: pageContext,
                                              builder: (_) => AlertDialog(
                                                title: const Text(
                                                  'ไม่สามารถระบุตำแหน่งได้',
                                                ),
                                                content: const Text(
                                                  'กรุณาเปิด GPS และลองใหม่อีกครั้ง\nระบบต้องการตำแหน่งของคุณ',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          pageContext,
                                                        ),
                                                    child: const Text('ตกลง'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            return;
                                          }
                                          final GeoPoint customerLocation =
                                              GeoPoint(
                                                _gpsPos.latitude,
                                                _gpsPos.longitude,
                                              );
                                          final DocumentSnapshot vDoc =
                                              await FirebaseFirestore.instance
                                                  .collection('vendors')
                                                  .doc(vendorId)
                                                  .get();
                                          final Map<String, dynamic> vDocData =
                                              vDoc.exists
                                              ? (vDoc.data()!
                                                    as Map<String, dynamic>)
                                              : {};
                                          final GeoPoint vendorLocation =
                                              vDocData['location']
                                                  as GeoPoint? ??
                                              GeoPoint(0, 0);
                                          final user = FirebaseAuth
                                              .instance
                                              .currentUser!;
                                          final String orderId =
                                              generateOrderId(user.uid);
                                          final orderRef = FirebaseFirestore
                                              .instance
                                              .collection('orders')
                                              .doc(orderId);
                                          final firstItem =
                                              vendorItems.isNotEmpty
                                              ? vendorItems.first
                                              : null;
                                          final double foodTotal = vendorItems
                                              .fold(
                                                0.0,
                                                (acc, item) =>
                                                    acc +
                                                    (item.price +
                                                            (item.extraPrice ??
                                                                0.0)) *
                                                        item.quantity,
                                              );
                                          final double distanceKm =
                                              Geolocator.distanceBetween(
                                                vendorLocation.latitude,
                                                vendorLocation.longitude,
                                                customerLocation.latitude,
                                                customerLocation.longitude,
                                              ) /
                                              1000;
                                          final bool isDeliveryQr =
                                              cartProvider.serviceType ==
                                              'delivery';
                                          final bool isEcommerceQr =
                                              cartProvider.serviceType ==
                                              'ecommerce';
                                          final double customerShipping;
                                          final double riderEarnings;
                                          if (isDeliveryQr) {
                                            if (cartProvider.isMultiVendor) {
                                              customerShipping = cartProvider
                                                  .getCustomerShippingForVendor(
                                                    vendorId,
                                                  );
                                              riderEarnings = cartProvider
                                                  .getRiderEarningsForVendor(
                                                    vendorId,
                                                  );
                                            } else {
                                              customerShipping =
                                                  CartProvider.calcCustomerShipping(
                                                    foodTotal,
                                                    distanceKm: distanceKm,
                                                  );
                                              riderEarnings =
                                                  CartProvider.calcRiderEarnings(
                                                    foodTotal,
                                                    distanceKm,
                                                  );
                                            }
                                          } else if (isEcommerceQr) {
                                            customerShipping = cartProvider
                                                .ecommerceShippingForVendor(
                                                  vendorId,
                                                );
                                            riderEarnings = 0.0;
                                          } else {
                                            customerShipping = 0.0;
                                            riderEarnings = 0.0;
                                          }
                                          final double platformCommission =
                                              isDeliveryQr
                                              ? CartProvider.calcPlatformCommission(
                                                  foodTotal,
                                                )
                                              : 0.0;
                                          final double vendorEarningsQr =
                                              isDeliveryQr
                                              ? CartProvider.calcVendorEarnings(
                                                  foodTotal,
                                                )
                                              : foodTotal;

                                          final Map<String, dynamic>
                                          orderData = {
                                            'orderId': orderId,
                                            'buyerId': user.uid,
                                            'serviceType':
                                                cartProvider.serviceType,
                                            'orderType': isEcommerceQr
                                                ? 'ecommerce'
                                                : (isDeliveryQr
                                                      ? 'delivery'
                                                      : 'pickup'),
                                            'paymentMethod': 'qr',
                                            'totalPrice':
                                                foodTotal + customerShipping,
                                            'shippingCharge': customerShipping,
                                            'shippingFee': isEcommerceQr
                                                ? customerShipping
                                                : 0,
                                            'riderEarnings': riderEarnings,
                                            'isMultiVendor':
                                                cartProvider.isMultiVendor,
                                            'platformCommission':
                                                platformCommission,
                                            'vendorEarnings':
                                                CartProvider.calcVendorEarnings(
                                                  foodTotal,
                                                ),
                                            'items': vendorItems
                                                .map((item) => item.toJson())
                                                .toList(),
                                            'vendorId': vendorId,
                                            'status': 'paid',
                                            'slipStatus': 'awaiting',
                                            'slipChatId': null,
                                            'timestamp':
                                                FieldValue.serverTimestamp(),
                                            'askme': false,
                                            'customerLocation':
                                                customerLocation,
                                            'lastLocationUpdate':
                                                FieldValue.serverTimestamp(),
                                            'multiVendorGroupId':
                                                _multiVendorGroupId,
                                            'vendorInfo': {
                                              'bussinessName':
                                                  vDocData['bussinessName'] ??
                                                  firstItem?.bussinessName ??
                                                  '',
                                              'vaddress':
                                                  vDocData['address'] ?? '',
                                              'vsubdistrict':
                                                  vDocData['subdistrict'] ?? '',
                                              'vdistrict':
                                                  vDocData['district'] ?? '',
                                              'vprovince':
                                                  vDocData['province'] ??
                                                  vDocData['city'] ??
                                                  '',
                                              'vzipcode':
                                                  vDocData['vzipcode'] ?? '',
                                              'vendorPhone':
                                                  vDocData['phone'] ?? '',
                                              'vendorEmail':
                                                  vDocData['email'] ?? '',
                                              'storeImage':
                                                  vDocData['image'] ?? '',
                                              'vendorLocation': vendorLocation,
                                            },
                                            'buyerInfo': {
                                              'fullName':
                                                  userData['fullName'] ??
                                                  user.displayName ??
                                                  '',
                                              'custphone':
                                                  userData['phone'] ?? '',
                                              'custemail':
                                                  userData['email'] ??
                                                  user.email ??
                                                  '',
                                              'address':
                                                  userData['address'] ?? '',
                                              'buyerImage':
                                                  userData['profileImage'] ??
                                                  user.photoURL ??
                                                  '',
                                            },
                                          };
                                          if (cartProvider.isDineIn &&
                                              cartProvider.tableId != null) {
                                            orderData['tableId'] =
                                                cartProvider.tableId;
                                          }
                                          if (isEcommerceQr &&
                                              vendorLocation.latitude != 0 &&
                                              distanceKm > 0) {
                                            orderData['orderDistance'] =
                                                double.parse(
                                                  distanceKm.toStringAsFixed(1),
                                                );
                                          }
                                          if (isEcommerceQr) {
                                            orderData['shippingAddress'] = {
                                              'name': userData['fullName'] ?? '',
                                              'phone': userData['phone'] ?? '',
                                              'address': userData['address'] ?? '',
                                              'city': userData['city'] ?? '',
                                              'state': userData['state'] ?? '',
                                              'country': userData['country'] ?? '',
                                              'zipcode': userData['zipcode'] ?? '',
                                            };
                                          }

                                          EasyLoading.show(
                                            status: 'กำลังบันทึกออร์เดอร์...',
                                          );
                                          final bool ok =
                                              await _setOrderWithRetry(
                                                orderRef,
                                                orderData,
                                              );
                                          EasyLoading.dismiss();
                                          if (!ok) {
                                            setDialogState(
                                              () => _isConfirming = false,
                                            );
                                            return;
                                          }

                                          if (dialogContext.mounted) {
                                            Navigator.of(dialogContext).pop();
                                          }

                                          await Future.delayed(
                                            const Duration(milliseconds: 200),
                                          );

                                          final dynamic slipResult =
                                              await _showSlipUploadDialog(
                                                context: this.context,
                                                orderId: orderId,
                                                vendorTotal: vendorTotal,
                                              );

                                          if (slipResult is String &&
                                              slipResult.startsWith('http')) {
                                            final _t7 = DateTime.now()
                                                .millisecondsSinceEpoch;

                                            cartProvider.clearItemsByVendor(
                                              vendorId,
                                            );
                                            final _t8 = DateTime.now()
                                                .millisecondsSinceEpoch;
                                            final _t9 = DateTime.now()
                                                .millisecondsSinceEpoch;

                                            final _t10 = DateTime.now()
                                                .millisecondsSinceEpoch;

                                            if (cartProvider
                                                .groupedItems
                                                .isEmpty) {
                                              final _t11 = DateTime.now()
                                                  .millisecondsSinceEpoch;

                                              Get.until(
                                                (route) => route.isFirst,
                                              );
                                              final _t12 = DateTime.now()
                                                  .millisecondsSinceEpoch;
                                            } else {
                                              print(
                                                '[SLIP] STEP 11b: multi-vendor next groupedItems=${cartProvider.groupedItems.length}',
                                              );
                                              _handleNextVendorOrHome(
                                                cartProvider,
                                              );
                                            }

                                            unawaited(
                                              _finalizeSlipOrder(
                                                orderRef: orderRef,
                                                slipUrl: slipResult,
                                                vendorId: vendorId,
                                                orderId: orderId,
                                                userData: userData,
                                                userId: user.uid,
                                                firstItem: firstItem,
                                              ),
                                            );
                                          } else if (slipResult == 'skip') {
                                            orderRef.update({
                                              'slipStatus': 'skipped',
                                            });
                                            cartProvider.clearItemsByVendor(
                                              vendorId,
                                            );

                                            _handleNextVendorOrHome(
                                              cartProvider,
                                            );
                                          } else {
                                            orderRef.delete();
                                          }
                                        } catch (e) {
                                          EasyLoading.dismiss();
                                          Fluttertoast.showToast(
                                            msg: 'เกิดข้อผิดพลาด: $e',
                                          );
                                        } finally {
                                          if (dialogContext.mounted) {
                                            setDialogState(
                                              () => _isConfirming = false,
                                            );
                                          }
                                        }
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: mainColor,
                                  foregroundColor: Colors.white,
                                  minimumSize: Size(double.infinity, 50.h),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(7.r),
                                  ),
                                ),
                                child: Text(
                                  'ยืนยัน',
                                  style: styles(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
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
                },
              );
            },
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      );
    } catch (e) {}
  }

  void startLocationStream(DocumentReference orderRef) async {
    await _positionStream?.cancel();

    final LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    try {
      _positionStream =
          Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen((Position position) {
            if (!mounted) {
              _positionStream?.cancel();
              return;
            }
            orderRef.update({
              'customerLocation': GeoPoint(
                position.latitude,
                position.longitude,
              ),
              'lastLocationUpdate': FieldValue.serverTimestamp(),
            });
          }, onError: (e) => print('Location stream error: \$e'));
      Fluttertoast.showToast(msg: 'แชร์ตำแหน่งสดให้ไรเดอร์สำเร็จ!');
    } catch (e) {
      Fluttertoast.showToast(msg: 'ไม่สามารถแชร์ตำแหน่งสดได้');
    }
  }

  String _generatePromptPayPayload({
    required String promptPayId,
    required double amount,
  }) {
    final cleanId = promptPayId.replaceAll(RegExp(r'[^\d]'), '');
    String aid;
    String idFormatted;
    if (cleanId.length == 13) {
      aid = 'A000000677010111';
      idFormatted = '0213$cleanId';
    } else if (cleanId.length == 10) {
      final mobile = '0066${cleanId.substring(1)}';
      aid = 'A000000677010111';
      idFormatted = '0113$mobile';
    } else {
      idFormatted = '0113$cleanId';
      aid = 'A000000677010111';
    }

    String payload =
        '00020101021129${(idFormatted.length + 20).toString().padLeft(2, '0')}0016$aid$idFormatted';
    payload += '5303764';

    final amtStr = amount.toStringAsFixed(2);
    payload += '54${amtStr.length.toString().padLeft(2, '0')}$amtStr';
    payload += '5802TH';
    payload += '6304';

    // คำนวณ CRC16
    final crc = _computeCRC16CCITT(payload);
    return '$payload$crc';
  }

  String generateThaiQRPayload({
    required String bankCode,
    required String accountNumber,
    required double amount,
    required String merchantName,
  }) {
    accountNumber = accountNumber.replaceAll(RegExp(r'[^\d]'), '');
    String payload = '';
    payload += '00020101';
    payload += '0112';
    String aid = 'A000000677010111';
    String fullAccount = bankCode + accountNumber;
    String subTag04 =
        '04${fullAccount.length.toString().padLeft(2, '0')}$fullAccount';
    String promptPayValue =
        '0016${aid.length.toString().padLeft(2, '0')}$aid$subTag04';
    payload +=
        '29${promptPayValue.length.toString().padLeft(2, '0')}$promptPayValue';
    payload += '5303764';
    String amtStr = amount.toStringAsFixed(2).replaceAll('.', '');
    payload += '54${amtStr.length.toString().padLeft(2, '0')}$amtStr';
    payload += '5802TH';
    String name = merchantName.length > 25
        ? merchantName.substring(0, 25)
        : merchantName;
    String nameHex = _utf8HexEncode(name);
    payload += '59${nameHex.length.toString().padLeft(2, '0')}$nameHex';
    String crc = _computeCRC16CCITT(payload);
    payload += '6304$crc';
    return payload;
  }

  String _utf8HexEncode(String text) {
    List<int> utf8Bytes = utf8.encode(text);
    return utf8Bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join();
  }

  String _computeCRC16CCITT(String data) {
    int crc = 0xFFFF;
    const int poly = 0x1021;
    for (int i = 0; i < data.length; i++) {
      int charCode = data.codeUnitAt(i);
      crc ^= (charCode << 8);
      for (int j = 0; j < 8; j++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ poly) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  Future<Map<String, bool>> _runSlipOcr(
    String imagePath,
    double vendorTotal,
  ) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    bool amountMatch = false;
    bool dateMatch = false;
    bool timeMatch = false;
    bool recipientMatch = false;
    bool accountMatch = false;

    try {
      final recognized = await recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );
      final text = recognized.text;
      for (final m in RegExp(r'[\d,]+\.?\d*').allMatches(text)) {
        final val = double.tryParse(m.group(0)!.replaceAll(',', ''));
        if (val != null && (val - vendorTotal).abs() < 1.0) {
          amountMatch = true;
          break;
        }
      }

      final now = DateTime.now();
      final d = now.day;
      final mo = now.month;
      final yAD = now.year;
      final yBE4 = yAD + 543;
      final yBE2 = yBE4 % 100;
      final dp = d.toString().padLeft(2, '0');
      final mp = mo.toString().padLeft(2, '0');
      for (final pattern in [
        '$dp/$mp/$yAD',
        '$dp/$mp/$yBE4',
        '$dp/$mp/${yBE2.toString().padLeft(2, '0')}',
        '$d/$mo/${yBE2.toString().padLeft(2, '0')}',
        '$yAD-$mp-$dp',
      ]) {
        if (text.contains(pattern)) {
          dateMatch = true;
          break;
        }
      }

      final timeRegex = RegExp(r'(\d{1,2}):(\d{2})');
      for (final m in timeRegex.allMatches(text)) {
        final h = int.tryParse(m.group(1)!);
        final min = int.tryParse(m.group(2)!);
        if (h != null && min != null) {
          final slipTime = DateTime(now.year, now.month, now.day, h, min);
          final diff = now.difference(slipTime).inMinutes;
          if (diff >= 0 && diff <= 30) {
            timeMatch = true;
            break;
          }
        }
      }

      final String storeName =
          _currentVendor?.accountName ?? _currentVendor?.bussinessName ?? '';
      if (storeName.isNotEmpty) {
        final lowerText = text.toLowerCase();
        for (final word in storeName.toLowerCase().trim().split(
          RegExp(r'\s+'),
        )) {
          if (word.length >= 3 && lowerText.contains(word)) {
            recipientMatch = true;
            break;
          }
        }
      }

      final String bankAccount =
          _currentVendor?.bankAccount.replaceAll(RegExp(r'[^\d]'), '') ?? '';
      if (bankAccount.length >= 4) {
        final last4 = bankAccount.substring(bankAccount.length - 4);
        if (text.contains(last4)) {
          accountMatch = true;
        }
      } else if (_currentVendor?.promptPayId.isNotEmpty == true) {
        final promptPay = _currentVendor!.promptPayId.replaceAll(
          RegExp(r'[^\d]'),
          '',
        );
        if (promptPay.length >= 4 &&
            text.contains(promptPay.substring(promptPay.length - 4))) {
          accountMatch = true;
        }
      }
    } finally {
      await recognizer.close();
    }

    return {
      'amount': amountMatch,
      'date': dateMatch,
      'time': timeMatch,
      'recipient': recipientMatch,
      'account': accountMatch,
    };
  }

  Future<dynamic> _showSlipUploadDialog({
    required BuildContext context,
    required String orderId,
    required double vendorTotal,
  }) async {
    XFile? selectedFile;
    String? _displayImagePath;
    Uint8List? _compressedSlipBytes;
    bool _isCompressing = false;
    final ImagePicker picker = ImagePicker();

    final result = await showDialog<dynamic>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, StateSetter setDialogState) {
            Future<void> pickImage() async {
              final source = await showModalBottomSheet<ImageSource>(
                context: dialogContext,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(16.r),
                  ),
                ),
                builder: (bsCtx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: 8.h),
                      Container(
                        width: 40.w,
                        height: 4.h,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      ListTile(
                        leading: const Icon(
                          Icons.camera_alt,
                          color: Colors.blue,
                        ),
                        title: Text('ถ่ายรูป', style: styles(fontSize: 15.sp)),
                        onTap: () => Navigator.pop(bsCtx, ImageSource.camera),
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.photo_library,
                          color: Colors.green,
                        ),
                        title: Text(
                          'แกลเลอรี่',
                          style: styles(fontSize: 15.sp),
                        ),
                        onTap: () => Navigator.pop(bsCtx, ImageSource.gallery),
                      ),
                      SizedBox(height: 8.h),
                    ],
                  ),
                ),
              );
              if (source == null) return;
              final file = await picker.pickImage(source: source);
              if (file == null || !dialogContext.mounted) return;
              selectedFile = file;
              _displayImagePath = file.path;
              _compressedSlipBytes = null;
              setDialogState(() => _isCompressing = true);
              try {
                _compressedSlipBytes =
                    await FlutterImageCompress.compressWithFile(
                      file.path,
                      minWidth: 1024,
                      minHeight: 1024,
                      quality: 85,
                      format: CompressFormat.jpeg,
                    );
              } catch (_) {
                _compressedSlipBytes = null;
              }
              if (dialogContext.mounted) {
                setDialogState(() => _isCompressing = false);
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              title: Center(
                child: Text(
                  'อัปโหลดสลิป',
                  style: styles(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'ยอดชำระ: ฿${vendorTotal.toStringAsFixed(2)}',
                        style: styles(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w400,
                          color: Colors.red[700],
                        ),
                      ),
                      SizedBox(height: 16.h),
                      GestureDetector(
                        onTap: pickImage,
                        child: Container(
                          height: 220.h,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            border: Border.all(
                              color: _displayImagePath != null
                                  ? mainColor
                                  : Colors.grey.shade400,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: _isCompressing
                              ? Center(
                                  child: CircularProgressIndicator(
                                    color: mainColor,
                                  ),
                                )
                              : _displayImagePath != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10.r),
                                  child: Image.file(
                                    File(_displayImagePath!),
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_photo_alternate_outlined,
                                      size: 48.sp,
                                      color: Colors.grey.shade400,
                                    ),
                                    SizedBox(height: 8.h),
                                    Text(
                                      'แตะเพื่อเลือกรูปสลิป',
                                      style: styles(
                                        fontSize: 13.sp,
                                        color: Colors.grey.shade500,
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
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: pickImage,
                        child: Text(
                          _displayImagePath != null ? 'แก้ไข' : 'เลืกรูป',
                          style: styles(fontSize: 13.sp),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: selectedFile == null || _isCompressing
                            ? null
                            : () async {
                                final bytes = _compressedSlipBytes;
                                if (bytes == null) return;

                                EasyLoading.show(status: 'กำลังตรวจสอบสลิป...');
                                try {
                                  final ocrResult = await _runSlipOcr(
                                    selectedFile!.path,
                                    vendorTotal,
                                  );
                                  EasyLoading.dismiss();

                                  final int passed = ocrResult.values
                                      .where((v) => v)
                                      .length;

                                  if (passed < 2) {
                                    await showDialog(
                                      context: dialogContext,
                                      builder: (_) => AlertDialog(
                                        title: const Text('สลิปไม่ถูกต้อง'),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'ไม่สามารถยืนยันสลิปได้ กรุณาตรวจสอบ:',
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              '${ocrResult['amount']! ? '✅' : '❌'} จำนวนเงิน: ฿${vendorTotal.toStringAsFixed(2)}',
                                            ),
                                            Text(
                                              '${ocrResult['date']! ? '✅' : '❌'} วันที่: วันนี้',
                                            ),
                                            Text(
                                              '${ocrResult['time']! ? '✅' : '❌'} เวลา: ไม่เกิน 30 นาที',
                                            ),
                                            Text(
                                              '${ocrResult['recipient']! ? '✅' : '❌'} ชื่อผู้รับ',
                                            ),
                                            Text(
                                              '${ocrResult['account']! ? '✅' : '❌'} เลขบัญชี',
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('ลองใหม่'),
                                          ),
                                        ],
                                      ),
                                    );
                                    return;
                                  }

                                  EasyLoading.show(status: 'กำลังอัปโหลด...');
                                  try {
                                    final slipUrl = await _uploadSlipToStorage(
                                      bytes,
                                      orderId,
                                    );
                                    Navigator.pop(dialogContext, slipUrl);
                                  } catch (e) {
                                    Navigator.pop(dialogContext, 'fail');
                                  } finally {
                                    EasyLoading.dismiss();
                                  }
                                } catch (e) {
                                  EasyLoading.dismiss();
                                  Fluttertoast.showToast(
                                    msg: 'ตรวจสอบสลิปไม่สำเร็จ: $e',
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedFile != null
                              ? mainColor
                              : Colors.grey.shade300,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(7.r),
                          ),
                        ),
                        child: Text(
                          'ส่งสลิป',
                          style: styles(
                            fontSize: 13.sp,
                            color: selectedFile != null
                                ? Colors.white
                                : Colors.grey.shade500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
    return result ?? 'skip';
  }

  Future<void> _finalizeSlipOrder({
    required DocumentReference orderRef,
    required String slipUrl,
    required String vendorId,
    required String orderId,
    required Map<String, dynamic> userData,
    required String userId,
    required CartAttr? firstItem,
  }) async {
    final _tf0 = DateTime.now().millisecondsSinceEpoch;

    final chatRef = FirebaseFirestore.instance
        .collection('chats')
        .doc('slip_$orderId');

    Future<void> updateOrder() => orderRef
        .update({
          'slipImage': slipUrl,
          'slipStatus': 'pending',
          'slipChatId': chatRef.id,
          'status': 'paid',
        })
        .timeout(const Duration(seconds: 30));

    bool orderUpdated = false;
    try {
      print(
        '[FINALIZE] currentUser uid=${FirebaseAuth.instance.currentUser?.uid}',
      );
      await updateOrder();
      orderUpdated = true;
      startLocationStream(orderRef);
      print(
        '[FINALIZE] B: order updated +${DateTime.now().millisecondsSinceEpoch - _tf0}ms',
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'บันทึกสลิปไม่สำเร็จ กรุณาติดต่อร้านค้าโดยตรง',
        toastLength: Toast.LENGTH_LONG,
      );
      return;
    }

    if (orderUpdated) {
      final orderSnap = await orderRef.get();
      final orderData =
          orderSnap.data() as Map<String, dynamic>? ?? {};
      final String vendorPhoto =
          (orderData['vendorInfo'] as Map<String, dynamic>?)?['storeImage']
              as String? ??
          '';
      final String proId = firstItem?.proId ?? '';
      final String proName = firstItem?.proName ?? 'ออร์เดอร์รวม';

      unawaited(
        Future(() async {
          try {
            await chatRef.set({
              'proId': proId,
              'proName': proName,
              'buyerName': userData['fullName'] ?? '',
              'buyerPhoto': userData['profileImage'] ?? '',
              'vendorPhoto': vendorPhoto,
              'buyerId': userId,
              'vendorId': vendorId,
              'message': 'สลิปการชำระเงินสำหรับออร์เดอร์ $orderId',
              'messageType': 'slip',
              'imageUrl': slipUrl,
              'senderId': userId,
              'chatDate': FieldValue.serverTimestamp(),
              'orderId': orderId,
              'slipStatus': 'pending',
            });
            await FirebaseFirestore.instance.collection('notifications').add({
              'to': vendorId,
              'type': 'order_paid',
              'orderId': orderId,
              'message': 'ออร์เดอร์ใหม่ชำระแล้ว รอเตรียมสินค้า',
              'timestamp': FieldValue.serverTimestamp(),
              'read': false,
            });
          } catch (e) {}
        }),
      );
    }
  }

  Future<String> _uploadSlipToStorage(
    Uint8List imageBytes,
    String orderId,
  ) async {
    try {
      final String buyerUid = FirebaseAuth.instance.currentUser!.uid;
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String fileName = 'slips/$buyerUid/$timestamp.jpg';
      final Reference ref = FirebaseStorage.instance.ref().child(fileName);
      final UploadTask uploadTask = ref.putData(imageBytes);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      rethrow;
    }
  }

  void _handleNextVendorOrHome(CartProvider cartProvider) {
    if (!mounted || _isNavigating) return;
    final remainingVendors = cartProvider.groupedItems.length;
    if (remainingVendors == 0) {
      _isNavigating = true;
      cartProvider.clearOrderInfo();
      Get.until((route) => route.isFirst);
      return;
    } else {
      final nextVendorId = cartProvider.groupedItems.keys.first;
      if (mounted) {
        setState(() {
          selectedVendorId = nextVendorId;
          _pricesFuture = _calculatePricesForAllVendors(
            cartProvider,
            cartProvider.groupedItems,
          );
        });
        if (cartProvider.isMultiVendor &&
            cartProvider.serviceType == 'delivery' &&
            cartProvider.isShippingCacheEmpty) {
          cartProvider.deliveryShipping;
        }

        _loadVendor(nextVendorId);
      }
    }
  }

  Future<Map<String, double>> _calculatePricesForAllVendors(
    CartProvider cartProvider,
    Map<String, List<CartAttr>> groupedItems,
  ) async {
    Map<String, double> prices = {};
    for (String vendorId in groupedItems.keys) {
      prices[vendorId] = await cartProvider.totalPriceByVendor(vendorId);
    }
    return prices;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        final groupedItems = cartProvider.groupedItems;
        final bool isMultiVendor = cartProvider.isMultiVendor;
        if (groupedItems.isEmpty) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator(color: mainColor)),
          );
        }
        return FutureBuilder<Map<String, dynamic>>(
          future: _userDataFuture,
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(color: Colors.green),
                ),
              );
            }
            if (!userSnapshot.hasData || userSnapshot.hasError) {
              return const Scaffold(
                body: Center(child: Text('ไม่สามารถโหลดข้อมูลผู้ใช้ได้')),
              );
            }
            _userData = userSnapshot.data!;
            return FutureBuilder<Map<String, double>>(
              future: _pricesFuture,
              builder: (context, priceSnapshot) {
                if (priceSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(color: Colors.green),
                    ),
                  );
                }
                if (priceSnapshot.hasError || !priceSnapshot.hasData) {
                  return const Scaffold(
                    body: Center(child: Text('ไม่สามารถคำนวณราคาได้')),
                  );
                }
                final prices = priceSnapshot.data!;
                final double globalTotal = prices.values.fold(
                  0.0,
                  (a, b) => a + b,
                );
                final String currentVendorId =
                    selectedVendorId ?? groupedItems.keys.first;
                Widget itemsListWidget = _buildItemsList(
                  cartProvider,
                  currentVendorId,
                  prices,
                );
                return Scaffold(
                  appBar: AppBar(
                    title: Text(
                      'ชำระเงิน',
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
                      padding: EdgeInsets.only(left: 8.0.w),
                      child: CircleAvatar(
                        backgroundColor: Colors.grey.shade200,
                        radius: 16.r,
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ),
                  ),
                  body: Padding(
                    padding: EdgeInsets.only(bottom: 120.h),
                    child: Column(
                      children: [
                        if (cartProvider.isDineIn &&
                            cartProvider.tableId != null)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              SizedBox(width: 20.w),
                              Icon(
                                Icons.table_restaurant,
                                color: Colors.green.shade700,
                                size: 28.sp,
                              ),
                              SizedBox(width: 12.w),
                              Text(
                                'T: ${cartProvider.tableId}',
                                style: TextStyle(
                                  fontSize: 20.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        Expanded(child: itemsListWidget),
                      ],
                    ),
                  ),
                  bottomNavigationBar: SafeArea(
                    child: _buildPaymentBottomSheet(
                      cartProvider,
                      _userData,
                      isMultiVendor,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildItemsList(
    CartProvider cartProvider,
    String? vendorId,
    Map<String, double> prices,
  ) {
    List<CartAttr> items = vendorId != null
        ? cartProvider.groupedItems[vendorId] ?? []
        : cartProvider.getCartItem.values.toList();
    if (items.isEmpty) return Center(child: Text('ไม่มีสินค้าในร้านนี้'));
    return ListView.builder(
      physics: const ClampingScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final cartData = items[index];
        final double unitPrice = cartData.price + (cartData.extraPrice ?? 0.0);
        final String optionsText = cartData.selectedOptions
            .map((opt) => opt['name'] ?? '')
            .join(', ');
        return Padding(
          padding: EdgeInsets.all(8.r),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Padding(
                  padding: EdgeInsets.only(left: 12.w, right: 8.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        cartData.proName,
                        style: styles(
                          fontSize: 14.sp,
                          color: Colors.black87,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Row(
                        children: [
                          Text(
                            '${cartData.price.toStringAsFixed(1)} x ${cartData.quantity}',
                            style: styles(
                              color: Colors.black54,
                              fontSize: 12.sp,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            (unitPrice * cartData.quantity).toStringAsFixed(1),
                            style: styles(color: Colors.red, fontSize: 12.sp),
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      if (optionsText.isNotEmpty)
                        Text(
                          optionsText,
                          style: styles(fontSize: 12.sp, color: Colors.black45),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentBottomSheet(
    CartProvider cartProvider,
    Map<String, dynamic> userData,
    bool isMultiVendor,
  ) {
    final bool hasPromptPay =
        _currentVendor != null &&
        _currentVendor!.promptPayId.isNotEmpty &&
        _currentVendor!.promptPayId != 'null';
    final bool hasBankAccount =
        _currentVendor != null &&
        _currentVendor!.bankAccount.isNotEmpty &&
        _currentVendor!.bankAccount != 'null' &&
        _currentVendor!.bankName.isNotEmpty;
    final bool hasQrImage =
        _currentVendor != null &&
        _currentVendor!.qrCodeImage != null &&
        _currentVendor!.qrCodeImage!.isNotEmpty;
    final bool hasBank = hasPromptPay || hasBankAccount || hasQrImage;
    final bool showCashButton =
        cartProvider.serviceType == 'pickup' || cartProvider.isDineIn;
    return FutureBuilder<Map<String, double>>(
      future: _pricesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: EdgeInsets.all(10.w),
            child: Center(child: CircularProgressIndicator(color: mainColor)),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Padding(
            padding: EdgeInsets.all(10.w),
            child: Text(
              'ไม่สามารถคำนวณราคาได้',
              style: TextStyle(color: Colors.red),
            ),
          );
        }
        final Map<String, double> prices = snapshot.data!;
        final double globalTotal = prices.values.fold(0.0, (a, b) => a + b);
        final double currentTotal = selectedVendorId != null
            ? prices[selectedVendorId] ?? globalTotal
            : globalTotal;
        final bool isReadyToPay = !isMultiVendor || selectedVendorId != null;
        return Padding(
          padding: EdgeInsets.all(10.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isMultiVendor && selectedVendorId != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '(${cartProvider.groupedItems.length} ร้าน)',
                    style: styles(
                      color: mainColor,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total: ฿${globalTotal.toStringAsFixed(2)}',
                        style: styles(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.red,
                        ),
                      ),
                      if (cartProvider.serviceType == 'ecommerce')
                        Text(
                          'รวมค่าส่ง ฿${cartProvider.ecommerceShippingTotal.toStringAsFixed(0)}',
                          style: styles(fontSize: 11.sp, color: Colors.blue.shade700),
                        ),
                    ],
                  ),
                  Spacer(),
                  if (showCashButton)
                    SizedBox(
                      width: width * .45,
                      height: 50.h,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(7.r),
                          ),
                        ),
                        label: Text(
                          'เงินสด',
                          style: styles(color: Colors.white, fontSize: 14.sp),
                        ),
                        icon: Icon(
                          Icons.add_home,
                          size: 20.w,
                          color: Colors.white,
                        ),
                        onPressed: isProcessing || !isReadyToPay
                            ? null
                            : () => _selectPaymentMethod(
                                'cash',
                                cartProvider,
                                userData,
                              ),
                      ),
                    ),
                ],
              ),
              if (isMultiVendor && selectedVendorId == null)
                Text(
                  'แตะร้านเพื่อเลือกจ่าย',
                  style: styles(fontSize: 12.sp, color: Colors.grey),
                )
              else if (!isReadyToPay)
                Text(
                  'กำลังโหลดข้อมูล...',
                  style: styles(fontSize: 12.sp, color: Colors.grey),
                ),
              SizedBox(height: 4.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: showCashButton ? width * .45 : width * .45,
                    height: 50.h,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7.r),
                        ),
                        backgroundColor: Colors.blue,
                      ),
                      label: Text(
                        'Stripe',
                        style: TextStyle(color: Colors.white, fontSize: 14.sp),
                      ),
                      icon: Icon(
                        Icons.credit_card,
                        size: 20.w,
                        color: Colors.white,
                      ),
                      onPressed: isProcessing || !isReadyToPay ? null : () {},
                      //  => _selectPaymentMethod(
                      //     'stripe',
                      //     cartProvider,
                      //     userData,
                      //   ),
                    ),
                  ),
                  SizedBox(
                    height: 50.h,
                    width: showCashButton ? width * .45 : width * .45,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7.r),
                        ),
                        backgroundColor: hasBank ? mainColor : Colors.grey,
                      ),
                      label: Text(
                        'QR Code',
                        style: TextStyle(color: Colors.white, fontSize: 14.sp),
                      ),
                      icon: Icon(
                        Icons.qr_code,
                        size: 20.w,
                        color: Colors.white,
                      ),
                      onPressed: hasBank && !isProcessing && isReadyToPay
                          ? () => _selectPaymentMethod(
                              'qr',
                              cartProvider,
                              userData,
                            )
                          : null,
                    ),
                  ),
                ],
              ),
              if (!hasBank && !isMultiVendor) ...[
                SizedBox(height: 5.h),
                Text(
                  'QR ไม่พร้อมใช้งาน: กรุณาตั้งค่าบัญชีธนาคารหรือ PromptPay ในโปรไฟล์ผู้ขาย',
                  style: TextStyle(fontSize: 10.sp, color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  TextStyle styles({double? fontSize, Color? color, FontWeight? fontWeight}) {
    return TextStyle(
      fontSize: fontSize,
      color: color ?? Colors.black,
      fontWeight: fontWeight,
    );
  }
}
