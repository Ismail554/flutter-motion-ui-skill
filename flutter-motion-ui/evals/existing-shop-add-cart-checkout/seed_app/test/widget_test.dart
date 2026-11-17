import 'package:flutter_test/flutter_test.dart';
import 'package:shop_app/main.dart';

void main() {
  testWidgets('catalog loads and a product opens', (tester) async {
    await tester.pumpWidget(ShopApp());
    await tester.pump(Duration(seconds: 1));
    expect(find.text('Trail Runner'), findsOneWidget);

    await tester.tap(find.text('Steel Bottle'));
    await tester.pumpAndSettle();
    expect(find.text('Add to cart'), findsOneWidget);
    expect(find.text('Keeps drinks cold for 24 hours.'), findsOneWidget);
  });
}
