// models/cart_attributes.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class CartAttr {
  String proName;
  String proId;
  String bussinessName;
  List<String> imageUrl;
  int quantity;
  int proqty;
  double price;
  double shippingCharge;
  String vendorId;
  String productSize;
  Timestamp scheduleDate;
  List<Map<String, dynamic>> selectedOptions;
  double? extraPrice;

  CartAttr({
    required this.proName,
    required this.proId,
    required this.bussinessName,
    required this.imageUrl,
    required this.quantity,
    required this.proqty,
    required this.price,
    required this.shippingCharge,
    required this.vendorId,
    required this.productSize,
    required this.scheduleDate,
    required this.selectedOptions,
    this.extraPrice,
  });

  void increase() {
    quantity++;
  }

  void decrease() {
    if (quantity > 0) {
      quantity--;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'proName': proName,
      'proId': proId,
      'bussinessName': bussinessName,
      'imageUrl': imageUrl,
      'quantity': quantity,
      'proqty': proqty,
      'price': price,
      'shippingCharge': shippingCharge,
      'vendorId': vendorId,
      'productSize': productSize,
      'scheduleDate': scheduleDate,
      'selectedOptions': selectedOptions,
      'extraPrice': extraPrice ?? 0.0,
    };
  }

  factory CartAttr.fromJson(Map<String, dynamic> json) {
    return CartAttr(
      proName: json['proName'] ?? '',
      proId: json['proId'] ?? '',
      bussinessName: json['bussinessName'] ?? '',
      imageUrl: List<String>.from(json['imageUrl'] ?? []),
      quantity: json['quantity'] ?? 0,
      proqty: json['proqty'] ?? 0,
      price: (json['price'] ?? 0.0).toDouble(),
      shippingCharge: (json['shippingCharge'] ?? 0.0).toDouble(),
      vendorId: json['vendorId'] ?? '',
      productSize: json['productSize'] ?? '',
      scheduleDate: json['scheduleDate'] ?? Timestamp.now(),
      selectedOptions: List<Map<String, dynamic>>.from(
        json['selectedOptions'] ?? [],
      ),
      extraPrice: (json['extraPrice'] ?? 0.0).toDouble(),
    );
  }

  void operator [](String other) {}
}
