import 'package:flutter_application_1/main_screens/dashboard_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'DashboardData prepares the existing query results for the new design',
    () {
      final now = DateTime.now().toIso8601String();
      final data = DashboardData.fromRows(
        preorderRows: [
          {'status': 'Pending', 'total_price': 100},
          {'status': 'Completed', 'total_price': 350},
          {'status': 'Cancelled', 'total_price': 200},
        ],
        furnitureRows: [
          {
            'furniture_id': 1,
            'furniture_name': 'Sofa',
            'stock': 12,
            'category_id': 1,
          },
          {
            'furniture_id': 2,
            'furniture_name': 'Chair',
            'stock': 4,
            'category_id': 1,
          },
          {
            'furniture_id': 3,
            'furniture_name': 'Table',
            'stock': 0,
            'category_id': 2,
          },
        ],
        categoryRows: [
          {'category_id': 1, 'category_name': 'Living Room'},
          {'category_id': 2, 'category_name': 'Dining Room'},
        ],
        preorderItemRows: [
          {
            'quantity': 3,
            'FURNITURE': {'furniture_name': 'Sofa'},
            'PREORDER': {'status': 'Completed'},
          },
          {
            'quantity': 2,
            'FURNITURE': {'furniture_name': 'Chair'},
            'PREORDER': {'status': 'Cancelled'},
          },
        ],
        receiptRows: [
          {
            'issued_at': now,
            'PREORDER': {'status': 'Completed'},
          },
          {
            'issued_at': now,
            'PREORDER': {'status': 'Pending'},
          },
        ],
      );

      expect(data.completedRevenue, 350);
      expect(data.totalFurnitureCount, 3);
      expect(data.totalStockCount, 16);
      expect(data.inStockCount, 1);
      expect(data.lowStockCount, 2);
      expect(data.outOfStockCount, 1);
      expect(data.receiptCount, 2);
      expect(data.activitySparkline.last, 2);
      expect(data.categoryStock.first.name, 'Living Room');
      expect(data.categoryStock.first.stockUnits, 16);
      expect(data.topPreorders.single.name, 'Sofa');
      expect(data.recentReceipts.length, 2);
    },
  );
}
