import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductsSalesScreen extends StatefulWidget {
  const ProductsSalesScreen({super.key});

  @override
  State<ProductsSalesScreen> createState() => _ProductsSalesScreenState();
}

class _SalesReport {
  final List<Map<String, dynamic>> rows; // aggregated per furniture
  final int completedOrders;
  _SalesReport(this.rows, this.completedOrders);

  double get totalIncome =>
      rows.fold(0.0, (s, r) => s + (r['income'] as double));
  int get totalUnits => rows.fold(0, (s, r) => s + (r['quantity'] as int));
}

class _ProductsSalesScreenState extends State<ProductsSalesScreen> {
  static const _brown = Color(0xFF4A3E3D);
  static const _muted = Color(0xFF7D6E6A);
  static const _sand = Color(0xFFE3D5CA);

  late Future<_SalesReport> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchSales();
  }

  void _refresh() => setState(() => _future = _fetchSales());

  Future<_SalesReport> _fetchSales() async {
    final db = Supabase.instance.client;

    // 1) completed preorders
    final orders =
        await db.from('PREORDER').select('preorder_id').ilike('status', 'completed');
    final orderIds =
        (orders as List).map((o) => o['preorder_id'] as int).toList();
    if (orderIds.isEmpty) return _SalesReport([], 0);

    // 2) their items
    final items = await db
        .from('PREORDER_ITEMS')
        .select('furniture_id, variant_id, quantity, item_total_price')
        .inFilter('preorder_id', orderIds) as List;

    // 3) resolve furniture_id for items that only have a variant_id
    final variantIds = items
        .where((i) => i['furniture_id'] == null && i['variant_id'] != null)
        .map((i) => i['variant_id'] as int)
        .toSet()
        .toList();

    final Map<int, int> variantToFurniture = {};
    if (variantIds.isNotEmpty) {
      final variants = await db
          .from('VARIANT')
          .select('variant_id, furniture_id')
          .inFilter('variant_id', variantIds) as List;
      for (final v in variants) {
        if (v['furniture_id'] != null) {
          variantToFurniture[v['variant_id'] as int] = v['furniture_id'] as int;
        }
      }
    }

    int? furnitureIdOf(Map item) =>
        (item['furniture_id'] as int?) ??
        variantToFurniture[item['variant_id'] as int?];

    final furnitureIds = items
        .map((i) => furnitureIdOf(i))
        .whereType<int>()
        .toSet()
        .toList();

    // 4) names (active + archived products)
    final Map<int, String> names = {};
    if (furnitureIds.isNotEmpty) {
      final active = await db
          .from('FURNITURE')
          .select('furniture_id, furniture_name')
          .inFilter('furniture_id', furnitureIds) as List;
      for (final f in active) {
        names[f['furniture_id'] as int] = f['furniture_name'] as String;
      }
      try {
        final archived = await db
            .from('FURNITURE_ARCHIVE')
            .select('furniture_id, furniture_name')
            .inFilter('furniture_id', furnitureIds) as List;
        for (final f in archived) {
          names.putIfAbsent(
              f['furniture_id'] as int, () => '${f['furniture_name']} (archived)');
        }
      } catch (_) {}
    }

    // 5) aggregate per product
    final Map<String, Map<String, dynamic>> grouped = {};
    for (final item in items) {
      final fid = furnitureIdOf(item);
      final key = fid?.toString() ?? 'unknown';
      final row = grouped.putIfAbsent(
        key,
        () => {
          'furniture_name': fid != null ? (names[fid] ?? 'Unknown Item') : 'Unknown Item',
          'quantity': 0,
          'income': 0.0,
        },
      );
      row['quantity'] = (row['quantity'] as int) + ((item['quantity'] as num?)?.toInt() ?? 0);
      row['income'] = (row['income'] as double) + ((item['item_total_price'] as num?)?.toDouble() ?? 0.0);
    }

    final rows = grouped.values.toList()
      ..sort((a, b) => (b['income'] as double).compareTo(a['income'] as double));

    return _SalesReport(rows, orderIds.length);
  }

  String _peso(double v) {
    final parts = v.toStringAsFixed(2).split('.');
    final whole = parts[0].replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
    return '₱ $whole.${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F5),
      body: FutureBuilder<_SalesReport>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _brown));
          }

          if (snapshot.hasError) {
            return _message(
              icon: Icons.error_outline_rounded,
              title: "Couldn't load sales",
              body: "${snapshot.error}",
              isError: true,
            );
          }

          final report = snapshot.data!;
          if (report.rows.isEmpty) {
            return _message(
              icon: Icons.receipt_long_rounded,
              title: "No Sales Records Yet",
              body:
                  "Completed preorder transactions, total volumes, and generated revenue streams will appear here once orders are processed.",
            );
          }

          return RefreshIndicator(
            color: _brown,
            onRefresh: () async => _refresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Product Sales",
                                style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: _brown)),
                            SizedBox(height: 4),
                            Text(
                              "Track your completed preorder transaction volumes and total revenue streams.",
                              style: TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _refresh,
                        tooltip: 'Refresh',
                        icon: const Icon(Icons.refresh_rounded, color: _brown),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Summary cards
                  LayoutBuilder(builder: (context, c) {
                    final cards = [
                      _statCard("Total Gross Income (Completed)",
                          _peso(report.totalIncome), Icons.payments_rounded,
                          highlight: true),
                      _statCard("Units Sold", "${report.totalUnits}",
                          Icons.inventory_2_rounded),
                      _statCard("Completed Orders", "${report.completedOrders}",
                          Icons.check_circle_rounded),
                    ];
                    if (c.maxWidth < 700) {
                      return Column(
                        children: cards
                            .map((w) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: w))
                            .toList(),
                      );
                    }
                    return Row(
                      children: [
                        Expanded(flex: 2, child: cards[0]),
                        const SizedBox(width: 16),
                        Expanded(child: cards[1]),
                        const SizedBox(width: 16),
                        Expanded(child: cards[2]),
                      ],
                    );
                  }),
                  const SizedBox(height: 32),

                  // Table
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Table(
                        columnWidths: const {
                          0: FlexColumnWidth(3),
                          1: FlexColumnWidth(1.3),
                          2: FlexColumnWidth(2),
                          3: FlexColumnWidth(1.2),
                        },
                        children: [
                          _headerRow(["Furniture Name", "Quantity Sold",
                              "Total Income", "Share"]),
                          ...report.rows.map((r) {
                            final income = r['income'] as double;
                            final share = report.totalIncome == 0
                                ? 0.0
                                : income / report.totalIncome * 100;
                            return _dataRow([
                              r['furniture_name'].toString(),
                              "${r['quantity']} units",
                              _peso(income),
                              "${share.toStringAsFixed(1)}%",
                            ]);
                          }),
                        ],
                      ),
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

  Widget _statCard(String label, String value, IconData icon,
      {bool highlight = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: highlight ? _sand : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: highlight
            ? null
            : [
                BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: highlight ? Colors.white.withOpacity(0.6) : _sand.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _muted, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF5C4E4B),
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      style: TextStyle(
                          fontSize: highlight ? 32 : 26,
                          fontWeight: FontWeight.bold,
                          color: _brown)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _message({
    required IconData icon,
    required String title,
    required String body,
    bool isError = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _sand.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 64, color: isError ? Colors.red : _muted),
            ),
            const SizedBox(height: 24),
            Text(title,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: _brown),
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(body,
                style: TextStyle(
                    fontSize: 14,
                    color: isError ? Colors.red : Colors.grey,
                    height: 1.4),
                textAlign: TextAlign.center),
            const SizedBox(height: 32),
            TextButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
              label: const Text("Check for Updates",
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.white)),
              style: TextButton.styleFrom(
                backgroundColor: _brown,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TableRow _headerRow(List<String> headers) {
    return TableRow(
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1.5)),
      ),
      children: headers
          .map((h) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                child: Text(h,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: _muted, fontSize: 14)),
              ))
          .toList(),
    );
  }

  TableRow _dataRow(List<String> d) {
    const pad = EdgeInsets.symmetric(vertical: 18, horizontal: 24);
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5))),
      ),
      children: [
        Padding(
            padding: pad,
            child: Text(d[0],
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF222222)))),
        Padding(
            padding: pad,
            child: Text(d[1],
                style: const TextStyle(fontSize: 14, color: Color(0xFF555555)))),
        Padding(
            padding: pad,
            child: Text(d[2],
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: _brown))),
        Padding(
            padding: pad,
            child: Text(d[3],
                style: const TextStyle(fontSize: 14, color: _muted))),
      ],
    );
  }
}