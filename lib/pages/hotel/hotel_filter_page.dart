// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:colae_cut/services/sevice.dart';

class HotelFilterPage extends StatefulWidget {
  final Map<String, dynamic> currentFilters;
  const HotelFilterPage({super.key, required this.currentFilters});

  @override
  State<HotelFilterPage> createState() => _HotelFilterPageState();
}

class _HotelFilterPageState extends State<HotelFilterPage> {
  late Map<String, dynamic> _f;
  List<String> _mainTypeOptions = [];
  List<String> _amenitiesOptions = [];

  final _provinceController = TextEditingController();
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _f = Map<String, dynamic>.from(widget.currentFilters);
    _f['amenities'] = List<String>.from(_f['amenities'] ?? []);
    _provinceController.text = _f['province'] ?? '';
    _minPriceController.text = _f['minPrice']?.toString() ?? '';
    _maxPriceController.text = _f['maxPrice']?.toString() ?? '';
    _loadLists();
  }

  @override
  void dispose() {
    _provinceController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  Future<void> _loadLists() async {
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('hotel_lists')
            .doc('main_types')
            .get(),
        FirebaseFirestore.instance
            .collection('hotel_lists')
            .doc('amenities')
            .get(),
      ]);
      if (mounted) {
        setState(() {
          _mainTypeOptions = List<String>.from(
            results[0].data()?['items'] ?? [],
          );
          _amenitiesOptions = List<String>.from(
            results[1].data()?['items'] ?? [],
          );
        });
      }
    } catch (_) {}
  }

  void _reset() {
    setState(() {
      _f = {
        'mainType': null,
        'province': null,
        'maxGuests': null,
        'minPrice': null,
        'maxPrice': null,
        'amenities': <String>[],
        'minRating': null,
        'sortBy': 'distance',
      };
      _provinceController.clear();
      _minPriceController.clear();
      _maxPriceController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ตัวกรอง',
          style: styles(color: Colors.white, fontSize: 18.sp),
        ),
        backgroundColor: mainColor,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _reset,
            child: const Text('ล้าง', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          _sectionTitle('ประเภทที่พัก'),
          _mainTypeOptions.isEmpty
              ? Text(
                  'กำลังโหลด...',
                  style: styles(fontSize: 12.sp, color: Colors.grey),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _mainTypeOptions.map((t) {
                    return FilterChip(
                      label: Text(
                        t,
                        style: styles(fontSize: 12.sp, color: Colors.black87),
                      ),
                      selected: _f['mainType'] == t,
                      selectedColor: mainColor.withOpacity(0.2),
                      checkmarkColor: mainColor,
                      onSelected: (v) =>
                          setState(() => _f['mainType'] = v ? t : null),
                    );
                  }).toList(),
                ),

          SizedBox(height: 16.h),
          _sectionTitle('จังหวัด'),
          TextField(
            controller: _provinceController,
            decoration: InputDecoration(
              hintText: 'พิมพ์ชื่อจังหวัด',
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12.w,
                vertical: 10.h,
              ),
            ),
            onChanged: (v) =>
                _f['province'] = v.trim().isEmpty ? null : v.trim(),
          ),

          SizedBox(height: 16.h),
          _sectionTitle('ช่วงราคา (บาท/คืน)'),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minPriceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'ต่ำสุด',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 10.h,
                    ),
                  ),
                  onChanged: (v) => _f['minPrice'] = double.tryParse(v),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                child: const Text('–'),
              ),
              Expanded(
                child: TextField(
                  controller: _maxPriceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'สูงสุด',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 10.h,
                    ),
                  ),
                  onChanged: (v) => _f['maxPrice'] = double.tryParse(v),
                ),
              ),
            ],
          ),

          SizedBox(height: 16.h),
          _sectionTitle('สิ่งอำนวยความสะดวก'),
          _amenitiesOptions.isEmpty
              ? Text(
                  'กำลังโหลด...',
                  style: styles(fontSize: 12.sp, color: Colors.grey),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _amenitiesOptions.map((a) {
                    final selected = (_f['amenities'] as List<String>).contains(
                      a,
                    );
                    return FilterChip(
                      label: Text(
                        a,
                        style: styles(fontSize: 12.sp, color: Colors.black87),
                      ),
                      selected: selected,
                      selectedColor: mainColor.withOpacity(0.2),
                      checkmarkColor: mainColor,
                      onSelected: (v) => setState(() {
                        if (v) {
                          (_f['amenities'] as List<String>).add(a);
                        } else {
                          (_f['amenities'] as List<String>).remove(a);
                        }
                      }),
                    );
                  }).toList(),
                ),

          SizedBox(height: 16.h),
          _sectionTitle('คะแนนรีวิวขั้นต่ำ'),
          Wrap(
            spacing: 8,
            children: [3.0, 4.0, 4.5].map((r) {
              return FilterChip(
                label: Text(
                  '$r+ ดาว',
                  style: styles(fontSize: 12.sp, color: Colors.black87),
                ),
                selected: _f['minRating'] == r,
                selectedColor: mainColor.withOpacity(0.2),
                checkmarkColor: mainColor,
                onSelected: (v) =>
                    setState(() => _f['minRating'] = v ? r : null),
              );
            }).toList(),
          ),

          SizedBox(height: 16.h),
          _sectionTitle('เรียงตาม'),
          ...[
            {'key': 'distance', 'label': 'ระยะทาง (ใกล้สุด)'},
            {'key': 'price_asc', 'label': 'ราคา (ต่ำ → สูง)'},
            {'key': 'price_desc', 'label': 'ราคา (สูง → ต่ำ)'},
            {'key': 'rating', 'label': 'คะแนนรีวิวมากสุด'},
            {'key': 'newest', 'label': 'ใหม่ล่าสุด'},
          ].map((opt) {
            return RadioListTile<String>(
              title: Text(
                opt['label']!,
                style: styles(fontSize: 13.sp, color: Colors.black87),
              ),
              value: opt['key']!,
              groupValue: _f['sortBy'] as String? ?? 'distance',
              activeColor: mainColor,
              dense: true,
              onChanged: (v) => setState(() => _f['sortBy'] = v),
            );
          }),

          SizedBox(height: 30.h),
          SizedBox(
            width: double.infinity,
            height: 50.h,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: mainColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              onPressed: () => Navigator.pop(context, _f),
              child: Text(
                'ใช้ตัวกรอง',
                style: styles(
                  fontSize: 16.sp,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h, top: 4.h),
      child: Row(
        children: [
          Container(
            width: 4.w,
            height: 16.h,
            decoration: BoxDecoration(
              color: mainColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            text,
            style: styles(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
