// ignore_for_file: no_leading_underscores_for_local_identifiers, unnecessary_cast

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:colae_cut/providers/active_order_provider.dart';
import 'package:colae_cut/widgets/bandner_widget.dart';
import 'package:colae_cut/widgets/category_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final String? buyerId = FirebaseAuth.instance.currentUser?.uid;
  late final Stream<QuerySnapshot> _categoryStream;
  int _categoryKey = 0;

  @override
  void initState() {
    super.initState();
    _categoryStream = FirebaseFirestore.instance
        .collection('categories')
        .snapshots();
    if (buyerId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Provider.of<ActiveOrderProvider>(
            context,
            listen: false,
          ).startListening(buyerId);
        }
      });
    }
  }

  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {
        _categoryKey++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            const SliverToBoxAdapter(child: BrandnerWidget()),
          ],
          body: StreamBuilder<QuerySnapshot>(
            stream: _categoryStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox.shrink();
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return const SizedBox.shrink();
              }
              final categories = snapshot.data!.docs;
              return CategoryWidget(
                key: ValueKey(_categoryKey),
                categories: categories,
                onCategorySelected: (_) {},
              );
            },
          ),
        ),
      ),
    );
  }
}
