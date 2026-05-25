import 'package:colae_cut/services/sevice.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MyAlertDialog {
  static void showMyDialog({
    required BuildContext context,
    required ImageProvider<Object> img,
    required String title,
    required String contant,
    Widget? widget,
    required Function() tabNo,
    Function()? tabYes,
  }) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Container(
            width: width * 0.85,
            padding: EdgeInsets.all(20.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image(image: img, width: 140.w),
                SizedBox(height: 12.h),
                Text(
                  title,
                  style: styles(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8.h),
                Text(
                  contant,
                  style: styles(
                    color: Colors.red,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (widget != null) ...[SizedBox(height: 10.h), widget],
                SizedBox(height: 16.h),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: tabNo,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.amber.shade700),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        child: Text(
                          'ยกเลิก',
                          style: styles(
                            color: Colors.amber.shade700,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: tabYes ?? () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mainColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        child: Text(
                          'ยืนยัน',
                          style: styles(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class LoginDialog {
  static void showLoginDialog(BuildContext context) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('please log in'),
        content: const Text('you should be logged in to take an action'),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          CupertinoDialogAction(
            child: Text(
              'Log in',
              style: styles(color: Colors.red, fontWeight: FontWeight.w600),
            ),
            onPressed: () {
              Navigator.pushReplacementNamed(context, 'customer_login');
            },
          ),
        ],
      ),
    );
  }
}
