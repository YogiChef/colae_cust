import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:colae_cut/models/category_model.dart';
import 'package:colae_cut/services/sevice.dart';

class CategoryController extends GetxController {
  RxList<CategoryModels> category = <CategoryModels>[].obs;

  @override
  void onInit() {
    _fetchCategories();
    super.onInit();
  }

  void _fetchCategories() {
    firestore.collection('categories').snapshots().listen((
      QuerySnapshot querySnapshot,
    ) {
      category.assignAll(
        querySnapshot.docs.map((e) {
          final data = e.data() as Map<String, dynamic>;

          return CategoryModels(
            categoryImage: data['image'],
            categoryName: data['categoryName'],
          );
        }).toList(),
      );
    });
  }
}
