// ignore_for_file: unnecessary_null_comparison, avoid_print

import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:colae_cut/services/sevice.dart';

class AuthController {
  Future<String> imageToStorage(Uint8List image, String uid) async {
    try {
      Reference ref = storage.ref().child('profilePick').child('$uid.jpg');
      UploadTask uploadTask = ref.putData(image);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload profile image: $e');
    }
  }

  Future<String> coverImageToStorage(Uint8List coverimage, String uid) async {
    try {
      Reference ref = storage.ref().child('coverPick').child('$uid.jpg');
      UploadTask uploadTask = ref.putData(coverimage);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload cover image: $e');
    }
  }

  Future<Uint8List?>? pickProfileImage(ImageSource source) async {
    final imgPicker = ImagePicker();
    XFile? file = await imgPicker.pickImage(source: source);

    if (file != null) {
      return await file.readAsBytes();
    } else {
      Fluttertoast.showToast(msg: 'No Image Selected');
      return null;
    }
  }

  Future<void> signUpUsers(
    String fullName,
    String custemail,
    String password,
    String custphone,
    Uint8List custimage,
    Uint8List custcoverImg,
  ) async {
    try {
      String trimmedEmail = custemail.trim();

      if (fullName.isEmpty ||
          trimmedEmail.isEmpty ||
          password.isEmpty ||
          custphone.isEmpty ||
          custimage.isEmpty ||
          custcoverImg.isEmpty) {
        throw Exception('Please fill all fields');
      }

      UserCredential cred = await auth.createUserWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );

      final uid = cred.user!.uid;

      await Future.delayed(const Duration(seconds: 1));

      String profileImageUrl = await imageToStorage(custimage, uid);

      String coverImageUrl = await coverImageToStorage(custcoverImg, uid);

      Map<String, dynamic> userMap = {
        'buyerId': cred.user!.uid,
        'fullName': fullName,
        'custemail': trimmedEmail,
        'custphone': custphone,
        'profileImage': profileImageUrl,
        'custcoverImage': coverImageUrl,
        'address': '',
      };
      await firestore.collection('buyers').doc(cred.user!.uid).set(userMap);

      Get.snackbar(
        'Success',
        'Account has been created for you',
        backgroundColor: Colors.yellow.shade900,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } on FirebaseAuthException catch (e) {
      String userMessage = 'Sign up failed';
      switch (e.code) {
        case 'email-already-in-use':
          userMessage =
              'Email นี้ถูกใช้แล้ว ลอง Sign In หรือใช้ email อื่น (อาจ link กับ Google/Apple)';
          break;
        case 'weak-password':
          userMessage = 'Password ต้องแข็งแรงกว่านี้ (อย่างน้อย 6 ตัวอักษร)';
          break;
        case 'invalid-email':
          userMessage = 'รูปแบบ email ไม่ถูกต้อง';
          break;
        case 'operation-not-allowed':
          userMessage =
              'Email/Password provider ไม่ได้ enable ใน Firebase Console';
          break;
        default:
          userMessage = e.message ?? 'Authentication error';
      }
      throw Exception(userMessage);
    } catch (e) {
      throw Exception('Failed to sign up: $e');
    }
  }

  Future<void> loginUser(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      Fluttertoast.showToast(msg: 'กรุณากรอกข้อมูลให้ครบถ้วน');
      throw Exception('empty fields');
    }
    try {
      await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      Fluttertoast.showToast(
        msg: 'Code: ${e.code}\n${e.message}',
        toastLength: Toast.LENGTH_LONG,
      );
      rethrow;
    } catch (e) {
      Fluttertoast.showToast(msg: e.toString(), toastLength: Toast.LENGTH_LONG);
      rethrow;
    }
  }
}
