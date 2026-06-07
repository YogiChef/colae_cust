import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoritesHelper {
  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  /// toggle favorite — return true ถ้าเพิ่ม, false ถ้าลบ
  static Future<bool> toggleFavorite(String hotelId) async {
    final ref = FirebaseFirestore.instance.collection('buyers').doc(_uid);
    final doc = await ref.get();
    final favorites = List<String>.from(doc.data()?['favoriteHotels'] ?? []);

    if (favorites.contains(hotelId)) {
      await ref.update({
        'favoriteHotels': FieldValue.arrayRemove([hotelId]),
      });
      return false;
    } else {
      await ref.set({
        'favoriteHotels': FieldValue.arrayUnion([hotelId]),
      }, SetOptions(merge: true));
      return true;
    }
  }

  /// stream เช็คว่า hotel นี้ favorite ไหม
  static Stream<bool> isFavoriteStream(String hotelId) {
    return FirebaseFirestore.instance
        .collection('buyers')
        .doc(_uid)
        .snapshots()
        .map((doc) {
      final favorites = List<String>.from(doc.data()?['favoriteHotels'] ?? []);
      return favorites.contains(hotelId);
    });
  }
}
