// ignore_for_file: no_leading_underscores_for_local_identifiers, avoid_print
import 'dart:async';
import 'package:colae_cut/assistants/qr_scanner_page.dart';
import 'package:colae_cut/tabs/store_tab/products_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:colae_cut/tabs/cart_tab/cart_page.dart';
import 'package:colae_cut/tabs/search_tab/search_tab.dart';
import 'package:colae_cut/tabs/home_tab/home_tab.dart';
import 'package:colae_cut/tabs/profile_tab/profile_page.dart';
import 'package:colae_cut/providers/cart_provider.dart';
import 'package:colae_cut/services/sevice.dart';
import 'package:badges/badges.dart' as badges;

class ExploreTabPages extends StatefulWidget {
  const ExploreTabPages({super.key});
  @override
  State<ExploreTabPages> createState() => _ExploreTabPagesState();
}

class _ExploreTabPagesState extends State<ExploreTabPages>
    with WidgetsBindingObserver {
  int pageIndex = 0;
  bool _hideNavBar = false;
  double _previousScroll = 0.0;
  Timer? _debounceTimer;

  late final List<Widget> _pages;

  void _onBackFromCart() {
    if (mounted) {
      setState(() {
        pageIndex = 0;
        _hideNavBar = false;
      });
      _previousScroll = 0.0;
    }
  }

  void _onNavTap(int val) {
    if (val != pageIndex) {
      _hideKeyboard();
    }
    setState(() {
      pageIndex = val;
      if (val == 3) {
        _hideNavBar = true;
      } else {
        _hideNavBar = false;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hideKeyboard();
      _previousScroll = 0.0;
      if (pageIndex != 2) {
        _resetNavBarIfStuck();
      }
    });
  }

  void _resetNavBarIfStuck() {
    if (pageIndex == 3) return;
    if (pageIndex == 1) return;
    if (_hideNavBar && _previousScroll < 100) {
      setState(() {
        _hideNavBar = false;
      });
    }
  }

  void _hideKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pages = [
      const Homepage(),
      ProductsTab(
        onScrollDown: () {
          if (!_hideNavBar && mounted) setState(() => _hideNavBar = true);
        },
        onScrollUp: () {
          if (_hideNavBar && mounted) setState(() => _hideNavBar = false);
        },
      ),
      const SearchPage(),
      CartPage(onBackFromCart: _onBackFromCart),
      const ProfilePage(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hideKeyboard();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _hideKeyboard();
          _resetNavBarIfStuck();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _hideKeyboard,
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        extendBody: true,
        body: NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification scrollInfo) {
            if (pageIndex == 2 || pageIndex == 3) {
              return false;
            }
            if (scrollInfo is UserScrollNotification) {
              final ScrollMetrics metrics = scrollInfo.metrics;
              final double currentPixels = metrics.pixels;
              final double delta = currentPixels - _previousScroll;
              scrollInfo is ScrollUpdateNotification
                  ? (scrollInfo as ScrollUpdateNotification)
                            .metrics
                            .viewportDimension *
                        0.1
                  : 0;
              if (_debounceTimer?.isActive ?? false) {
                _debounceTimer!.cancel();
              }
              _debounceTimer = Timer(const Duration(milliseconds: 100), () {
                if (mounted) {
                  if (delta > 10 && currentPixels > 100) {
                    if (!_hideNavBar) {
                      setState(() {
                        _hideNavBar = true;
                      });
                    }
                  } else if (delta < -10 || currentPixels < 100) {
                    if (_hideNavBar) {
                      setState(() {
                        _hideNavBar = false;
                      });
                    }
                  }
                  _previousScroll = currentPixels;

                  Timer(const Duration(milliseconds: 1500), () {
                    _resetNavBarIfStuck();
                  });
                }
              });
            }
            return false;
          },
          child: IndexedStack(index: pageIndex, children: _pages),
        ),
        bottomNavigationBar: SafeArea(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            height: _hideNavBar ? 0 : 65.h,
            child: _hideNavBar
                ? const SizedBox.shrink()
                : Consumer<CartProvider>(
                    builder: (context, cartProvider, child) {
                      return Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.bottomCenter,
                        children: [
                          Container(
                            decoration: const BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 8.0,
                                  offset: Offset(0, -2),
                                ),
                              ],
                            ),
                            child: BottomNavigationBar(
                              key: const ValueKey('bottom_nav'),
                              type: BottomNavigationBarType.fixed,
                              currentIndex: pageIndex,
                              onTap: _onNavTap,
                              selectedItemColor: Colors.white,
                              unselectedItemColor: Colors.white,
                              backgroundColor: mainColor,
                              selectedLabelStyle: GoogleFonts.righteous(
                                fontSize: 16,
                              ),
                              elevation: 0,
                              items: [
                                BottomNavigationBarItem(
                                  icon: Icon(
                                    pageIndex == 0
                                        ? IconlyBold.home
                                        : IconlyLight.home,
                                    size: 24.w,
                                  ),
                                  label: 'Home',
                                ),
                                BottomNavigationBarItem(
                                  icon: Icon(
                                    pageIndex == 1
                                        ? IconlyBold.category
                                        : IconlyLight.category,
                                    size: 24.w,
                                  ),
                                  label: 'Products',
                                ),
                                BottomNavigationBarItem(
                                  icon: SizedBox(width: 48.w),
                                  label: '',
                                ),
                                BottomNavigationBarItem(
                                  icon: badges.Badge(
                                    showBadge: cartProvider.totalQuantity == 0
                                        ? false
                                        : true,
                                    badgeContent: Padding(
                                      padding: EdgeInsets.all(2.w),
                                      child: Text(
                                        cartProvider.totalQuantity.toString(),
                                        style: styles(
                                          color: Colors.white,
                                          fontSize: 12.sp,
                                        ),
                                      ),
                                    ),
                                    badgeStyle: const badges.BadgeStyle(
                                      shape: badges.BadgeShape.circle,
                                      borderSide: BorderSide(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(100),
                                      ),
                                      badgeColor: Colors.redAccent,
                                      padding: EdgeInsets.all(4),
                                    ),
                                    child: Icon(
                                      pageIndex == 3
                                          ? IconlyBold.bookmark
                                          : IconlyLight.bookmark,
                                      size: 24.w,
                                    ),
                                  ),
                                  label: 'Cart',
                                ),
                                BottomNavigationBarItem(
                                  icon: Icon(
                                    pageIndex == 4
                                        ? IconlyBold.profile
                                        : IconlyLight.profile,
                                    size: 24.w,
                                  ),
                                  label: 'Profile',
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            bottom: 25.h,
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ScannerPage(),
                                  ),
                                );
                              },
                              child: Container(
                                height: 60.w,
                                width: 60.w,
                                decoration: BoxDecoration(
                                  color: mainColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: BoxBorder.all(
                                    width: 5,
                                    color: Colors.white,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: mainColor.withAlpha(300),
                                      spreadRadius: 3,
                                      blurRadius: 5,
                                      offset: Offset(2, 3),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  IconlyLight.scan,
                                  color: Colors.white,
                                  size: 34.sp,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
