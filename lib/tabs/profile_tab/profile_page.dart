// ignore_for_file: use_build_context_synchronously, avoid_print

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:colae_cut/providers/cart_provider.dart';
import 'package:colae_cut/providers/active_order_provider.dart';
import 'package:colae_cut/providers/vendor_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:colae_cut/auth/address/address_book.dart';
import 'package:colae_cut/auth/login_page.dart';
import 'package:colae_cut/tabs/cart_tab/cart_page.dart';
import 'package:colae_cut/pages/order_tab/order_page.dart';
import 'package:colae_cut/services/sevice.dart';
import 'package:colae_cut/widgets/dialog.dart';
import 'package:colae_cut/pages/minor_page/referral_dashboard_page.dart';
import 'package:colae_cut/pages/minor_page/edit_profile_page.dart';
import 'package:colae_cut/pages/minor_page/notification_settings_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  final bool isParentLoading;

  const ProfilePage({super.key, this.isParentLoading = false});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Future<DocumentSnapshot>? _userFuture;

  @override
  void initState() {
    super.initState();
    if (auth.currentUser != null) {
      _userFuture = firestore
          .collection('buyers')
          .doc(auth.currentUser!.uid)
          .get();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isParentLoading) {
      return const SizedBox.shrink();
    }

    return auth.currentUser == null
        ? Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        height: MediaQuery.of(context).size.height * 0.33.dg,
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 80, 20, 40),
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage('images/profile.jpg'),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.white,
                              radius: 50.dg,
                              child: Icon(
                                Icons.person,
                                size: 80.dg,
                                color: Colors.yellow.shade900,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: 10.w),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width:
                                        MediaQuery.of(context).size.width *
                                        0.5.dg,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.purple,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                        ),
                                      ),
                                      onPressed: () {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const LoginPage(),
                                          ),
                                        );
                                      },
                                      child: Text(
                                        'Login Account',
                                        style: styles(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),
                  firstBlock(
                    onPress: () {},
                    icon: Icons.settings,
                    text: 'แนะนำเฟื่อน',
                    subtitle: 'รายได้ Referral',
                  ),
                  firstBlock(onPress: () {}, icon: Icons.phone, text: 'Phone'),
                  firstBlock(
                    onPress: () {},
                    icon: Icons.shopping_cart,
                    text: 'ตะกร้า',
                  ),
                  firstBlock(
                    onPress: () {},
                    icon: Icons.description,
                    text: 'ออเดอร์',
                  ),
                  firstBlock(
                    onPress: () {},
                    icon: Icons.notifications,
                    text: 'การแจ้งเตือน',
                    subtitle: 'ตั้งค่าการแจ้งเตือน',
                  ),

                  firstBlock(
                    onPress: () {
                      MyAlertDialog.showMyDialog(
                        contant: 'Are you sure to log out ',
                        context: context,
                        img: const AssetImage('images/signout.png'),
                        tabNo: () {
                          Navigator.pop(context);
                        },
                        tabYes: () async {
                          try {
                            Provider.of<CartProvider>(
                              context,
                              listen: false,
                            ).removeAllItem();
                          } catch (_) {}
                          try {
                            Provider.of<ActiveOrderProvider>(
                              context,
                              listen: false,
                            ).clear();
                          } catch (_) {}
                          try {
                            Provider.of<VendorProvider>(
                              context,
                              listen: false,
                            ).clear();
                          } catch (_) {}

                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove('buyer_last_mode');

                          await auth.signOut();

                          if (!context.mounted) return;
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(),
                            ),
                            (route) => false,
                          );
                        },
                        title: 'ออกจากระบบ',
                      );
                    },
                    icon: Icons.logout,
                    text: 'ออกจากระบบ',
                  ),
                  SizedBox(height: 70.h),
                ],
              ),
            ),
          )
        : FutureBuilder<DocumentSnapshot>(
            future: _userFuture,
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<DocumentSnapshot> snapshot,
                ) {
                  if (snapshot.hasError) {
                    return const Text("Something went wrong");
                  }

                  if (snapshot.hasData && !snapshot.data!.exists) {
                    return const Text("Document does not exist");
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: SizedBox.shrink());
                  }

                  if (snapshot.connectionState == ConnectionState.done) {
                    Map<String, dynamic> data =
                        snapshot.data!.data() as Map<String, dynamic>;
                    return Scaffold(
                      body: SingleChildScrollView(
                        child: Column(
                          children: [
                            Container(
                              height: height * 0.33.h,
                              width: double.infinity,
                              padding: EdgeInsets.fromLTRB(
                                20.w,
                                40.h,
                                20.w,
                                12.h,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(20.r),
                                  bottomRight: Radius.circular(20.r),
                                ),
                                image: DecorationImage(
                                  image: CachedNetworkImageProvider(data['custcoverImage']),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 50.dg,
                                        backgroundImage: CachedNetworkImageProvider(
                                          data['profileImage'],
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: CircleAvatar(
                                          backgroundColor: Colors.cyanAccent,
                                          radius: 18.dg,
                                          child: IconButton(
                                            icon: Icon(
                                              Icons.edit,
                                              size: 20.dg,
                                              color: Colors.redAccent,
                                            ),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const EditProfilePage(),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        left: 12.w,
                                        top: 12.h,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Text(
                                            data['fullName'],
                                            textAlign: TextAlign.start,
                                            overflow: TextOverflow.ellipsis,
                                            style: styles(
                                              fontSize: 16.sp,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.blue[800],
                                            ),
                                          ),
                                          SizedBox(height: 4.h),
                                          Text(
                                            data['custemail'],
                                            textAlign: TextAlign.start,
                                            overflow: TextOverflow.ellipsis,
                                            style: styles(
                                              fontSize: 14.sp,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          SizedBox(height: 12.h),
                                          SizedBox(
                                            height: 40.h,
                                            width: width * .5.w,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: mainColor,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(5),
                                                ),
                                              ),
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        const AddressBook(),
                                                  ),
                                                );
                                              },
                                              child: Text(
                                                'แก้ไขที่อยู่',
                                                style: styles(
                                                  fontSize: 14.sp,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 20.h),

                            firstBlock(
                              onPress: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ReferralDashboardPage(),
                                  ),
                                );
                              },
                              icon: Icons.card_giftcard,
                              text: 'ธุรกิจ',
                              subtitle: 'รายได้ Referral',
                            ),

                            firstBlock(
                              onPress: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const CartPage(),
                                  ),
                                );
                              },
                              icon: Icons.shopping_cart,
                              text: 'ตะกร้า',
                            ),
                            firstBlock(
                              onPress: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const OrderPage(),
                                  ),
                                );
                              },
                              icon: Icons.description,
                              text: 'ออเดอร์',
                            ),
                            firstBlock(
                              onPress: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const NotificationSettingsPage(),
                                  ),
                                );
                              },
                              icon: Icons.notifications,
                              text: 'การแจ้งเตือน',
                              subtitle: 'ตั้งค่าการแจ้งเตือน',
                            ),

                            firstBlock(
                              onPress: () {
                                MyAlertDialog.showMyDialog(
                                  contant: 'Are you sure to signout ',
                                  context: context,
                                  img: const AssetImage('images/signout.png'),
                                  tabNo: () {
                                    Navigator.pop(context);
                                  },
                                  tabYes: () async {
                                    // เคลียร์ provider ทุกตัวก่อน signOut
                                    try {
                                      Provider.of<CartProvider>(
                                        context,
                                        listen: false,
                                      ).removeAllItem();
                                    } catch (_) {}
                                    try {
                                      Provider.of<ActiveOrderProvider>(
                                        context,
                                        listen: false,
                                      ).clear();
                                    } catch (_) {}
                                    try {
                                      Provider.of<VendorProvider>(
                                        context,
                                        listen: false,
                                      ).clear();
                                    } catch (_) {}

                                    // ลบ mode ที่จำไว้ เพื่อให้เลือกบริการใหม่
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    await prefs.remove('buyer_last_mode');

                                    await auth.signOut();

                                    if (!context.mounted) return;
                                    Navigator.of(context).pushAndRemoveUntil(
                                      MaterialPageRoute(
                                        builder: (_) => const LoginPage(),
                                      ),
                                      (route) => false,
                                    );
                                  },
                                  title: 'Log Out',
                                );
                              },
                              icon: Icons.logout,
                              text: 'ออกจากระบบ',
                            ),
                            SizedBox(height: 70.h),
                          ],
                        ),
                      ),
                    );
                  }

                  return Center(
                    child: CircularProgressIndicator(
                      color: Colors.yellow.shade900,
                    ),
                  );
                },
          );
  }

  Padding firstBlock({
    required IconData icon,
    required String text,
    String subtitle = '',
    required VoidCallback onPress,
  }) {
    return Padding(
      padding: EdgeInsets.only(left: 20.w),
      child: ListTile(
        onTap: onPress,
        leading: Icon(icon),
        title: Text(
          text,
          style: styles(
            fontSize: 16.sp,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: styles(
            fontSize: 12.sp,
            color: Colors.grey,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
