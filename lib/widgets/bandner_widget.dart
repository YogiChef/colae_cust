// ignore_for_file: no_leading_underscores_for_local_identifiers
import 'package:cached_network_image/cached_network_image.dart';
import 'package:card_swiper/card_swiper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:colae_cut/services/sevice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer_animation/shimmer_animation.dart';

class BrandnerWidget extends StatefulWidget {
  final VoidCallback? onExploreBack;
  final bool isParentLoading;

  const BrandnerWidget({
    super.key,
    this.onExploreBack,
    this.isParentLoading = false,
  });

  @override
  State<BrandnerWidget> createState() => _BrandnerWidgetState();
}

class _BrandnerWidgetState extends State<BrandnerWidget> {
  late final Stream<QuerySnapshot> _bannerStream;

  @override
  void initState() {
    super.initState();
    _bannerStream = FirebaseFirestore.instance
        .collection('banners')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isParentLoading) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _bannerStream,
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.hasError) {
          return const Text('Something went wrong');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: SizedBox.shrink());
        }

        return Container(
          height: height * 0.22,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Swiper(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final bannerImage = snapshot.data!.docs[index];
              return ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: CachedNetworkImage(
                  imageUrl: bannerImage['image'],
                  placeholder: (context, url) => Shimmer(
                    colorOpacity: 0,
                    enabled: true,
                    direction: const ShimmerDirection.fromLTRB(),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.yellow.shade900.withAlpha(128),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                  fit: BoxFit.cover,
                ),
              );
            },
            autoplay: true,
            autoplayDelay: 5000,
            viewportFraction: 0.9,
            scale: 0.9,
            loop: true,
            pagination: SwiperPagination(
              alignment: Alignment.bottomCenter,
              builder: DotSwiperPaginationBuilder(
                color: Colors.white,
                activeColor: mainColor,

                size: 10.r,
                activeSize: 12.r,
              ),
            ),
          ),
        );
      },
    );
  }
}
