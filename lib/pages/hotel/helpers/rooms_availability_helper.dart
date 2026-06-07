import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class RoomAvailability {
  /// คำนวณห้องว่างของ room นี้ในช่วงวันที่
  static Future<int> getAvailableRooms({
    required String hotelId,
    required String roomId,
    required int totalRooms,
    required DateTime checkIn,
    required DateTime checkOut,
  }) async {
    final snap = await FirebaseFirestore.instance
        .collection('hotel_bookings')
        .where('hotelId', isEqualTo: hotelId)
        .where('roomId', isEqualTo: roomId)
        .where('status', whereIn: ['pending', 'confirmed', 'checked_in'])
        .get();

    int bookedRooms = 0;
    for (final doc in snap.docs) {
      final d = doc.data();
      final bookingCheckIn = (d['checkIn'] as Timestamp).toDate();
      final bookingCheckOut = (d['checkOut'] as Timestamp).toDate();

      // overlap: bookingCheckIn < checkOut && bookingCheckOut > checkIn
      if (bookingCheckIn.isBefore(checkOut) &&
          bookingCheckOut.isAfter(checkIn)) {
        bookedRooms += (d['rooms'] as num?)?.toInt() ?? 1;
      }
    }

    return (totalRooms - bookedRooms).clamp(0, totalRooms);
  }

  /// คำนวณราคารวมจาก basePrice + special_prices ในแต่ละวัน
  static Future<double> calculateTotalPrice({
    required String hotelId,
    required String roomId,
    required double basePrice,
    required DateTime checkIn,
    required DateTime checkOut,
  }) async {
    final specialSnap = await FirebaseFirestore.instance
        .collection('hotels')
        .doc(hotelId)
        .collection('rooms')
        .doc(roomId)
        .collection('special_prices')
        .get();

    final specialMap = <String, double>{};
    for (final doc in specialSnap.docs) {
      specialMap[doc.id] =
          (doc.data()['price'] as num?)?.toDouble() ?? basePrice;
    }

    double total = 0;
    DateTime cursor = DateTime(checkIn.year, checkIn.month, checkIn.day);
    final end = DateTime(checkOut.year, checkOut.month, checkOut.day);

    while (cursor.isBefore(end)) {
      final key = DateFormat('yyyy-MM-dd').format(cursor);
      total += specialMap[key] ?? basePrice;
      cursor = cursor.add(const Duration(days: 1));
    }

    return total;
  }
}
