// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:colae_cut/pages/main_catagorys.dart';
import 'package:colae_cut/services/sevice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:colae_cut/pages/main_store.dart';

class CategoryWidget extends StatefulWidget {
  final List<QueryDocumentSnapshot> categories;
  final Function(String?)? onCategorySelected;

  const CategoryWidget({
    super.key,
    required this.categories,
    this.onCategorySelected,
  });

  @override
  State<CategoryWidget> createState() => _CategoryWidgetState();
}

class _CategoryWidgetState extends State<CategoryWidget> {
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _selectedCategory = null);
        await Future.delayed(const Duration(milliseconds: 300));
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Flexible(
              child: SizedBox(
                height: 130.h,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                  child: Row(
                    children: widget.categories.map((categoryData) {
                      final data = categoryData.data() as Map<String, dynamic>;
                      final String categoryName =
                          data['categoryName'] as String? ?? '';
                      final String categoryKey =
                          data['category'] as String? ??
                          data['categoryKey'] as String? ??
                          categoryName;
                      final String imageUrl = data['image'] as String? ?? '';
                      final bool isThisSelected =
                          _selectedCategory == categoryKey;

                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedCategory = categoryKey);
                        },
                        child: Container(
                          width: 100.w,
                          margin: EdgeInsets.symmetric(horizontal: 4.w),
                          padding: EdgeInsets.only(top: 20.h),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12.r),
                            color: Colors.white.withAlpha(
                              isThisSelected ? 20 : 10,
                            ),
                          ),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12.r),
                                child: Image(
                                  image: CachedNetworkImageProvider(
                                    imageUrl,
                                    maxWidth: 112,
                                    maxHeight: 100,
                                  ),
                                  height: isThisSelected ? 56.r : 52.r,
                                  width: isThisSelected ? 56.r : 52.r,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              SizedBox(height: 12.h),
                              Text(
                                categoryName,
                                textAlign: TextAlign.center,
                                style: styles(
                                  fontSize: isThisSelected ? 14.sp : 12.sp,
                                  fontWeight: FontWeight.w700,
                                  color: isThisSelected
                                      ? Colors.green
                                      : Colors.grey.shade700,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: _selectedCategory != null
                ? CategoryHome(
                    key: ValueKey(_selectedCategory),
                    bussinessName: _selectedCategory!,
                  )
                : const MainStorePage(),
          ),
        ],
      ),
    );
  }
}
