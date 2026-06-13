import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:colae_cut/pages/product_detail.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:colae_cut/services/sevice.dart';

class HomeProductType extends StatefulWidget {
  final String vendorid;
  const HomeProductType({super.key, required this.vendorid});

  @override
  State<HomeProductType> createState() => _HomeProductTypeState();
}

class _HomeProductTypeState extends State<HomeProductType> {
  bool following = false;
  @override
  Widget build(BuildContext context) {
    final Stream<QuerySnapshot> productsStream = firestore
        .collection('products')
        .where('approved', isEqualTo: true)
        .where('vendorId', isEqualTo: widget.vendorid)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: productsStream,
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.hasError) {
          return const Text('Something went wrong');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'This category \n\n has no items yet !',
              textAlign: TextAlign.center,
              style: styles(
                fontSize: 26,
                color: Colors.yellow.shade900,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: snapshot.data!.docs.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 0.75,
            ),
            itemBuilder: (BuildContext context, int index) {
              final productData = snapshot.data!.docs[index];
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: GestureDetector(
                  onTap: productData['pqty'] <= 0
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ProductDetail(productData: productData),
                            ),
                          );
                        },
                  child: Column(
                    children: [
                      productData['pqty'] <= 0
                          ? Stack(
                              children: [
                                CachedNetworkImage(
                                  imageUrl: productData['imageUrl'][0],
                                  fit: BoxFit.cover,
                                  memCacheWidth: 400,
                                  placeholder: (_, __) => Container(color: Colors.grey.shade200),
                                  errorWidget: (_, __, ___) => Container(
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.broken_image, color: Colors.grey),
                                  ),
                                ),
                                Positioned.fill(
                                  child: Container(
                                    color: Colors.black87.withAlpha(150),
                                    child: Center(
                                      child: Text(
                                        'Out of Stock',
                                        style: styles(color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : CachedNetworkImage(
                              imageUrl: productData['imageUrl'][0],
                              fit: BoxFit.cover,
                              memCacheWidth: 400,
                              placeholder: (_, __) => Container(color: Colors.grey.shade200),
                              errorWidget: (_, __, ___) => Container(
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.broken_image, color: Colors.grey),
                              ),
                            ),
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 6,
                          top: 8,
                          right: 6,
                        ),
                        child: Text(
                          productData['proName'],
                          style: styles(fontSize: 12),
                        ),
                      ),
                      Text(
                        '฿${productData['price'].toStringAsFixed(2)}',
                        overflow: TextOverflow.ellipsis,
                        style: styles(fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
