// ignore_for_file: no_leading_underscores_for_local_identifiers, unnecessary_cast, unused_field

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:colae_cut/pages/hotel/hotel_main_page.dart';
import 'package:colae_cut/providers/active_order_provider.dart';
import 'package:colae_cut/tabs/explore_tab.dart';
import 'package:colae_cut/widgets/bandner_widget.dart';
import 'package:colae_cut/widgets/category_widget.dart';
import 'package:colae_cut/widgets/location_widget.dart';
import 'package:colae_cut/widgets/mode_card_row.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final String? buyerId = FirebaseAuth.instance.currentUser?.uid;
  late final Stream<QuerySnapshot> _categoryStream;
  int _categoryKey = 0;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();

    _categoryStream = FirebaseFirestore.instance
        .collection('categories')
        .snapshots();
    if (buyerId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Provider.of<ActiveOrderProvider>(
            context,
            listen: false,
          ).startListening(buyerId);
        }
      });
    }
  }

  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {
        _categoryKey++;
      });
    }
  }

  Future<void> _selectMode(String mode) async {
    if (mode == 'vehicle') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เร็วๆ นี้! โหมดนี้กำลังพัฒนา')),
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('buyer_last_mode', mode);
    _navigateToMode(mode);
  }

  void _navigateToMode(String mode) {
    if (mode == 'hotel') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const HotelMainPage()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ExploreTabPages()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 30),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ModeCardRow(
                            image: Image.asset('images/hotel.png'),
                            color: Colors.blue,
                            title: 'โรงแรม',
                            onTap: () => _selectMode('hotel'),
                          ),
                          ModeCardRow(
                            image: Image.asset('images/vehicle.png'),
                            color: Colors.blue,
                            title: 'เดินทาง',
                            onTap: () {},
                          ),
                          ModeCardRow(
                            image: Image.asset('images/agriculture.png'),
                            color: Colors.blue,
                            title: 'เกษตร',
                            onTap: () {},
                          ),
                          ModeCardRow(
                            image: Image.asset('images/map.webp'),
                            color: Colors.blue,
                            title: 'แผนที่',
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LocationPage(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const BrandnerWidget(),
                ],
              ),
            ),
          ],
          body: StreamBuilder<QuerySnapshot>(
            stream: _categoryStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox.shrink();
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return const SizedBox.shrink();
              }
              final categories = snapshot.data!.docs;
              return CategoryWidget(
                key: ValueKey(_categoryKey),
                categories: categories,
                onCategorySelected: (_) {},
              );
            },
          ),
        ),
      ),
    );
  }
}
