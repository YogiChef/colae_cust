// ignore_for_file: deprecated_member_use, unused_element, avoid_print, avoid_types_as_parameter_names

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:colae_cut/models/cart_attributes.dart';
import 'package:colae_cut/models/delivery_config_model.dart';
import 'package:colae_cut/models/vendor_model.dart';
import 'package:colae_cut/services/deli_service.dart';
import 'package:colae_cut/services/sevice.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class CartProvider with ChangeNotifier {
  final Map<String, CartAttr> _cartItems = {};
  String _serviceType = 'pickup';
  String? _tableId;

  DeliveryConfig _deliveryConfig = const DeliveryConfig();
  String _currentArea = '';

  final Map<String, Map<String, dynamic>> _vendorCache = {};

  final Map<String, double> _shippingCache = {};
  final Map<String, double> _riderShippingCache = {};
  Position? _cachedPosition;

  Map<String, CartAttr> get getCartItem {
    return _cartItems;
  }

  String get serviceType => _serviceType;
  String? get tableId => _tableId;
  bool get isDineIn => _serviceType == 'dine-in';
  double getCustomerShippingForVendor(String vendorId) {
    return _shippingCache[vendorId] ?? 0.0;
  }

  double getRiderEarningsForVendor(String vendorId) {
    return _riderShippingCache[vendorId] ?? 0.0;
  }

  bool get isShippingCacheEmpty => _shippingCache.isEmpty;

  void setServiceType(String type) {
    if (type == 'delivery' ||
        type == 'pickup' ||
        type == 'dine-in' ||
        type == 'ecommerce') {
      if (_serviceType != type) {
        _serviceType = type;
        if (type != 'dine-in') {
          _tableId = null;
        }
        notifyListeners();
      }
    }
  }

  /// คำนวณค่าส่ง ecommerce จาก shippingTiers ของ item หนึ่งชิ้น
  double _calcItemEcommerceShipping(CartAttr item) {
    final tiers = item.shippingTiers;
    final qty = item.quantity;
    if (tiers.isEmpty) return 0;
    double fee = 0;
    bool found = false;
    for (final tier in tiers) {
      final t = Map<String, dynamic>.from(tier as Map);
      final from = (t['qtyFrom'] as num?)?.toInt() ?? 1;
      final to = (t['qtyTo'] as num?)?.toInt() ?? 9999;
      if (qty >= from && qty <= to) {
        fee = (t['fee'] as num?)?.toDouble() ?? 0;
        found = true;
        break;
      }
    }
    if (!found) {
      final lastTier = Map<String, dynamic>.from(tiers.last as Map);
      final lastTo = (lastTier['qtyTo'] as num?)?.toInt() ?? 9999;
      final lastFee = (lastTier['fee'] as num?)?.toDouble() ?? 0;
      final extraUnits = qty - lastTo;
      fee =
          lastFee +
          item.shippingExtraBase +
          (extraUnits * item.shippingExtraPerUnit);
    }
    return fee;
  }

  double get ecommerceShippingTotal {
    if (_serviceType != 'ecommerce') return 0;
    return _cartItems.values.fold(
      0.0,
      (sum, item) => sum + _calcItemEcommerceShipping(item),
    );
  }

  double ecommerceShippingForVendor(String vendorId) {
    if (_serviceType != 'ecommerce') return 0;
    return _cartItems.values
        .where((item) => item.vendorId == vendorId)
        .fold(0.0, (sum, item) => sum + _calcItemEcommerceShipping(item));
  }

  void setTableId(String tableId) {
    _tableId = tableId.trim().toUpperCase();
    _serviceType = 'dine-in';
    notifyListeners();
  }

  void clearOrderInfo() {
    _serviceType = 'pickup';
    _tableId = null;
    notifyListeners();
  }

  Future<void> loadDeliveryConfig(String area) async {
    const Map<String, String> areaMap = {
      'กรุงเทพ': 'bangkok',
      'กรุงเทพมหานคร': 'bangkok',
      'ภูเก็ต': 'phuket',
      'ขอนแก่น': 'khonkaen',
      'พัทยา': 'pattaya',
      'เชียงใหม่': 'chiangmai',
      'หาดใหญ่': 'hatyai',
      'นครราชสีมา': 'korat',
      'อุดรธานี': 'udonthani',
      'เชียงราย': 'chiangrai',
    };

    final key = areaMap[area.trim()] ?? 'default';
    if (_currentArea == key) return;
    try {
      var doc = await FirebaseFirestore.instance
          .collection('delivery_config')
          .doc(key)
          .get();
      if (!doc.exists) {
        doc = await FirebaseFirestore.instance
            .collection('delivery_config')
            .doc('default')
            .get();
      }
      if (doc.exists) {
        _deliveryConfig = DeliveryConfig.fromMap(doc.data()!);
        _currentArea = key;
        _shippingCache.clear();
        _riderShippingCache.clear();
      }
    } catch (e) {
      print('[Config] error: $e — using default');
    }
  }

  DeliveryConfig get deliveryConfig => _deliveryConfig;

  Future<void> preloadVendor(String vendorId) async {
    if (vendorId.isEmpty || _vendorCache.containsKey(vendorId)) return;
    await _getVendorData(vendorId);
  }

  Future<Map<String, dynamic>?> _getVendorData(String vendorId) async {
    if (_vendorCache.containsKey(vendorId)) return _vendorCache[vendorId];
    try {
      final doc = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(vendorId)
          .get();
      if (doc.exists) {
        _vendorCache[vendorId] = doc.data()!;
        return _vendorCache[vendorId];
      }
    } catch (_) {}
    return null;
  }

  Future<Position?> _getPosition() async {
    if (_cachedPosition != null) return _cachedPosition;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          return null;
        }
      }
      _cachedPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return _cachedPosition;
    } catch (_) {
      return null;
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

  String getCompositeKey(CartAttr item) {
    return _getCompositeKey(item.proId, item.selectedOptions);
  }

  Map<String, List<CartAttr>> get groupedItems {
    final Map<String, List<CartAttr>> grouped = {};
    for (final cartAttr in _cartItems.values) {
      final vendorId = cartAttr.vendorId;
      grouped.putIfAbsent(vendorId, () => []).add(cartAttr);
    }
    return grouped;
  }

  bool get isMultiVendor {
    if (groupedItems.isEmpty) return false;
    return groupedItems.length > 1;
  }

  double calculateExtraPrice(List<Map<String, dynamic>> options) {
    return options.fold(
      0.0,
      (acc, opt) => acc + (opt['price'] as num? ?? 0).toDouble(),
    );
  }

  double subTotalByVendor(String vendorId) {
    var total = 0.0;
    final vendorItems = groupedItems[vendorId] ?? [];
    for (final item in vendorItems) {
      final extra =
          item.extraPrice ?? calculateExtraPrice(item.selectedOptions);
      total += (item.price + extra) * item.quantity;
    }
    return total;
  }

  Future<double> customerShippingByVendor(String vendorId) =>
      deliveryShippingByVendor(vendorId);

  Future<double> riderShippingByVendor(String vendorId) async {
    if (_riderShippingCache.containsKey(vendorId)) {
      return _riderShippingCache[vendorId]!;
    }
    final vendorItems = groupedItems[vendorId] ?? [];
    if (vendorItems.isEmpty) return 0.0;

    final double foodTotal = vendorItems.fold(
      0.0,
      (acc, item) =>
          acc + (item.price + (item.extraPrice ?? 0.0)) * item.quantity,
    );
    double distanceKm = 0.0;
    try {
      final vendorData = await _getVendorData(vendorId);
      if (vendorData != null && vendorData['location'] != null) {
        final GeoPoint vendorLocation = vendorData['location'] as GeoPoint;
        final buyerPosition = await _getPosition();
        if (buyerPosition != null) {
          distanceKm =
              Geolocator.distanceBetween(
                vendorLocation.latitude,
                vendorLocation.longitude,
                buyerPosition.latitude,
                buyerPosition.longitude,
              ) /
              1000;
        }
      }
    } catch (_) {}
    _riderShippingCache[vendorId] = _roundToNearestBaht(
      calcRiderEarnings(foodTotal, distanceKm, config: _deliveryConfig),
    );
    return _riderShippingCache[vendorId]!;
  }

  Future<double> deliveryShippingByVendor(String vendorId) async {
    if (_shippingCache.containsKey(vendorId)) {
      return _shippingCache[vendorId]!;
    }

    final vendorItems = groupedItems[vendorId] ?? [];
    if (vendorItems.isEmpty) {
      return 0.0;
    }

    final double foodTotal = vendorItems.fold(
      0.0,
      (acc, item) =>
          acc + (item.price + (item.extraPrice ?? 0.0)) * item.quantity,
    );
    double distanceKm = 0.0;
    try {
      final vendorData = await _getVendorData(vendorId);
      if (vendorData != null && vendorData['location'] != null) {
        final GeoPoint vendorLocation = vendorData['location'] as GeoPoint;

        final buyerPosition = await _getPosition();
        if (buyerPosition != null) {
          distanceKm =
              Geolocator.distanceBetween(
                vendorLocation.latitude,
                vendorLocation.longitude,
                buyerPosition.latitude,
                buyerPosition.longitude,
              ) /
              1000;
        }
      }
    } catch (_) {}

    final double customerShip = calcCustomerShipping(
      foodTotal,
      distanceKm: distanceKm,
      config: _deliveryConfig,
    );
    final double riderEarnings = calcRiderEarnings(
      foodTotal,
      distanceKm,
      config: _deliveryConfig,
    );
    _shippingCache[vendorId] = _roundToNearestBaht(customerShip);
    _riderShippingCache[vendorId] = _roundToNearestBaht(riderEarnings);

    return _shippingCache[vendorId]!;
  }

  double _roundToNearestBaht(double amount) {
    return amount.roundToDouble();
  }

  static double calcSubsidy(
    double foodTotal, {
    DeliveryConfig config = const DeliveryConfig(),
  }) => foodTotal * config.subsidyRate;

  static double calcCustomerShipping(
    double foodTotal, {
    double distanceKm = 0.0,
    DeliveryConfig config = const DeliveryConfig(),
  }) {
    final subsidy = calcSubsidy(foodTotal, config: config);
    final distanceExtra = distanceKm > config.freeDistanceKm
        ? (distanceKm - config.freeDistanceKm) * config.distanceRate
        : 0.0;
    final baseCharge = (config.baseDeliveryFee - subsidy).clamp(
      0.0,
      config.baseDeliveryFee,
    );
    return baseCharge + distanceExtra;
  }

  static double calcRiderEarnings(
    double foodTotal,
    double distanceKm, {
    DeliveryConfig config = const DeliveryConfig(),
  }) {
    final subsidy = calcSubsidy(foodTotal, config: config);
    final distanceExtra = distanceKm > config.freeDistanceKm
        ? (distanceKm - config.freeDistanceKm) * config.distanceRate
        : 0.0;
    final riderBase = subsidy.clamp(
      config.baseDeliveryFee,
      config.maxSubsidyCap,
    );
    return riderBase + distanceExtra;
  }

  static double calcPlatformCommission(
    double foodTotal, {
    DeliveryConfig config = const DeliveryConfig(),
  }) {
    final subsidy = calcSubsidy(foodTotal, config: config);
    return (subsidy - config.maxSubsidyCap).clamp(0.0, double.infinity);
  }

  static double calcVendorEarnings(
    double foodTotal, {
    DeliveryConfig config = const DeliveryConfig(),
  }) {
    return foodTotal - calcSubsidy(foodTotal, config: config);
  }

  static Map<String, double> calcMultiVendorShipping({
    required double totalFoodAmount,
    required double totalInterVendorDistance,
    required double distanceToCustomer,
    DeliveryConfig config = const DeliveryConfig(),
  }) {
    final double subsidy = calcSubsidy(totalFoodAmount, config: config);
    final double baseCharge = (config.multiVendorBaseDeliveryFee - subsidy)
        .clamp(0.0, config.multiVendorBaseDeliveryFee);
    final double overSubsidy = (subsidy - config.multiVendorBaseDeliveryFee)
        .clamp(0.0, double.infinity);
    final double rawDistanceCharge =
        totalInterVendorDistance * config.distanceRate;
    final double netDistanceCharge = (rawDistanceCharge - overSubsidy).clamp(
      0.0,
      double.infinity,
    );
    final double extraToCustomer = distanceToCustomer > config.freeDistanceKm
        ? (distanceToCustomer - config.freeDistanceKm) * config.distanceRate
        : 0.0;
    final double customerShipping =
        baseCharge + netDistanceCharge + extraToCustomer;
    final double riderEarnings =
        subsidy.clamp(config.multiVendorBaseDeliveryFee, config.maxSubsidyCap) +
        netDistanceCharge +
        extraToCustomer;
    return {
      'customerShipping': customerShipping,
      'riderEarnings': riderEarnings,
    };
  }

  Future<double> _calcMultiVendorDeliveryShipping() async {
    final vendorIds = groupedItems.keys.toList();

    double totalFoodAmount = 0.0;
    for (final vId in vendorIds) {
      totalFoodAmount += subTotalByVendor(vId);
    }

    final List<GeoPoint?> vendorLocations = [];
    for (final vId in vendorIds) {
      final data = await _getVendorData(vId);
      vendorLocations.add(data?['location'] as GeoPoint?);
    }

    double totalInterVendorDistance = 0.0;
    for (int i = 0; i < vendorLocations.length - 1; i++) {
      final a = vendorLocations[i];
      final b = vendorLocations[i + 1];
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

    double distanceToCustomer = 0.0;
    final lastVendorGeo = vendorLocations.lastWhere(
      (g) => g != null,
      orElse: () => null,
    );
    if (lastVendorGeo != null) {
      final buyerPos = await _getPosition();
      if (buyerPos != null) {
        distanceToCustomer =
            Geolocator.distanceBetween(
              lastVendorGeo.latitude,
              lastVendorGeo.longitude,
              buyerPos.latitude,
              buyerPos.longitude,
            ) /
            1000;
      }
    }

    final result = calcMultiVendorShipping(
      totalFoodAmount: totalFoodAmount,
      totalInterVendorDistance: totalInterVendorDistance,
      distanceToCustomer: distanceToCustomer,
      config: _deliveryConfig,
    );

    for (final vId in vendorIds) {
      final vendorRatio = subTotalByVendor(vId) / totalFoodAmount;
      _shippingCache[vId] = _roundToNearestBaht(
        result['customerShipping']! * vendorRatio,
      );
      _riderShippingCache[vId] = _roundToNearestBaht(
        result['riderEarnings']! * vendorRatio,
      );
    }

    return _roundToNearestBaht(result['customerShipping']!);
  }

  Future<double> totalPriceByVendor(String vendorId) async {
    final subtotal = subTotalByVendor(vendorId);
    if (_serviceType == 'delivery') {
      if (isMultiVendor && _shippingCache.containsKey(vendorId)) {
        return subtotal + _shippingCache[vendorId]!;
      }
      final shipping = await deliveryShippingByVendor(vendorId);
      return subtotal + shipping;
    } else if (_serviceType == 'ecommerce') {
      return subtotal + ecommerceShippingForVendor(vendorId);
    } else {
      return subtotal;
    }
  }

  Future<double> get deliveryShipping async {
    if (groupedItems.isEmpty) return 0.0;

    if (!isMultiVendor) {
      final vendorId = groupedItems.keys.first;
      return await deliveryShippingByVendor(vendorId);
    }

    return await _calcMultiVendorDeliveryShipping();
  }

  double get subTotal {
    if (groupedItems.isEmpty) return 0.0;
    if (!isMultiVendor) {
      return subTotalByVendor(groupedItems.keys.first);
    }
    double total = 0.0;
    groupedItems.forEach((vendorId, group) {
      total += subTotalByVendor(vendorId);
    });
    return total;
  }

  Future<double> get totalPrice async {
    if (groupedItems.isEmpty) return 0.0;
    double total = 0.0;
    for (String vendorId in groupedItems.keys) {
      total += await totalPriceByVendor(vendorId);
    }
    return total;
  }

  int get totalQuantity {
    return _cartItems.values.fold(0, (acc, item) => acc + item.quantity);
  }

  Future<void> addProductToCart(
    String proName,
    String proId,
    String bussinessName,
    List<String> imageUrl,
    int quantity,
    int proqty,
    double price,
    double shippingCharge,
    String vendorId,
    String productSize,
    dynamic date,
    List<Map<String, dynamic>> selectedOptions, {
    List<dynamic> shippingTiers = const [],
    double shippingExtraBase = 0.0,
    double shippingExtraPerUnit = 0.0,
  }) async {
    final vendorData = await _getVendorData(vendorId);
    if (vendorData == null) throw Exception('Vendor not found: $vendorId');
    if (_serviceType != 'ecommerce') {
      final vendor = VendorModel.fromJson(vendorData);
      final isOpen = DeliService.isStoreOpenNow(vendor.storeHours);
      if (!isOpen) throw Exception('ร้านปิดชั่วคราว – ไม่สามารถเพิ่มสินค้าได้');
      await loadDeliveryConfig(vendor.city);
    }

    final extraPrice = calculateExtraPrice(selectedOptions);
    final String key = _getCompositeKey(proId, selectedOptions);

    if (_cartItems.containsKey(key)) {
      _cartItems[key]!.quantity += quantity;
    } else {
      _cartItems.putIfAbsent(
        key,
        () => CartAttr(
          proName: proName,
          proId: proId,
          bussinessName: bussinessName,
          imageUrl: imageUrl,
          quantity: quantity,
          proqty: proqty,
          price: price,
          shippingCharge: 0.0,
          vendorId: vendorId,
          productSize: productSize,
          scheduleDate: date,
          selectedOptions: selectedOptions,
          extraPrice: extraPrice,
          shippingTiers: shippingTiers,
          shippingExtraBase: shippingExtraBase,
          shippingExtraPerUnit: shippingExtraPerUnit,
        ),
      );
    }

    notifyListeners();
  }

  void increaseQuantity(String key) {
    if (_cartItems.containsKey(key)) {
      _cartItems[key]!.increase();
      _shippingCache.clear();
      _riderShippingCache.clear();
      notifyListeners();
    }
  }

  void decreaseQuantity(String key) {
    if (_cartItems.containsKey(key)) {
      final item = _cartItems[key]!;
      if (item.quantity > 1) {
        item.decrease();
        _shippingCache.clear();
        _riderShippingCache.clear();
      } else {
        removeItem(key);
      }
      notifyListeners();
    }
  }

  void updateQuantity(String key, int newQty) {
    if (_cartItems.containsKey(key) && newQty > 0) {
      _cartItems[key]!.quantity = newQty;
      _shippingCache.clear();
      _riderShippingCache.clear();
      notifyListeners();
    }
  }

  void removeItem(String key) {
    _cartItems.remove(key);
    _shippingCache.clear();
    _riderShippingCache.clear();
    notifyListeners();
  }

  void removeAllItem() {
    _cartItems.clear();
    _shippingCache.clear();
    _riderShippingCache.clear();
    _cachedPosition = null;
    clearOrderInfo();
    notifyListeners();
  }

  void clearItemsByVendor(String vendorId) {
    final itemsToRemove = <String>{};

    groupedItems[vendorId]?.forEach((item) {
      itemsToRemove.add(getCompositeKey(item));
    });
    for (String key in itemsToRemove) {
      _cartItems.remove(key);
    }

    _shippingCache.remove(vendorId);
    _riderShippingCache.remove(vendorId);
    notifyListeners();
  }

  Future<List<String>> createSplitOrders(
    Map<String, dynamic> userData,
    String paymentMethod,
  ) async {
    if (groupedItems.isEmpty) return [];
    final bool multiVendor = isMultiVendor;
    if (multiVendor) {
      await _calcMultiVendorDeliveryShipping();
    }
    List<String> orderIds = [];
    for (String vendorId in groupedItems.keys) {
      final vendorItems = groupedItems[vendorId]!;
      final double subtotal = subTotalByVendor(vendorId);
      final double customerShipping = _serviceType == 'delivery'
          ? (_shippingCache[vendorId] ?? 0.0)
          : 0.0;
      final double riderEarning = _serviceType == 'delivery'
          ? (_riderShippingCache[vendorId] ?? 0.0)
          : 0.0;
      final double totalPrice = subtotal + customerShipping;
      final String orderId = generateOrderId(
        FirebaseAuth.instance.currentUser!.uid,
      );
      final orderRef = FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId);
      final vendorData = await _getVendorData(vendorId) ?? {};
      Map<String, dynamic> orderData = {
        'buyerId': FirebaseAuth.instance.currentUser!.uid,
        'vendorId': vendorId,
        'serviceType': _serviceType,
        'paymentMethod': paymentMethod,
        'totalPrice': totalPrice,
        'shippingCharge': customerShipping,
        'riderEarnings': riderEarning,
        'isMultiVendor': multiVendor,
        'items': vendorItems.map((item) => item.toJson()).toList(),
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'vendorInfo': {
          'bussinessName': vendorData['bussinessName'] ?? '',
          'vaddress': vendorData['address'] ?? '',
          'vsubdistrict': vendorData['subdistrict'] ?? '',
          'vdistrict': vendorData['district'] ?? '',
          'vprovince': vendorData['province'] ?? vendorData['city'] ?? '',
          'vzipcode': vendorData['vzipcode'] ?? '',
          'vendorPhone': vendorData['phone'] ?? '',
          'vendorEmail': vendorData['email'] ?? '',
          'storeImage': vendorData['image'] ?? '',
          'vendorLocation': vendorData['location'] ?? const GeoPoint(0, 0),
        },
        'buyerInfo': {
          'fullName': userData['fullName'] ?? '',
          'custphone': userData['phone'] ?? '',
          'custemail': userData['email'] ?? '',
          'address': userData['address'] ?? '',
          'buyerImage': userData['profileImage'] ?? '',
        },
      };
      if (paymentMethod == 'qr') {
        final vendorDoc = await FirebaseFirestore.instance
            .collection('vendors')
            .doc(vendorId)
            .get();
        if (vendorDoc.exists) {
          final vendorDocData = vendorDoc.data()!;
          orderData['paymentDetails'] = {
            'bankName': vendorDocData['bankName'] ?? '',
            'bankAccount': vendorDocData['bankAccount'] ?? '',
          };
        }
      }

      await orderRef.set(orderData);
      orderIds.add(orderId);
    }
    return orderIds;
  }

  Future<GeoPoint?> _findNearestRider(GeoPoint vendorLocation) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('riders')
          .where('status', isEqualTo: 'online')
          .limit(5)
          .get();

      if (snapshot.docs.isEmpty) return null;

      GeoPoint? nearest;
      double minDistance = double.infinity;

      for (var doc in snapshot.docs) {
        final geo = doc['location'] as GeoPoint?;
        if (geo != null) {
          double distance = Geolocator.distanceBetween(
            vendorLocation.latitude,
            vendorLocation.longitude,
            geo.latitude,
            geo.longitude,
          );
          if (distance < minDistance) {
            minDistance = distance;
            nearest = geo;
          }
        }
      }
      return nearest;
    } catch (e) {
      return null;
    }
  }

  Future<bool> reserveStockForVendor(
    String vendorId, {
    String? proId,
    int? qty,
  }) async {
    return true;
  }

  Future<bool> updateStock(String proId, int quantity, String action) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final productRef = FirebaseFirestore.instance
            .collection('products')
            .doc(proId);
        final snapshot = await transaction.get(productRef);
        if (!snapshot.exists) throw Exception('Product not found');
        final data = snapshot.data() as Map<String, dynamic>;
        int currentQty = (data['pqty'] as num?)?.toInt() ?? 0;
        int newQty;
        if (action == 'deduct') {
          if (currentQty < quantity) {
            throw Exception('Stock insufficient: $currentQty < $quantity');
          }
          newQty = currentQty - quantity;
        } else if (action == 'add') {
          newQty = currentQty + quantity;
        } else {
          throw Exception('Invalid action: $action');
        }
        transaction.update(productRef, {'pqty': newQty});
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deductStockForVendor(String vendorId) async {
    try {
      final vendorItems = groupedItems[vendorId] ?? [];
      if (vendorItems.isEmpty) return true;
      return true;
    } catch (e) {
      return false;
    }
  }
}
