import 'package:flutter/material.dart';

class ProductsSalesScreen extends StatelessWidget {
  const ProductsSalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Sample configuration matching your dynamic store pricing
    final List<Map<String, dynamic>> salesData = [
      {"name": "Bed Gray", "qty": 4, "price": 25000.00},
      {"name": "L-Shape Leather Sofa", "qty": 3, "price": 30000.00},
      {"name": "Cushioned Chair", "qty": 3, "price": 1999.00},
      {"name": "Wooden Table", "qty": 2, "price": 8500.00},
      {"name": "Wooden Cabinet", "qty": 2, "price": 2999.00},
    ];

    // Calculate total layout summary income dynamically
    final double totalIncome = salesData.fold(0, (sum, item) => sum + (item['qty'] * item['price']));

    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(36.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Title
            const Text(
              "Product Sales",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A3E3D),
              ),
            ),
            const Text(
              "Track your furniture transaction volumes and total revenue streams.",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // Top Gross Revenue Banner Container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFE3D5CA), // Warm theme primary background
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Total Gross Income Generated",
                    style: TextStyle(fontSize: 14, color: Color(0xFF5C4E4B), fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "₱ ${totalIncome.toStringAsFixed(2)}",
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF4A3E3D)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Elegant Main Data Table Sheet
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(3), // Furniture Title Column
                  1: FlexColumnWidth(1), // Quantity Count
                  2: FlexColumnWidth(2), // Total calculated income
                },
                children: [
                  // Structured Table Column Labels
                  _buildTableHeaderRow(["Furniture Name", "Quantity Sold", "Total Income"]),
                  
                  // Generating dynamic presentation table rows
                  ...salesData.map((item) {
                    double income = item['qty'] * item['price'];
                    return _buildTableRow([
                      item['name'].toString(),
                      "${item['qty']} units",
                      "₱ ${income.toStringAsFixed(2)}"
                    ]);
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Header Element Line Stylist
  TableRow _buildTableHeaderRow(List<String> headers) {
    return TableRow(
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1.5)),
      ),
      children: headers.map((header) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
          child: Text(
            header,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7D6E6A), fontSize: 14),
          ),
        );
      }).toList(),
    );
  }

  // Row Generator Injection Function
  TableRow _buildTableRow(List<String> data) {
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5))),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 24.0),
          child: Text(data[0], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF222222))),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 24.0),
          child: Text(data[1], style: const TextStyle(fontSize: 14, color: Color(0xFF555555))),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 24.0),
          child: Text(
            data[2], 
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF4A3E3D)),
          ),
        ),
      ],
    );
  }
}