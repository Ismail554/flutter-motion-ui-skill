import 'package:flutter/material.dart';

import '../models/product.dart';

class CatalogModel extends ChangeNotifier {
  bool isLoading = false;
  bool hasError = false;
  List<Product> products = [];
  Set<String> favourites = {};

  Future<void> load() async {
    isLoading = true;
    hasError = false;
    notifyListeners();
    await Future.delayed(Duration(milliseconds: 600));
    products = [
      Product('p1', 'Trail Runner', 129.0, 'Light shoe for rough ground.', Color(0xFFE57373)),
      Product('p2', 'City Backpack', 89.5, '20 litre pack with laptop sleeve.', Color(0xFF64B5F6)),
      Product('p3', 'Steel Bottle', 24.0, 'Keeps drinks cold for 24 hours.', Color(0xFF81C784)),
      Product('p4', 'Wool Beanie', 19.0, 'Merino, one size.', Color(0xFFFFB74D)),
      Product('p5', 'Rain Shell', 159.0, 'Packable waterproof jacket.', Color(0xFF9575CD)),
      Product('p6', 'Camp Mug', 14.5, 'Enamel mug, 350 ml.', Color(0xFF4DB6AC)),
    ];
    isLoading = false;
    notifyListeners();
  }

  void toggleFavourite(String id) {
    if (favourites.contains(id)) {
      favourites.remove(id);
    } else {
      favourites.add(id);
    }
    notifyListeners();
  }
}
