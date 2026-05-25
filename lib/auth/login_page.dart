// ignore_for_file: use_build_context_synchronously
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:colae_cut/services/sevice.dart';
import 'package:colae_cut/pages/map_page.dart';
import 'package:colae_cut/widgets/botton_widget.dart';
import 'package:colae_cut/widgets/input_textfield.dart';

class LoginPage extends StatefulWidget {
  final String? userId;
  final String? email;
  final String? token;

  const LoginPage({
    super.key,
    this.userId,
    this.email,
    this.token,
    String? ref,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  CollectionReference buyers = firestore.collection('buyers');
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String email = '';
  String password = '';
  bool _obscureText = true;
  bool _isLoading = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> login() async {
    if (_formKey.currentState!.validate()) {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        FocusScope.of(context).requestFocus(FocusNode());
      });
      try {
        await authController.loginUser(email, password);
        await auth.currentUser!.reload();
        _formKey.currentState!.reset();

        final user = auth.currentUser;
        if (user == null) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          return;
        }

        final buyerDoc = await firestore
            .collection('buyers')
            .doc(user.uid)
            .get();
        if (!buyerDoc.exists) {
          await auth.signOut();
          if (!mounted) return;
          setState(() => _isLoading = false);
          Fluttertoast.showToast(
            msg: 'ไม่พบบัญชีผู้ใช้ กรุณาตรวจสอบอีเมล',
            toastLength: Toast.LENGTH_LONG,
          );
          return;
        }

        final SharedPreferences prf = await _prefs;
        prf.setString('cid', user.uid);

        await Future.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;
        Get.to(const MapPage());
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        Fluttertoast.showToast(
          msg: 'code: ${e.code} | msg: ${e.message}',
          toastLength: Toast.LENGTH_LONG,
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        Fluttertoast.showToast(
          msg: e.toString(),
          toastLength: Toast.LENGTH_LONG,
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.email != null) {
      email = widget.email!;
      _emailController.text = widget.email!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleQrParams();
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleQrParams() {
    if (widget.email != null || widget.token != null) {
      Get.dialog(
        AlertDialog(
          title: const Text('ลงทะเบียนจาก QR Code'),
          content: Text(
            'พบข้อมูล: ${widget.email ?? 'ไม่มี'} \nต้องการลงทะเบียนเลยไหม?',
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('ยกเลิก'),
            ),
            TextButton(
              onPressed: () {
                Get.back();
                Get.toNamed(
                  '/signup',
                  arguments: {
                    'userId': widget.userId,
                    'email': widget.email,
                    'token': widget.token,
                  },
                );
              },
              child: const Text('ลงทะเบียน'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mainColor,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Container(
                  height: 300.h,
                  width: 380.w,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('images/colae2.png'),
                      fit: BoxFit.fitWidth,
                    ),
                  ),
                ),

                Container(
                  margin: EdgeInsets.only(top: 260.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24.r),
                      topRight: Radius.circular(24.r),
                    ),
                    border: Border.all(color: Colors.grey.shade200, width: 0.5),
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20.w, 32.h, 20.w, 220.h),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.bottomLeft,
                          child: TextButton(
                            onPressed: () {
                              Get.toNamed('/signup');
                            },
                            child: Text(
                              'สมัครสมาชิก',
                              style: GoogleFonts.righteous(
                                decoration: TextDecoration.underline,
                                fontSize: 16.sp,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.yellow.shade900,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 40.h),
                        InputTextfield(
                          controller: _emailController,
                          onChanged: (value) {
                            setState(() {
                              email = value;
                            });
                          },
                          validator: (value) {
                            if (value!.isEmpty) {
                              return 'กรุณากรอกอีเมลของคุณ';
                            } else if (value.isValidEmail() == false) {
                              return 'รูปแบบอีเมลไม่ถูกต้อง';
                            } else if (value.isValidEmail() == true) {
                              return null;
                            } else {
                              return null;
                            }
                          },
                          hintText: 'Email',
                          textInputType: TextInputType.emailAddress,
                          prefixIcon: Icon(
                            Icons.email,
                            color: Colors.cyan.shade400,
                          ),
                        ),
                        InputTextfield(
                          controller: _passwordController,
                          hintText: 'รหัสผ่าน',
                          textInputType: TextInputType.text,
                          prefixIcon: Icon(
                            Icons.lock,
                            color: Colors.red.shade600,
                          ),
                          obscureText: _obscureText,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureText == true
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              size: 20.r,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureText = !_obscureText;
                              });
                            },
                          ),
                          onChanged: (value) {
                            setState(() {
                              password = value;
                            });
                          },
                          validator: (value) {
                            if (value!.isEmpty) {
                              return 'กรุณากรอกรหัสผ่าน';
                            } else if (value.length < 8) {
                              return 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร';
                            } else {
                              return null;
                            }
                          },
                        ),
                        SizedBox(height: 50.h),
                        SizedBox(
                          height: 50.h,
                          width: double.infinity,
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : BottonWidget(
                                  label: 'เข้าสู่ระบบ',
                                  style: GoogleFonts.righteous(
                                    fontSize: 16.sp,
                                    color: Colors.white,
                                  ),
                                  icon: Icons.login,
                                  press: login,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
