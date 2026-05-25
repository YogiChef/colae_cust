// ignore_for_file: unnecessary_underscores

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:colae_cut/pages/product_detail.dart';
import 'package:colae_cut/services/sevice.dart';

class SearchPage extends StatefulWidget {
  final bool isParentLoading;

  const SearchPage({super.key, this.isParentLoading = false});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String searchInput = '';
  final FocusNode _searchFocus = FocusNode();

  Timer? _debounce;
  List<QueryDocumentSnapshot> _results = [];
  bool _isSearching = false;

  void _hideKeyboard() {
    _searchFocus.unfocus();
    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  void _onSearchChanged(String value) {
    setState(() {
      searchInput = value;
      if (value.isEmpty) {
        _results = [];
        _isSearching = false;
      }
    });
    if (value.isEmpty) return;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _runSearch(value);
    });
  }

  Future<void> _runSearch(String query) async {
    if (!mounted) return;
    setState(() => _isSearching = true);
    try {
      final snapshot = await firestore
          .collection('products')
          .where('approved', isEqualTo: true)
          .get();
      final lower = query.toLowerCase();
      final filtered = snapshot.docs.where((e) {
        final proName = (e['proName'] as String?) ?? '';
        return proName.toLowerCase().contains(lower);
      }).toList();
      if (mounted) setState(() => _results = filtered);
    } catch (_) {
      if (mounted) setState(() => _results = []);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hideKeyboard();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isParentLoading) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: Padding(
          padding: EdgeInsets.only(top: 12.h),
          child: SizedBox(
            height: 50.h,
            child: CupertinoSearchTextField(
              itemSize: 24.h,
              backgroundColor: Colors.grey.shade200,
              focusNode: _searchFocus,
              autofocus: false,
              onChanged: _onSearchChanged,
            ),
          ),
        ),
      ),
      body: GestureDetector(
        onTap: _hideKeyboard,
        behavior: HitTestBehavior.opaque,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (searchInput.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120.w,
            height: 120.w,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              image: DecorationImage(image: AssetImage('images/search.png')),
            ),
          ),
          Center(
            child: Text(
              'Search for\nany products',
              style: styles(fontSize: 26.sp, color: mainColor),
            ),
          ),
        ],
      );
    }
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_results.isEmpty) {
      return const Center(child: Text('ไม่มีผลลัพธ์ที่ตรงกับการค้นหา'));
    }
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) => SearchModel(e: _results[index]),
    );
  }
}

class SearchModel extends StatelessWidget {
  final dynamic e;
  const SearchModel({super.key, required this.e});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: e['pqty'] <= 0
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductDetail(productData: e),
                ),
              );
            },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(5),
          ),
          width: double.infinity,
          height: 120.w,
          child: Row(
            children: [
              e['pqty'] <= 0
                  ? Stack(
                      children: [
                        SizedBox(
                          height: 90.w,
                          width: 100.w,
                          child: CachedNetworkImage(
                            imageUrl: e['imageUrl'][0] ?? '',
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: Colors.grey.shade200),
                            errorWidget: (_, __, ___) =>
                                const Icon(Icons.image_not_supported),
                          ),
                        ),
                        Positioned.fill(
                          child: Container(
                            alignment: Alignment.center,
                            color: Colors.black87.withAlpha(60),
                            child: Text(
                              'Out of Stock',
                              style: styles(
                                fontSize: 10.sp,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ClipRRect(
                      child: SizedBox(
                        height: 90.w,
                        width: 100.w,
                        child: CachedNetworkImage(
                          imageUrl: e['imageUrl'][0] ?? '',
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: Colors.grey.shade200),
                          errorWidget: (_, __, ___) =>
                              const Icon(Icons.image_not_supported),
                        ),
                      ),
                    ),
              Flexible(
                child: Padding(
                  padding: EdgeInsets.only(left: 12.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e['proName'] ?? 'ไม่มีชื่อสินค้า',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: styles(
                          fontSize: 14.sp,
                          color: Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        e['description'] ?? '',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        style: styles(
                          fontSize: 12.sp,
                          color: Colors.grey,
                          height: 1,
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Text(
                              'à¸¿ ${e['price'].toStringAsFixed(2)}',
                              style: styles(
                                fontSize: 12.sp,
                                color: e['pqty'] <= 10
                                    ? Colors.red
                                    : Colors.grey,
                                height: 1,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: 12.w, right: 12.w),
                              child: Icon(
                                Icons.shopping_basket_outlined,
                                size: 20.r,
                                color: e['pqty'] <= 10
                                    ? Colors.red
                                    : Colors.grey,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6.w),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                border: Border.all(
                                  width: 1,
                                  color: e['pqty'] <= 10
                                      ? Colors.red
                                      : Colors.grey,
                                ),
                              ),
                              child: Text(
                                e['pqty'].toString(),
                                style: styles(
                                  fontSize: 16.sp,
                                  color: e['pqty'] <= 10
                                      ? Colors.red
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
