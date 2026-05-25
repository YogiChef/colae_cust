import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:colae_cut/services/sevice.dart';
import 'package:colae_cut/pages/order_tab/ordered_tab.dart';
import 'package:colae_cut/pages/order_tab/ordering_tab.dart';

class OrderPage extends StatefulWidget {
  const OrderPage({super.key});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          backgroundColor: mainColor,
          leading: Padding(
            padding: EdgeInsets.only(left: 12.w, top: 12.h),
            child: IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
          title: Text(
            'Orders ',
            style: styles(fontSize: 16.sp, color: Colors.white),
          ),
          elevation: 0,
          centerTitle: true,
          bottom: TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 6,
            unselectedLabelColor: Colors.grey,
            labelColor: Colors.white,
            labelStyle: styles(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
            unselectedLabelStyle: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w400,
            ),
            tabs: const [
              Tab(child: Text('รายการที่สัง')),
              Tab(child: Text('ประวัติการสั่ง')),
            ],
          ),
        ),
        body: const TabBarView(children: [Ordering(), Ordered()]),
      ),
    );
  }
}
