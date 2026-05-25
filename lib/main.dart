// ignore_for_file: avoid_print, unused_element_parameter, deprecated_member_use, unnecessary_underscores

import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:colae_cut/auth/sign_up_page.dart';
import 'package:colae_cut/firebase_options.dart';
import 'package:colae_cut/pages/main_products.dart';
import 'package:colae_cut/providers/active_order_provider.dart';
import 'package:colae_cut/services/sevice.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:colae_cut/auth/login_page.dart';
import 'package:colae_cut/providers/cart_provider.dart';
import 'package:colae_cut/providers/app_info.dart' as local;
import 'package:colae_cut/tabs/explore_tab.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:colae_cut/services/notification_service.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final mapsImplementation = GoogleMapsFlutterPlatform.instance;
  if (mapsImplementation is GoogleMapsFlutterAndroid) {
    mapsImplementation.useAndroidViewSurface = true;
    print('✅ Google Maps Hybrid Composition enabled (แก้ปัญหาแผนที่แล้ว)');
  }
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.dark,
    ),
  );

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
      );

      await FirebaseAuth.instance.setSettings(forceRecaptchaFlow: false);
    } else {}
  } catch (e) {
    print("🔥 Firebase initialization error: $e");
  }

  await FirebaseAppCheck.instance.activate(
    androidProvider: kReleaseMode
        ? AndroidProvider.playIntegrity
        : AndroidProvider.debug,
  );
  await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);

  await NotificationService.init();

  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    await NotificationService.saveToken(currentUser.uid);
  }
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    NotificationService.showLocalNotification(message);
  });

  final appLinks = AppLinks();
  final initialUri = await appLinks.getInitialLink();
  if (initialUri != null) {
    _handleIncomingLink(initialUri);
  }

  appLinks.uriLinkStream.listen((uri) {
    _handleIncomingLink(uri);
  }, onError: (err) {});

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => local.AppInfo()),
        ChangeNotifierProvider(create: (_) => ActiveOrderProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

void _handleIncomingLink(Uri uri) {
  if (uri.scheme == 'delibox' && uri.host == 'table') {
    final restaurantId = uri.queryParameters['restaurant_id'];
    final tableNumber = uri.queryParameters['table'];

    if (restaurantId == null || restaurantId.isEmpty) {
      return;
    }
    Get.to(
      () => MainProductPage(vendorid: restaurantId, tableNumber: tableNumber),
    );
  }
}

class _AuthHome extends StatelessWidget {
  final String uid;
  const _AuthHome({required this.uid, super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('buyers')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }

        if (snapshot.hasError) {
          print("🔥 Firestore Error: ${snapshot.error}");
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('เกิดข้อผิดพลาดในการโหลดข้อมูล'),
                  Text('Error: ${snapshot.error}'),
                  ElevatedButton(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    child: const Text('ออกจากระบบ'),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const LoginPage();
        }

        return const ExploreTabPages();
      },
    );
  }
}

class AppLifecycleObserver extends StatefulWidget {
  final Widget child;
  const AppLifecycleObserver({super.key, required this.child});

  @override
  State<AppLifecycleObserver> createState() => _AppLifecycleObserverState();
}

class _AppLifecycleObserverState extends State<AppLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          FirebaseFirestore.instance
              .collection('buyers')
              .doc(user.uid)
              .get()
              .then((doc) => print('Buyer data refreshed: ${doc.exists}'));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return GetMaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Deli Box',
          theme: ThemeData(
            scaffoldBackgroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.black26),
            primarySwatch: Colors.blue,
            textTheme: Typography.englishLike2018.apply(
              fontSizeFactor: 1.sp,
              bodyColor: Colors.black,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primarySwatch: Colors.pink,
            scaffoldBackgroundColor: Colors.black,
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: Colors.white),
              bodyMedium: TextStyle(color: Colors.white70),
              headlineSmall: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
          ),
          themeMode: ThemeMode.system,
          getPages: [
            GetPage(name: '/', page: () => const ExploreTabPages()),
            GetPage(name: '/login', page: () => const LoginPage()),
            GetPage(name: '/signup', page: () => const SignUpPage()),
            GetPage(
              name: '/signup',
              page: () {
                final args = Get.arguments as Map<String, dynamic>?;
                return LoginPage(
                  userId: args?['userId'] as String?,
                  email: args?['email'] as String?,
                  token: args?['token'] as String?,
                );
              },
            ),
          ],
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, authSnapshot) {
              if (authSnapshot.connectionState == ConnectionState.waiting) {
                return const SplashView();
              }
              if (authSnapshot.data == null) {
                return const LoginPage();
              }

              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('buyers')
                    .doc(authSnapshot.data!.uid)
                    .snapshots(),
                builder: (context, buyerSnapshot) {
                  if (buyerSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const SplashView();
                  }
                  if (!buyerSnapshot.hasData || !buyerSnapshot.data!.exists) {
                    return const LoginPage();
                  }
                  return const ExploreTabPages();
                },
              );
            },
          ),
          builder: EasyLoading.init(),
        );
      },
    );
  }
}

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  Timer? _timer;

  @override
  void initState() {
    _timer = Timer(const Duration(seconds: 7), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (_, __, ___) => AppLifecycleObserver(
            child: StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data == null) {
                  return const LoginPage();
                }
                return _AuthHome(uid: snapshot.data!.uid);
              },
            ),
          ),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    });
    super.initState();
  }

  @override
  void dispose() {
    _timer!.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mainColor,
      body: Column(
        children: [
          SizedBox(height: 170),
          Center(child: Image.asset('images/colae2.png', fit: BoxFit.contain)),
        ],
      ),
    );
  }
}
