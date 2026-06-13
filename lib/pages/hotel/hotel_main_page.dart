import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:colae_cut/pages/hotel/tabs/hotel_search_tab.dart';
import 'package:colae_cut/pages/hotel/tabs/my_bookings_tab.dart';
import 'package:colae_cut/pages/hotel/tabs/hotel_favorites_tab.dart';
import 'package:colae_cut/services/sevice.dart';
import 'dart:async';

class HotelMainPage extends StatefulWidget {
  const HotelMainPage({super.key});

  @override
  State<HotelMainPage> createState() => _HotelMainPageState();
}

class _HotelMainPageState extends State<HotelMainPage> {
  int _currentTab = 0;
  int _unreadCount = 0;
  StreamSubscription<QuerySnapshot>? _chatSub;

  final List<Widget> _tabs = const [
    HotelSearchTab(),
    MyBookingsTab(),
    HotelFavoritesTab(),
  ];

  @override
  void initState() {
    super.initState();
    _listenUnread();
  }

  void _listenUnread() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _chatSub = FirebaseFirestore.instance
        .collection('chats')
        .where('buyerId', isEqualTo: uid)
        .where('proId', isGreaterThanOrEqualTo: 'hotel_')
        .where('proId', isLessThan: 'hotel_~')
        .snapshots()
        .listen((snap) {
          int count = 0;
          for (final doc in snap.docs) {
            final d = doc.data();
            final read = d['read'] as bool? ?? true;
            final senderId = d['senderId'] as String? ?? '';
            if (!read && senderId != uid) count++;
          }
          if (mounted && count != _unreadCount) {
            setState(() => _unreadCount = count);
          }
        });
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    super.dispose();
  }

  Widget _bookingTabIcon() {
    if (_unreadCount == 0) {
      return Icon(
        _currentTab == 1 ? IconlyBold.bookmark : IconlyLight.bookmark,
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(_currentTab == 1 ? IconlyBold.bookmark : IconlyLight.bookmark),
        Positioned(
          right: -6,
          top: -6,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            child: Text(
              _unreadCount > 9 ? '9+' : '$_unreadCount',
              style: styles(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_currentTab],
      bottomNavigationBar: SafeArea(
        child: BottomNavigationBar(
          backgroundColor: mainColor,
          currentIndex: _currentTab,
          selectedItemColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          unselectedItemColor: Colors.white70,
          selectedIconTheme: IconThemeData(size: 22.sp),
          selectedLabelStyle: GoogleFonts.righteous(fontSize: 14.sp),
          onTap: (index) => setState(() => _currentTab = index),
          items: [
            BottomNavigationBarItem(
              icon: _currentTab == 0
                  ? Icon(IconlyBold.search)
                  : Icon(IconlyLight.search),
              label: 'ค้นหา',
            ),
            BottomNavigationBarItem(
              icon: _bookingTabIcon(),
              label: 'การจองของฉัน',
            ),
            BottomNavigationBarItem(
              icon: _currentTab == 2
                  ? Icon(IconlyBold.heart)
                  : Icon(IconlyLight.heart),
              label: 'รายการโปรด',
            ),
          ],
        ),
      ),
    );
  }
}
