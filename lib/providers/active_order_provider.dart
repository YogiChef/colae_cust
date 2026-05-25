// ignore_for_file: unnecessary_cast

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ActiveOrderProvider extends ChangeNotifier {
  bool hasActiveDeliveryOrder = false;
  String? activeOrderId;
  String? riderId;
  String? riderName = 'ไรเดอร์';
  StreamSubscription<QuerySnapshot>? _subscription;

  void startListening(String? buyerId) {
    if (buyerId == null) return;
    _subscription?.cancel();
    hasActiveDeliveryOrder = false;
    activeOrderId = null;
    riderId = null;
    riderName = 'ไรเดอร์';

    final stream = FirebaseFirestore.instance
        .collection('orders')
        .where('buyerId', isEqualTo: buyerId)
        .where('serviceType', isEqualTo: 'delivery')
        .where('status', whereIn: [
      'pending_rider',
      'rider_accepted',
      'picked_up',
    ]).snapshots();

    _subscription = stream.listen((snapshot) {
      bool newHasActive = false;
      String? newOrderId;
      String? newRId;
      String? newRName = 'ไรเดอร์';

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data() as Map<String, dynamic>;
        final rId = data['riderId']?.toString();
        if (rId != null && rId.isNotEmpty) {
          newHasActive = true;
          newOrderId = snapshot.docs.first.id;
          newRId = rId;
          newRName = data['riderName']?.toString() ?? 'ไรเดอร์';
        }
      }

      if (newHasActive != hasActiveDeliveryOrder ||
          newOrderId != activeOrderId ||
          newRId != riderId ||
          newRName != riderName) {
        hasActiveDeliveryOrder = newHasActive;
        activeOrderId = newOrderId;
        riderId = newRId;
        riderName = newRName;
        notifyListeners();
      }
    }, onError: (error) {
      debugPrint('ActiveOrderProvider error: $error');
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
