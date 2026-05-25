// ignore_for_file: use_build_context_synchronously, avoid_print

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:colae_cut/services/sevice.dart';
import 'package:colae_cut/pages/map_page.dart';
import 'package:colae_cut/auth/login_page.dart';
import 'package:colae_cut/widgets/botton_widget.dart';
import 'package:colae_cut/widgets/input_textfield.dart';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String fullName = '';
  String email = '';
  String password = '';
  String phone = '';
  bool _isLoading = false;
  bool _obscureText = true;
  final _referralCodeController = TextEditingController();

  Uint8List? _image, _coverImage;

  @override
  void dispose() {
    _referralCodeController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    setState(() {
      _isLoading = true;
    });
    if (_image != null &&
        _image!.isNotEmpty &&
        _coverImage != null &&
        _coverImage!.isNotEmpty) {
      if (_formKey.currentState != null && _formKey.currentState!.validate()) {
        try {
          await authController.signUpUsers(
            fullName,
            email,
            password,
            phone,
            _image!,
            _coverImage!,
          );
          final referralCode =
              _referralCodeController.text.trim().toUpperCase();
          if (referralCode.isNotEmpty) {
            try {
              final functions = FirebaseFunctions.instanceFor(
                region: 'asia-southeast1',
              );
              await functions.httpsCallable('registerReferral').call({
                'newUserId': FirebaseAuth.instance.currentUser!.uid,
                'referralCode': referralCode,
                'userType': 'customer',
              });
            } catch (e) {
              debugPrint('[REFERRAL] error: $e');
            }
          } else {
            try {
              final functions = FirebaseFunctions.instanceFor(
                region: 'asia-southeast1',
              );
              await functions
                  .httpsCallable('generateReferralCodeForUser')
                  .call({
                    'userId': FirebaseAuth.instance.currentUser!.uid,
                    'userType': 'customer',
                  });
            } catch (e) {
              debugPrint('[REFERRAL-GEN] error: $e');
            }
          }
          await Future.delayed(const Duration(seconds: 1));
          setState(() {
            _formKey.currentState!.reset();
            _image = null;
            _coverImage = null;
            _isLoading = false;
            FocusScope.of(context).requestFocus(FocusNode());
          });
          Get.to(const MapPage());
          Fluttertoast.showToast(
            msg: 'Congratulations, an account has been created for you',
            backgroundColor: Colors.green,
            timeInSecForIosWeb: 4,
          );
        } catch (e) {
          setState(() {
            _isLoading = false;
          });

          String errorMessage = e.toString();
          if (e is FirebaseAuthException) {
            switch (e.code) {
              case 'email-already-in-use':
                errorMessage =
                    'Email นี้ถูกใช้แล้ว ลอง Sign In หรือใช้ email อื่น';
                break;
              case 'weak-password':
                errorMessage =
                    'Password ต้องแข็งแรงกว่านี้ (อย่างน้อย 6 ตัวอักษร)';
                break;
              case 'invalid-email':
                errorMessage = 'รูปแบบ email ไม่ถูกต้อง';
                break;
              default:
                errorMessage = e.message ?? 'Authentication error';
            }
          } else if (e is FirebaseException) {
            errorMessage = e.message ?? 'Firebase error';
          }
          Fluttertoast.showToast(
            msg: 'Sign up failed: $errorMessage',
            backgroundColor: Colors.red,
            timeInSecForIosWeb: 4,
          );
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        Fluttertoast.showToast(
          msg: 'Form validation failed or form not initialized',
          backgroundColor: Colors.red,
          timeInSecForIosWeb: 4,
        );
      }
    } else {
      setState(() {
        _isLoading = false;
      });
      Fluttertoast.showToast(
        msg: 'Please pick both profile and cover images',
        backgroundColor: Colors.red,
        timeInSecForIosWeb: 4,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).requestFocus(FocusNode()),
        behavior: HitTestBehavior.opaque,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Stack(
                    alignment: Alignment.topLeft,
                    children: [
                      Container(
                        height: height * 0.32,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: mainColor,
                          borderRadius: BorderRadius.circular(0),
                          image: _coverImage != null
                              ? DecorationImage(
                                  image: MemoryImage(_coverImage!),
                                  fit: BoxFit.cover,
                                )
                              : const DecorationImage(
                                  image: AssetImage('images/colae2.png'),
                                  fit: BoxFit.fitWidth,
                                ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Stack(
                                children: [
                                  _image != null
                                      ? CircleAvatar(
                                          radius: 50,
                                          backgroundColor:
                                              Colors.yellow.shade900,
                                          backgroundImage: MemoryImage(_image!),
                                        )
                                      : const CircleAvatar(
                                          radius: 50,
                                          backgroundImage: AssetImage(
                                            'images/account.png',
                                          ),
                                        ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: CircleAvatar(
                                      backgroundColor: Colors.amber.shade400,
                                      radius: 18,
                                      child: IconButton(
                                        onPressed: () {
                                          chooseOption(context);
                                        },
                                        icon: _image != null
                                            ? const Icon(
                                                Icons.edit,
                                                color: Colors.white,
                                                size: 18,
                                              )
                                            : const Icon(
                                                CupertinoIcons.photo,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        right: 12.w,
                        bottom: 6.h,
                        child: CircleAvatar(
                          backgroundColor: Colors.red.shade400,
                          radius: 18,
                          child: IconButton(
                            onPressed: () {
                              chooseOptionCoverImage(context);
                            },
                            icon: _coverImage != null
                                ? const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 18,
                                  )
                                : const Icon(
                                    CupertinoIcons.photo,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginPage(),
                        ),
                      );
                    },
                    child: Text(
                      'เข้าสู่ระบบ',
                      style: GoogleFonts.righteous(
                        decoration: TextDecoration.underline,
                        color: Colors.amber[900],
                        letterSpacing: 1,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                InputTextfield(
                  hintText: 'ชื่อ-สกุล',
                  textInputType: TextInputType.text,
                  prefixIcon: Icon(Icons.person, color: Colors.yellow.shade900),
                  onChanged: (value) {
                    setState(() {
                      fullName = value;
                    });
                  },
                  validator: (value) {
                    if ((value ?? '').isEmpty) {
                      return 'Please Enter your name';
                    } else {
                      return null;
                    }
                  },
                ),
                InputTextfield(
                  hintText: 'Email',
                  textInputType: TextInputType.emailAddress,
                  prefixIcon: Icon(Icons.email, color: Colors.cyan.shade400),
                  onChanged: (value) {
                    setState(() {
                      email = value;
                    });
                  },
                  validator: (value) {
                    final val = value ?? '';
                    if (val.isEmpty) {
                      return 'Please enter your email address';
                    } else if (!val.isValidEmail()) {
                      return 'Invalid email';
                    }
                    return null;
                  },
                ),
                InputTextfield(
                  hintText: 'รหัสผ่าน',
                  textInputType: TextInputType.text,
                  obscureText: _obscureText,
                  prefixIcon: Icon(Icons.lock, color: Colors.red.shade600),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility : Icons.visibility_off,
                      size: 20,
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
                    final val = value ?? '';
                    if (val.isEmpty) {
                      return 'Please enter your password';
                    } else if (val.length < 8) {
                      return 'Password must be longer than eight characters';
                    }
                    return null;
                  },
                ),
                InputTextfield(
                  hintText: 'เบอร์โทร',
                  textInputType: TextInputType.phone,
                  prefixIcon: Icon(Icons.phone, color: Colors.green.shade300),
                  onChanged: (value) {
                    setState(() {
                      phone = value;
                    });
                  },
                  validator: (value) {
                    if ((value ?? '').isEmpty) {
                      return 'Please Enter your Phone';
                    } else {
                      return null;
                    }
                  },
                ),
                InputTextfield(
                  hintText: 'รหัสแนะนำ (ถ้ามี)',
                  textInputType: TextInputType.text,
                  prefixIcon: Icon(
                    Icons.card_giftcard,
                    color: Colors.purple,
                  ),
                  controller: _referralCodeController,
                  validator: (_) => null,
                ),
                SizedBox(height: 70.h),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewPadding.bottom + 12.h,
            left: 20.w,
            right: 20.w,
            top: 10.h,
          ),
          child: SizedBox(
            height: 50.h,
            width: double.infinity,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : BottonWidget(
                    label: 'เข้าสู่ระบบ',
                    style: styles(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    icon: Icons.upload_rounded,
                    press: _signUp,
                  ),
          ),
        ),
      ),
    );
  }

  Future<dynamic> chooseOption(BuildContext context) {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'ตัวเลือก',
            style: GoogleFonts.righteous(
              fontWeight: FontWeight.w500,
              color: Colors.yellow.shade900,
            ),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                InkWell(
                  onTap: () {
                    selectCameca();
                    Navigator.pop(context);
                  },
                  splashColor: Colors.yellow.shade900,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.camera_alt_outlined,
                          color: Colors.yellow.shade900,
                        ),
                      ),
                      Text(
                        'กล้อง',
                        style: GoogleFonts.righteous(
                          fontWeight: FontWeight.w500,
                          color: mainColor,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () {
                    selectGallery();
                    Navigator.pop(context);
                  },
                  splashColor: Colors.yellow.shade900,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.image_outlined,
                          color: Colors.green[900],
                        ),
                      ),
                      Text(
                        'คลังภาพ',
                        style: GoogleFonts.righteous(
                          fontWeight: FontWeight.w500,
                          color: mainColor,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () {
                    remove();
                  },
                  splashColor: Colors.yellow.shade900,
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.remove_circle, color: Colors.red),
                      ),
                      Text(
                        'ออก',
                        style: GoogleFonts.righteous(
                          fontWeight: FontWeight.w500,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> selectCameca() async {
    Uint8List? img = await authController.pickProfileImage(ImageSource.camera);

    if (img != null) {
      setState(() {
        _image = img;
      });
    } else {
      Fluttertoast.showToast(msg: 'ไม่ได้เลือกภาพ');
    }
  }

  Future<void> selectGallery() async {
    final img = await authController.pickProfileImage(ImageSource.gallery);

    setState(() {
      _image = img;
    });
  }

  void remove() {
    Navigator.pop(context);
  }

  Future<dynamic> chooseOptionCoverImage(BuildContext context) {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'ตัวเลือก',
            style: GoogleFonts.righteous(
              fontWeight: FontWeight.w500,
              color: Colors.yellow.shade900,
            ),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                InkWell(
                  onTap: () {
                    selectCamecaCoverImg();
                    Navigator.pop(context);
                  },
                  splashColor: Colors.yellow.shade900,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          CupertinoIcons.camera_circle,
                          color: Colors.yellow.shade900,
                        ),
                      ),
                      Text(
                        'กล้อง',
                        style: GoogleFonts.righteous(
                          fontWeight: FontWeight.w500,
                          color: mainColor,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () {
                    selectGalleryCoverImg();
                    Navigator.pop(context);
                  },
                  splashColor: Colors.yellow.shade900,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.image_outlined,
                          color: Colors.green[900],
                        ),
                      ),
                      Text(
                        'คลังภาพ',
                        style: GoogleFonts.righteous(
                          fontWeight: FontWeight.w500,
                          color: mainColor,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () {
                    removeCoverImg();
                  },
                  splashColor: Colors.yellow.shade900,
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.remove_circle, color: Colors.red),
                      ),
                      Text(
                        'ออก',
                        style: GoogleFonts.righteous(
                          fontWeight: FontWeight.w500,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> selectCamecaCoverImg() async {
    Uint8List? img = await authController.pickProfileImage(ImageSource.camera);

    if (img != null) {
      setState(() {
        _image = img;
      });
    } else {
      Fluttertoast.showToast(msg: 'ไม่ได้เลือกภาพ');
    }
  }

  Future<void> selectGalleryCoverImg() async {
    final img = await authController.pickProfileImage(ImageSource.gallery);

    setState(() {
      _coverImage = img;
    });
  }

  void removeCoverImg() {
    Navigator.pop(context);
  }
}
