import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/catalog_model.dart';
import 'product_detail_screen.dart';

class ProductListScreen extends StatefulWidget {
  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<CatalogModel>().load());
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<CatalogModel>();
    return Scaffold(
      appBar: AppBar(title: Text('Shop')),
      body: model.isLoading
          ? Center(child: CircularProgressIndicator())
          : model.hasError
              ? Center(child: Text('Something went wrong'))
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: model.products.length,
                  itemBuilder: (context, i) {
                    final p = model.products[i];
                    final fav = model.favourites.contains(p.id);
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ProductDetailScreen(product: p)),
                        );
                      },
                      child: Container(
                        margin: EdgeInsets.only(bottom: 12),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4))],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(color: p.color, borderRadius: BorderRadius.circular(10)),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                  SizedBox(height: 4),
                                  Text('\$${p.price.toStringAsFixed(2)}', style: TextStyle(color: Color(0xFF757575))),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => model.toggleFavourite(p.id),
                              child: AnimatedContainer(
                                duration: Duration(milliseconds: 200),
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: fav ? Color(0xFFFFEBEE) : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(fav ? Icons.favorite : Icons.favorite_border, color: fav ? Colors.red : Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
