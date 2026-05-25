import 'package:cloud_firestore/cloud_firestore.dart'; // à¹ƒà¸«à¸¡à¹ˆ: à¸ªà¸³à¸«à¸£à¸±à¸š GeoPoint

class VendorModel {
  final bool? approved;
  final String vendorId;
  final String bussinessName;
  final String accountName;
  final String city;
  final String country;
  final String address;
  final String zipcode;
  final String email;
  final String image;
  final String phone;
  final String category;
  final String state;
  final String taxStatus;
  final String taxNo;
  final String bankName;
  final String bankAccount;
  final String promptPayId;
  final Map<String, dynamic>? storeHours;
  final String? qrCodeImage;
  final GeoPoint? location;
  final bool temporarilyClosed;

  VendorModel({
    this.approved,
    required this.vendorId,
    required this.bussinessName,
    required this.city,
    required this.country,
    required this.address,
    required this.zipcode,
    required this.email,
    required this.image,
    required this.phone,
    required this.category,
    required this.state,
    required this.taxStatus,
    required this.taxNo,
    required this.bankName,
    required this.bankAccount,
    required this.promptPayId,
    this.storeHours,
    this.qrCodeImage,
    this.location,
    this.temporarilyClosed = false,
    required this.accountName,
  });

  factory VendorModel.fromJson(Map<String, Object?> json) {
    bool? approved;
    if (json['approved'] is bool) {
      approved = json['approved'] as bool;
    } else if (json['approved'] is String) {
      approved = json['approved'].toString().toLowerCase() == 'true';
    } else {
      approved = false;
    }
    return VendorModel(
      approved: approved,
      vendorId: json['vendorId'] as String? ?? '',
      bussinessName: json['bussinessName'] as String? ?? 'Unknown',
      city: (json['city'] as String?)?.isNotEmpty == true
          ? json['city'] as String
          : json['province'] as String? ?? '',
      country: json['country'] as String? ?? '',
      address: json['address'] as String? ?? '',
      zipcode: json['vzipcode'] as String? ?? '',
      email: json['email'] as String? ?? '',
      image: json['image'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      state: json['state'] as String? ?? '',
      category: json['category'] as String? ?? '',
      taxStatus: json['taxStatus'] as String? ?? '',
      taxNo: json['taxNo'] as String? ?? '',
      bankName: json['bankName'] as String? ?? '',
      bankAccount: json['bankAccount'] as String? ?? '',
      promptPayId: json['promptPayId'] as String? ?? '',
      storeHours: json['storeHours'] as Map<String, dynamic>?,
      qrCodeImage: json['qrCodeImage'] as String?,
      location: json['location'] as GeoPoint?,
      temporarilyClosed: json['temporarilyClosed'] as bool? ?? false,
      accountName: json['ownerName'] as String? ?? '',
    );
  }

  Map<String, Object?> toJson() {
    return {
      'approved': approved,
      'vendorId': vendorId,
      'bussinessName': bussinessName,
      'city': city,
      'country': country,
      'address': address,
      'vzipcode': zipcode,
      'email': email,
      'image': image,
      'phone': phone,
      'state': state,
      'taxStatus': taxStatus,
      'category': category,
      'taxNo': taxNo,
      'bankName': bankName,
      'bankAccount': bankAccount,
      'promptPayId': promptPayId,
      'storeHours': storeHours,
      'qrCodeImage': qrCodeImage,
      'location': location,
      'temporarilyClosed': temporarilyClosed,
      'ownerName': accountName,
    };
  }
}
