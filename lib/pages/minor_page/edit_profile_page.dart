// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:colae_cut/services/sevice.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  final _picker = ImagePicker();
  final _nameController = TextEditingController();

  String _profileImageUrl = '';
  File? _newImage;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final doc = await FirebaseFirestore.instance
        .collection('buyers')
        .doc(_uid)
        .get();
    if (mounted && doc.exists) {
      final d = doc.data()!;
      setState(() {
        _nameController.text = d['fullName'] ?? '';
        _profileImageUrl = d['profileImage'] ?? '';
        _loading = false;
      });
    } else if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('ถ่ายรูป'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('เลือกจากแกลลอรี่'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await _picker.pickImage(source: source, imageQuality: 70);
    if (picked != null) setState(() => _newImage = File(picked.path));
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      Fluttertoast.showToast(msg: 'กรุณากรอกชื่อ');
      return;
    }
    setState(() => _saving = true);
    EasyLoading.show(status: 'กำลังบันทึก...');
    try {
      String imageUrl = _profileImageUrl;
      if (_newImage != null) {
        final ref = FirebaseStorage.instance.ref(
          'profilePick/${_uid}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await ref.putFile(_newImage!);
        imageUrl = await ref.getDownloadURL();
      }
      await FirebaseFirestore.instance.collection('buyers').doc(_uid).update({
        'fullName': _nameController.text.trim(),
        'profileImage': imageUrl,
      });
      EasyLoading.showSuccess('บันทึกสำเร็จ');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      EasyLoading.showError('ผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'เปลี่ยนรหัสผ่าน',
          textAlign: TextAlign.center,
          style: styles(
            fontWeight: FontWeight.w600,
            fontSize: 18.sp,
            color: Colors.deepPurple[900],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'รหัสผ่านเดิม',

                labelStyle: styles(
                  color: Colors.black45,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(height: 8.h),
            TextField(
              controller: newController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'รหัสผ่าน',
                labelStyle: styles(
                  color: Colors.black45,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(height: 8.h),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'ยืนยันรหัสผ่าน',
                labelStyle: styles(
                  color: Colors.black45,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: mainColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('ยืนยัน', style: styles(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != true) return;
    if (newController.text != confirmController.text) {
      Fluttertoast.showToast(msg: 'รหัสผ่านใหม่ไม่ตรงกัน');
      return;
    }
    if (newController.text.length < 6) {
      Fluttertoast.showToast(msg: 'รหัสผ่านต้องมีอย่างน้อย 6 ตัว');
      return;
    }

    EasyLoading.show(status: 'กำลังเปลี่ยน...');
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: oldController.text,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newController.text);
      EasyLoading.showSuccess('เปลี่ยนรหัสผ่านสำเร็จ');
    } on FirebaseAuthException catch (e) {
      String msg = 'ผิดพลาด';
      if (e.code == 'wrong-password') {
        msg = 'รหัสผ่านเดิมไม่ถูกต้อง';
      } else if (e.code == 'weak-password')
        msg = 'รหัสผ่านอ่อนเกินไป';
      EasyLoading.showError(msg);
    } catch (e) {
      EasyLoading.showError('ผิดพลาด: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(backgroundColor: mainColor),
        body: Center(child: CircularProgressIndicator(color: mainColor)),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ข้อมูลส่วนตัว',
          style: styles(
            color: Colors.white,
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: mainColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 60.r,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: _newImage != null
                      ? FileImage(_newImage!) as ImageProvider
                      : (_profileImageUrl.isNotEmpty
                            ? NetworkImage(_profileImageUrl)
                            : null),
                  child: (_newImage == null && _profileImageUrl.isEmpty)
                      ? Icon(Icons.person, size: 60.sp, color: Colors.grey)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius: 18.r,
                    backgroundColor: mainColor,
                    child: IconButton(
                      icon: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: _pickImage,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),
            TextField(
              controller: _nameController,
              textAlign: TextAlign.center,
              style: styles(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: Colors.deepPurple[900],
              ),
              decoration: const InputDecoration(border: InputBorder.none),
            ),
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: OutlinedButton.icon(
                icon: Icon(Icons.lock, color: mainColor),
                label: Text(
                  'เปลี่ยนรหัสผ่าน',
                  style: styles(
                    color: Colors.deepPurple[900],
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(),
                ),
                onPressed: _changePassword,
              ),
            ),
            SizedBox(height: 16.h),
            SizedBox(
              width: width * 0.8,
              height: 50.h,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save, color: Colors.white),
                label: Text(
                  'บันทึก',
                  style: styles(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7.r),
                  ),
                  backgroundColor: mainColor,
                ),
                onPressed: _saving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
