import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:colae_cut/services/sevice.dart';

class HotelReviewPage extends StatefulWidget {
  final String bookingId;
  final String hotelId;
  final String hotelName;
  const HotelReviewPage({
    super.key,
    required this.bookingId,
    required this.hotelId,
    required this.hotelName,
  });

  @override
  State<HotelReviewPage> createState() => _HotelReviewPageState();
}

class _HotelReviewPageState extends State<HotelReviewPage> {
  final _commentController = TextEditingController();
  final _picker = ImagePicker();

  int _cleanliness = 0;
  int _service = 0;
  int _value = 0;
  int _location = 0;

  final List<File> _images = [];
  bool _saving = false;
  bool _alreadyReviewed = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkExisting();
  }

  Future<void> _checkExisting() async {
    final snap = await FirebaseFirestore.instance
        .collection('hotel_reviews')
        .where('bookingId', isEqualTo: widget.bookingId)
        .limit(1)
        .get();

    if (mounted) {
      setState(() {
        _alreadyReviewed = snap.docs.isNotEmpty;
        _loading = false;
      });
    }
  }

  Future<void> _pickImages() async {
    if (_images.length >= 5) {
      Fluttertoast.showToast(msg: 'แนบรูปได้สูงสุด 5 รูป');
      return;
    }
    final picked = await _picker.pickMultiImage(limit: 5 - _images.length);
    if (picked.isEmpty) return;
    setState(() {
      _images.addAll(picked.map((x) => File(x.path)));
    });
  }

  double get _averageRating {
    final ratings = [_cleanliness, _service, _value, _location];
    final filled = ratings.where((r) => r > 0).toList();
    if (filled.isEmpty) return 0;
    return filled.reduce((a, b) => a + b) / filled.length;
  }

  Future<void> _submit() async {
    if (_cleanliness == 0 || _service == 0 || _value == 0 || _location == 0) {
      Fluttertoast.showToast(msg: 'กรุณาให้คะแนนทุกด้าน');
      return;
    }
    if (_commentController.text.trim().length < 10) {
      Fluttertoast.showToast(msg: 'กรุณาเขียนรีวิวอย่างน้อย 10 ตัวอักษร');
      return;
    }

    setState(() => _saving = true);
    EasyLoading.show(status: 'กำลังส่งรีวิว...');

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final buyerDoc = await FirebaseFirestore.instance
          .collection('buyers')
          .doc(uid)
          .get();
      final buyerData = buyerDoc.data() ?? {};

      final imageUrls = <String>[];
      for (final file in _images) {
        final ref = FirebaseStorage.instance.ref(
          'review_images/${widget.bookingId}/${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await ref.putFile(file);
        imageUrls.add(await ref.getDownloadURL());
      }

      final reviewRef = FirebaseFirestore.instance
          .collection('hotel_reviews')
          .doc();
      await reviewRef.set({
        'bookingId': widget.bookingId,
        'hotelId': widget.hotelId,
        'hotelName': widget.hotelName,
        'guestId': uid,
        'guestName': buyerData['fullName'] ?? 'ไม่ระบุ',
        'guestImage': buyerData['profileImage'] ?? '',
        'ratings': {
          'cleanliness': _cleanliness,
          'service': _service,
          'value': _value,
          'location': _location,
        },
        'averageRating': _averageRating,
        'comment': _commentController.text.trim(),
        'images': imageUrls,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _updateHotelRating();

      EasyLoading.showSuccess('ส่งรีวิวสำเร็จ');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      EasyLoading.showError('ผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updateHotelRating() async {
    final snap = await FirebaseFirestore.instance
        .collection('hotel_reviews')
        .where('hotelId', isEqualTo: widget.hotelId)
        .get();

    if (snap.docs.isEmpty) return;

    double sum = 0;
    for (final doc in snap.docs) {
      sum += (doc.data()['averageRating'] as num?)?.toDouble() ?? 0;
    }
    final avg = sum / snap.docs.length;

    await FirebaseFirestore.instance
        .collection('hotels')
        .doc(widget.hotelId)
        .update({'rating': avg, 'totalReviews': snap.docs.length});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(backgroundColor: mainColor),
        body: Center(child: CircularProgressIndicator(color: mainColor)),
      );
    }

    if (_alreadyReviewed) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'รีวิว',
            style: styles(color: Colors.white, fontSize: 18.sp),
          ),
          backgroundColor: mainColor,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, size: 80.sp, color: Colors.green),
              SizedBox(height: 16.h),
              Text(
                'คุณได้รีวิวแล้ว',
                style: styles(fontSize: 16.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8.h),
              Text(
                'รีวิวสามารถเขียนได้ครั้งเดียวเท่านั้น',
                style: styles(fontSize: 13.sp, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'เขียนรีวิว',
          style: styles(
            color: Colors.white,
            fontSize: 20.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: mainColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 20.h),
            Text(
              widget.hotelName,
              style: styles(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.purple[900],
              ),
            ),
            SizedBox(height: 16.h),

            _sectionTitle('ให้คะแนน (1-5 ดาว)'),
            _ratingRow(
              'ความสะอาด',
              _cleanliness,
              (v) => setState(() => _cleanliness = v),
            ),
            _ratingRow(
              'การบริการ',
              _service,
              (v) => setState(() => _service = v),
            ),
            _ratingRow(
              'ความคุ้มค่า',
              _value,
              (v) => setState(() => _value = v),
            ),
            _ratingRow('ทำเล', _location, (v) => setState(() => _location = v)),

            if (_averageRating > 0) ...[
              SizedBox(height: 12.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 24.sp),
                    SizedBox(width: 8.w),
                    Text('คะแนนเฉลี่ย: ', style: styles(fontSize: 13.sp)),
                    Text(
                      _averageRating.toStringAsFixed(1),
                      style: styles(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber[800],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(height: 20.h),
            _sectionTitle('เขียนรีวิว (อย่างน้อย 10 ตัวอักษร)'),
            TextField(
              controller: _commentController,
              maxLines: 5,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'เล่าประสบการณ์การพักของคุณ...',
                hintStyle: styles(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey.shade400,
                ),
                border: const OutlineInputBorder(),
              ),
            ),

            SizedBox(height: 20.h),
            _sectionTitle('แนบรูป (${_images.length}/5)'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._images.asMap().entries.map((entry) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8.r),
                        child: Image.file(
                          entry.value,
                          width: 80.w,
                          height: 80.w,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _images.removeAt(entry.key)),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                if (_images.length < 5)
                  InkWell(
                    onTap: _pickImages,
                    child: Container(
                      width: 80.w,
                      height: 80.w,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Icon(
                        Icons.add_a_photo,
                        color: Colors.grey,
                        size: 28.sp,
                      ),
                    ),
                  ),
              ],
            ),

            SizedBox(height: 24.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange[800],
                    size: 18.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'รีวิวเขียนได้ครั้งเดียว ไม่สามารถแก้ไขได้',
                      style: styles(fontSize: 11.sp, color: Colors.orange[900]),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.send, color: Colors.white),
                label: Text(
                  _saving ? 'กำลังส่ง...' : 'ส่งรีวิว',
                  style: styles(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(backgroundColor: mainColor),
                onPressed: _saving ? null : _submit,
              ),
            ),
            SizedBox(height: 30.h),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h, top: 4.h),
      child: Text(
        text,
        style: styles(
          fontSize: 15.sp,
          fontWeight: FontWeight.bold,
          color: Colors.purple[900],
        ),
      ),
    );
  }

  Widget _ratingRow(String label, int value, ValueChanged<int> onChanged) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            label,
            style: styles(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: Colors.purple[900],
            ),
          ),
          Spacer(),
          ...List.generate(5, (i) {
            final star = i + 1;
            return GestureDetector(
              onTap: () => onChanged(star),
              child: Icon(
                star <= value ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 32.sp,
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}
