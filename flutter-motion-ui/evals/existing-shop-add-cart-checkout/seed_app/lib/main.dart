import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/product_list_screen.dart';
import 'state/catalog_model.dart';

void main() {
  runApp(ShopApp());
}

class ShopApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CatalogModel(),
      child: MaterialApp(
        title: 'Shop',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFF1565C0)),
          scaffoldBackgroundColor: Color(0xFFF5F6F8),
        ),
        home: ProductListScreen(),
      ),
    );
  }
}
