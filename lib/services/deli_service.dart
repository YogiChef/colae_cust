// ignore_for_file: no_leading_underscores_for_local_identifiers, avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:colae_cut/models/vendor_model.dart';

class DeliService {
  static bool isStoreOpenNow(Map<String, dynamic>? storeHours) {
    if (storeHours == null || storeHours.isEmpty) return true;
    final now = DateTime.now();
    final dayKey = _getDayKey(now.weekday);
    final dayHours = storeHours[dayKey];
    if (dayHours == null) return true;

    final closed = dayHours['closed'] as bool? ?? false;
    if (closed == true) return false;

    final openStr = dayHours['open'] as String?;
    final closeStr = dayHours['close'] as String?;

    final String effectiveOpen = openStr ?? '00:00';
    final String effectiveClose = closeStr ?? '23:59';

    try {
      final openParts = effectiveOpen.split(':');
      final closeParts = effectiveClose.split(':');
      final openTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(openParts[0]),
        int.parse(openParts[1]),
      );
      final closeTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(closeParts[0]),
        int.parse(closeParts[1]),
      );
      if (closeTime.isBefore(openTime)) return true;
      return now.isAfter(openTime) && now.isBefore(closeTime);
    } catch (e) {
      return true;
    }
  }

  static String getCurrentDayKey() {
    final now = DateTime.now();
    final weekday = now.weekday;
    const days = [
      'sunday',
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
    ];
    final int index = (weekday == 7) ? 0 : weekday;
    return days[index];
  }

  static String formatStoreHours(Map<String, dynamic>? storeHours) {
    if (storeHours == null || storeHours.isEmpty) return 'เปิดตลอด 24 ชม.';
    final now = DateTime.now();
    final dayKey = _getDayKey(now.weekday);
    final dayHours = storeHours[dayKey];
    if (dayHours == null) return 'วันนี้เปิดปกติ';

    // แก้: เช็ค closed flag ก่อน
    final closed = dayHours['closed'] as bool? ?? false;
    if (closed == true) return 'ปิดวันนี้';

    final openStr = dayHours['open'] as String?;
    final closeStr = dayHours['close'] as String?;

    if (openStr == null && closeStr == null) {
      return 'วันนี้เปิดปกติ';
    } else if (openStr != null && closeStr == null) {
      return 'วันนี้: เปิด $openStr ';
    } else if (openStr == null && closeStr != null) {
      return 'วันนี้: ปิด $closeStr';
    } else {
      return 'วันนี้: $openStr - $closeStr';
    }
  }

  static String _getDayKey(int weekday) {
    const days = [
      'sunday',
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
    ];
    final int index = (weekday == 7) ? 0 : weekday;
    return days[index];
  }

  static Stream<List<VendorModel>> streamVendorsWithStatus() {
    return FirebaseFirestore.instance.collection('vendors').snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final vendor = VendorModel.fromJson(data);
        return vendor;
      }).toList();
    });
  }
}
