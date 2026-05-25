// ignore_for_file: unused_field, use_build_context_synchronously, avoid_print, unused_local_variable

import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:thai_address_picker/thai_address_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:colae_cut/widgets/input_textfield.dart';
import 'package:colae_cut/services/sevice.dart';

class Address extends StatefulWidget {
  const Address({super.key, required this.userData});
  final dynamic userData;
  @override
  State<Address> createState() => _AddressState();
}

class _AddressState extends State<Address> {
  final fullName = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  bool _isLoading = false;
  String zipcode = '';
  String countryValue = 'Country';
  String stateValue = 'State';
  String cityValue = 'City';

  String? address;
  ThaiAddress? _selectedAddress;

  Uint8List? _image, _coverImage;

  @override
  void initState() {
    setState(() {
      fullName.text = widget.userData['fullName'];
      email.text = widget.userData['custemail'];
      phone.text = widget.userData['custphone'];
    });
    super.initState();
  }

  Future<void> _saveAddress() async {
    setState(() {
      _isLoading = true;
    });
    try {
      EasyLoading.show(status: 'Updating..');
      if (_selectedAddress != null &&
          (_selectedAddress?.zipCode ?? '').isNotEmpty) {
        CollectionReference addresRf = firestore
            .collection('buyers')
            .doc(auth.currentUser!.uid)
            .collection('address');
        var addresId = const Uuid().v4();
        await addresRf.doc(addresId).set({
          'addressId': addresId,
          'fullName': fullName.text.trim(),
          'email': email.text.trim(),
          'phone': phone.text.trim(),
          'address': address ?? '',
          'country': _selectedAddress?.provinceTh ?? '',
          'state': _selectedAddress?.provinceTh ?? '',
          'city': _selectedAddress?.districtTh ?? '',
          'subDistrict': _selectedAddress?.subDistrictTh ?? '',
          'zipcode': _selectedAddress?.zipCode ?? '',
          'default': true,
        });

        QuerySnapshot allAddresses = await addresRf.get();
        for (var item in allAddresses.docs) {
          await dfAddressFalse(item);
        }
        await dfAddressTrue(addresId);
        Map<String, dynamic> updateData = {
          'phone': phone.text.trim(),
          'address': address ?? '',
          'city': _selectedAddress?.districtTh ?? '',
          'state': _selectedAddress?.provinceTh ?? '',
          'subDistrict': _selectedAddress?.subDistrictTh ?? '',
          'country': 'ประเทศไทย',
          'zipcode': _selectedAddress?.zipCode ?? '',
        };
        await updateProfile(updateData);

        Fluttertoast.showToast(msg: 'Address updated successfully!');
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        Fluttertoast.showToast(
          msg: 'Please set your location and zipcode',
          backgroundColor: Colors.orange,
        );
      }
    } catch (e) {
      print('Save address error: $e'); // Log
      Fluttertoast.showToast(
        msg: 'Failed to update address: $e',
        backgroundColor: Colors.red,
      );
    } finally {
      EasyLoading.dismiss(); // Always dismiss
      if (mounted) {
        setState(() {
          _isLoading = false;
        }); // Re-enable UI
      }
    }
  }

  Future<void> dfAddressFalse(QueryDocumentSnapshot<Object?> item) async {
    if (!mounted) return;
    await firestore.runTransaction((transaction) async {
      DocumentReference dRf = firestore
          .collection('buyers')
          .doc(auth.currentUser!.uid)
          .collection('address')
          .doc(item.id);
      transaction.update(dRf, {'default': false});
    });
  }

  Future<void> dfAddressTrue(String addressId) async {
    if (!mounted) return;
    await firestore.runTransaction((transaction) async {
      DocumentReference dRf = firestore
          .collection('buyers')
          .doc(auth.currentUser!.uid)
          .collection('address')
          .doc(addressId);
      transaction.update(dRf, {'default': true});
    });
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    if (!mounted) return;
    await firestore.runTransaction((transaction) async {
      DocumentReference dRf = firestore
          .collection('buyers')
          .doc(auth.currentUser!.uid);
      transaction.update(dRf, data);
    });
    print(
      '=== DEBUG UPDATE PROFILE SUCCESS === Updated fields: ${data.toString()}',
    );
  }

  @override
  Widget build(BuildContext context) {
    var chooseAddress =
        countryValue != 'Country' &&
        stateValue != 'State' &&
        cityValue != 'City';

    return ProviderScope(
      child: Scaffold(
        body: GestureDetector(
          onTap: () => FocusScope.of(context).requestFocus(FocusNode()),
          behavior: HitTestBehavior.opaque,
          child: ListView(
            children: [
              Stack(
                children: [
                  SizedBox(
                    height: 60.h,
                    child: Center(
                      child: Text(
                        'เพิ่มที่อยู่',
                        textAlign: TextAlign.center,
                        style: styles(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16.w,
                    top: 12.h,
                    child: CircleAvatar(
                      radius: 20.r,
                      child: IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.arrow_back),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsets.only(top: 12.h),
                child: InputTextfield(
                  hintText: 'ชื่อ สกุล',
                  textInputType: TextInputType.text,
                  prefixIcon: Icon(Icons.person, color: Colors.yellow.shade900),
                  controller: fullName,
                  validator: (value) {
                    if (value!.isEmpty) {
                      return 'กรุณาใช้ชื่อจริง นามสกุลจริง';
                    } else {
                      return null;
                    }
                  },
                ),
              ),
              InputTextfield(
                hintText: 'Email',
                textInputType: TextInputType.emailAddress,
                prefixIcon: Icon(Icons.email, color: Colors.cyan.shade400),
                controller: email,
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'กรุณาใส่ email ของท่าน';
                  } else if (!value.isValidEmail()) {
                    // Fix: ใช้ !isValidEmail()
                    return 'Invalid email';
                  }
                  return null;
                },
              ),
              InputTextfield(
                hintText: 'เบอร์โทรศัพท์',
                textInputType: TextInputType.phone,
                prefixIcon: Icon(Icons.phone, color: Colors.green.shade300),
                controller: phone,
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'กรุณาใส่เบอร์โทรศัพท์';
                  }
                  if (!RegExp(r'^\d{10}$').hasMatch(value)) {
                    return 'เบอร์โทรต้องเป็นตัวเลข 10 หลักเท่านั้น (เช่น 0123456789)';
                  }

                  return null;
                },
              ),
              InputTextfield(
                hintText: 'ที่อยู่เลขที่',
                textInputType: TextInputType.text,
                prefixIcon: const Icon(
                  Icons.pin_drop_outlined,
                  color: Colors.red,
                ),
                onChanged: (value) {
                  address = value.trim(); // Trim space
                },
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Please Enter your address';
                  } else {
                    return null;
                  }
                },
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Column(
                  children: [
                    ThaiAddressForm(
                      textStyle: styles(
                        fontSize: 14.sp,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),

                      onChanged: (address) {
                        setState(() {});
                        if ((address.provinceTh ?? '').isEmpty) return;
                        if ((address.districtTh ?? '').isEmpty) return;
                        if ((address.subDistrictTh ?? '').isEmpty) {
                          return;
                        }
                        if ((address.zipCode ?? '').isEmpty) return;
                        setState(() => _selectedAddress = address);
                      },
                      useThai: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewPadding.bottom + 12.h,
              left: 20.w,
              right: 20.w,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50.h,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.purple),
                    )
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mainColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      onPressed: _isLoading ? null : _saveAddress,
                      child: Text(
                        'บันทึก',
                        style: styles(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
