class CartItem {
  final String proId;
  final String proName;
  final String bussinessName;
  final String city;
  final String state;
  final String country;
  final String vzipcode;
  final String vaddress;
  final String phone;
  final String email;
  final String storeImage;
  final List<String> imageUrls;
  int quantity;
  final int pqty;
  double price;
  final double shippingCharge;
  final String vendorId;
  final String? productSize;
  final DateTime? date;
  final List<Map<String, dynamic>> selectedOptions;
  double? extraPrice;

  CartItem({
    required this.proId,
    required this.proName,
    required this.bussinessName,
    required this.city,
    required this.state,
    required this.country,
    required this.vzipcode,
    required this.vaddress,
    required this.phone,
    required this.email,
    required this.storeImage,
    required this.imageUrls,
    this.quantity = 1,
    required this.pqty,
    required this.price,
    required this.shippingCharge,
    required this.vendorId,
    this.productSize,
    this.date,
    required this.selectedOptions,
    this.extraPrice,
  });

  Map<String, dynamic> toJson() {
    return {
      'proId': proId,
      'proName': proName,
      'bussinessName': bussinessName,
      'city': city,
      'state': state,
      'country': country,
      'vzipcode': vzipcode,
      'vaddress': vaddress,
      'phone': phone,
      'email': email,
      'storeImage': storeImage,
      'imageUrls': imageUrls,
      'quantity': quantity,
      'pqty': pqty,
      'price': price,
      'shippingCharge': shippingCharge,
      'vendorId': vendorId,
      'productSize': productSize,
      'date': date,
      'selectedOptions': selectedOptions,
      'extraPrice': extraPrice ?? 0.0,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      proId: json['proId'] ?? '',
      proName: json['proName'] ?? '',
      bussinessName: json['bussinessName'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      country: json['country'] ?? '',
      vzipcode: json['vzipcode'] ?? '',
      vaddress: json['vaddress'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      storeImage: json['storeImage'] ?? '',
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      quantity: json['quantity'] ?? 1,
      pqty: json['pqty'] ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      shippingCharge: (json['shippingCharge'] as num?)?.toDouble() ?? 0.0,
      vendorId: json['vendorId'] ?? '',
      productSize: json['productSize'],
      date: json['date'],
      selectedOptions: List<Map<String, dynamic>>.from(
        json['selectedOptions'] ?? [],
      ),
      extraPrice: (json['extraPrice'] as num?)?.toDouble(),
    );
  }
}
