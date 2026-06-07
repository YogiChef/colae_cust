import 'package:colae_cut/tabs/explore_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:colae_cut/services/sevice.dart';

class HotelProfileTab extends StatelessWidget {
  const HotelProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'โปรไฟล์',
          style: styles(color: Colors.white, fontSize: 18.sp),
        ),
        backgroundColor: mainColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: EdgeInsets.all(12.w),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.swap_horiz, color: Colors.blue),
              title: Text('เปลี่ยนบริการ', style: styles(fontSize: 16.sp)),
              subtitle: Text(
                'กลับไปเลือกโหมดบริการอื่น',
                style: styles(fontSize: 12.sp, color: Colors.grey),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('buyer_last_mode');
                if (!context.mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const ExploreTabPages()),
                  (route) => false,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
