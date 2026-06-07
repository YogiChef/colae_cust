// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:colae_cut/services/sevice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ModeCardRow extends StatelessWidget {
  const ModeCardRow({
    super.key,
    required this.image,
    required this.color,
    required this.onTap,
    required this.title,
  });

  final Image image;
  final Color color;
  final VoidCallback onTap;
  final String title;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7.r),
      child: Container(
        width: width * 0.23,
        margin: EdgeInsets.symmetric(horizontal: 4.w),
        padding: EdgeInsets.only(top: 30.h, bottom: 26.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
          color: Colors.white.withAlpha(20),
        ),
        child: Column(
          children: [
            Image(
              image: image.image,
              height: 52.r,
              width: 52.r,
              fit: BoxFit.fitWidth,
            ),
            SizedBox(height: 12.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: styles(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: Colors.black45,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
