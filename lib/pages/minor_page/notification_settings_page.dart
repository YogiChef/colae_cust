import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:colae_cut/services/sevice.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  bool _orderNotif = true;
  bool _hotelNotif = true;
  bool _promotionNotif = true;
  bool _chatNotif = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final doc = await FirebaseFirestore.instance
        .collection('buyers')
        .doc(_uid)
        .get();
    if (mounted && doc.exists) {
      final d = doc.data()!;
      final settings = d['notificationSettings'] as Map<String, dynamic>? ?? {};
      setState(() {
        _orderNotif = settings['order'] ?? true;
        _hotelNotif = settings['hotel'] ?? true;
        _promotionNotif = settings['promotion'] ?? true;
        _chatNotif = settings['chat'] ?? true;
        _loading = false;
      });
    } else if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _updateSetting(String key, bool value) async {
    await FirebaseFirestore.instance.collection('buyers').doc(_uid).set({
      'notificationSettings': {key: value},
    }, SetOptions(merge: true));
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
          'การแจ้งเตือน',
          style: styles(color: Colors.white, fontSize: 18.sp),
        ),
        backgroundColor: mainColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: EdgeInsets.all(12.w),
        children: [
          _switchTile(
            'การสั่งอาหาร',
            'แจ้งเตือนเมื่อ order มีการเปลี่ยนแปลง',
            Icons.shopping_cart,
            Colors.blue,
            _orderNotif,
            (v) {
              setState(() => _orderNotif = v);
              _updateSetting('order', v);
            },
          ),
          _switchTile(
            'การจองที่พัก',
            'แจ้งเตือนเมื่อ booking มีการเปลี่ยนแปลง',
            Icons.hotel,
            Colors.green,
            _hotelNotif,
            (v) {
              setState(() => _hotelNotif = v);
              _updateSetting('hotel', v);
            },
          ),
          _switchTile(
            'แชท',
            'แจ้งเตือนเมื่อมีข้อความใหม่',
            Icons.chat_bubble,
            Colors.orange,
            _chatNotif,
            (v) {
              setState(() => _chatNotif = v);
              _updateSetting('chat', v);
            },
          ),
          _switchTile(
            'โปรโมชั่น',
            'รับข่าวสารและส่วนลดพิเศษ',
            Icons.local_offer,
            Colors.red,
            _promotionNotif,
            (v) {
              setState(() => _promotionNotif = v);
              _updateSetting('promotion', v);
            },
          ),
        ],
      ),
    );
  }

  Widget _switchTile(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      child: SwitchListTile(
        secondary: Icon(icon, color: color, size: 24.sp),
        title: Text(
          title,
          style: styles(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.deepPurple[900],
          ),
        ),
        subtitle: Text(
          subtitle,
          style: styles(fontSize: 11.sp, color: Colors.grey[700]),
        ),
        value: value,
        activeThumbColor: Colors.green,
        onChanged: onChanged,
      ),
    );
  }
}
