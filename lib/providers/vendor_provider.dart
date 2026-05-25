// lib/providers/vendor_provider.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vendor_model.dart';

class VendorProvider with ChangeNotifier {
  final Map<String, VendorModel> _cachedVendors = {};

  VendorModel? getVendor(String vendorId) {
    return _cachedVendors[vendorId];
  }

  Future<VendorModel?> loadVendor(String vendorId) async {
    if (_cachedVendors.containsKey(vendorId)) {
      return _cachedVendors[vendorId];
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(vendorId)
          .get();

      if (doc.exists) {
        final vendor = VendorModel.fromJson(doc.data()!);
        _cachedVendors[vendorId] = vendor;
        notifyListeners();

        return vendor;
      }
    } catch (e) {
      debugPrint('Error loading vendor $vendorId: $e');
    }
    return null;
  }

  void clearCache() => _cachedVendors.clear();
}
