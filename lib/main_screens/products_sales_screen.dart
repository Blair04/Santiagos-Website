import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductsSalesScreen extends StatefulWidget {
  const ProductsSalesScreen({super.key});

  @override
  State<ProductsSalesScreen> createState() => _ProductsSalesScreenState();
}

class _ProductsSalesScreenState extends State<ProductsSalesScreen> {
  late Future<List<Map<String, dynamic>>> _salesDataFuture;

  @override
  void initState() {
    super.initState();
    _salesDataFuture = fetchCompletedPreorders();
  }

  Future<List<Map<String, dynamic>>> fetchCompletedPreorders() async {
    try {
      final response = await Supabase.instance.client
          .from('PREORDER_ITEMS')
          .select('''
            quantity,
            item_total_price,
            VARIANT (
              FURNITURE (
                furniture_name
              )
            ),
            PREORDER!inner (
              status
            )
          ''')
          .eq('PREORDER.status', 'completed');

      final List<dynamic> data = response as List<dynamic>;

      return data.map((item) {
        final variant = item['VARIANT'] as Map<String, dynamic>? ?? {};
        final furniture = variant['FURNITURE'] as Map<String, dynamic>? ?? {};

        return {
          "furniture_name": furniture['furniture_name'] ?? 'Unknown Item',
          "quantity": item['quantity'] ?? 0,
          "item_total_price": (item['item_total_price'] as num?)?.toDouble() ?? 0.0,
        };
      }).toList();
    } catch (e) {
      throw Exception("Failed to fetch database records: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F5),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _salesDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF4A3E3D)),
            );
          } 
          
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  "${snapshot.error}",
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          } 

          // Enhanced Beautiful Empty State Interface
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3D5CA).withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        size: 64,
                        color: Color(0xFF7D6E6A),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "No Sales Records Yet",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4A3E3D),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Completed preorder transactions, total volumes, and generated revenue streams will appear here once orders are processed.",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _salesDataFuture = fetchCompletedPreorders();
                        });
                      },
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                      label: const Text(
                        "Check for Updates",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF4A3E3D),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final List<Map<String, dynamic>> salesData = snapshot.data!;

          final double totalIncome = salesData.fold(
            0.0, 
            (sum, item) => sum + (item['item_total_price'] as double),
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(36.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Product Sales",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A3E3D),
                  ),
                ),
                const Text(
                  "Track your completed preorder transaction volumes and total revenue streams.",
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 24),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3D5CA), 
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Total Gross Income Generated (Completed)",
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
                      0: FlexColumnWidth(3), 
                      1: FlexColumnWidth(1), 
                      2: FlexColumnWidth(2), 
                    },
                    children: [
                      _buildTableHeaderRow(["Furniture Name", "Quantity Sold", "Total Income"]),
                      
                      ...salesData.map((item) {
                        return _buildTableRow([
                          item['furniture_name'].toString(),
                          "${item['quantity']} units",
                          "₱ ${(item['item_total_price'] as double).toStringAsFixed(2)}"
                        ]);
                      }),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

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