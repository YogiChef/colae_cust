import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:colae_cut/controllers/auth_controller.dart';
import 'package:colae_cut/models/user_model.dart';

FirebaseAuth auth = FirebaseAuth.instance;
FirebaseFirestore firestore = FirebaseFirestore.instance;
FirebaseStorage storage = FirebaseStorage.instance;
AuthController authController = AuthController();
Future<SharedPreferences> sharedPreferences = SharedPreferences.getInstance();
Position? currentPosition;
late GoogleMapController? mapController;
UserModel? userModelCurrentInfo;
User? currentfuser;
String userDropOffAdress = '';
String cloudMessagingServerToken = ''; //Todo

double height = 825.h;
double width = 375.w;

Color mainColor = const Color(0xFF2ec415);
Color textColor = Colors.grey;

TextStyle styles({
  double? letterSpacing,
  double? fontSize,
  double? height,
  FontWeight? fontWeight = FontWeight.w400,
  Color? color = Colors.white,
  TextDecoration? decoration,
}) {
  return GoogleFonts.josefinSans(
    height: height,
    letterSpacing: letterSpacing,
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    decoration: decoration,
  );
}

TextStyle textstyles({
  double? letterSpacing,
  double? fontSize,
  double? height,
  FontWeight? fontWeight = FontWeight.w400,
  Color? color = Colors.black45,
}) {
  return TextStyle(
    height: height,
    letterSpacing: letterSpacing,
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
  );
}

String generateOrderId(String uid) {
  const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  final rand = Random();
  final prefix = List.generate(4, (_) => letters[rand.nextInt(26)]).join();
  final ts = DateTime.now().millisecondsSinceEpoch;
  final tsPart = (ts % 1000000000).toString().padLeft(9, '0');
  return prefix + tsPart;
}

void callVendor(String phone) async {
  final String url = 'tel:$phone';
  if (await canLaunchUrl(Uri.parse(url))) {
    await launchUrl(Uri.parse(url));
  } else {
    throw ('Could not launch phone call');
  }
}
