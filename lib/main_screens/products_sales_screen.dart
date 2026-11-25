import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductsSalesScreen extends StatefulWidget {
  const ProductsSalesScreen({super.key});

  @override
  State<ProductsSalesScreen> createState() => _ProductsSalesScreenState();
}

class _SalesReport {
  final List<Map<String, dynamic>> rows;
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
  static const _darkBrown = Color(0xFF6D4C41);

  static const double _tableMinWidth = 480;

  final ScrollController _tableScrollController = ScrollController();

  bool _isLoading = true;
  _SalesReport? _report;
  Object? _error;

  double get _screenWidth => MediaQuery.of(context).size.width;
  bool get _isTablet => _screenWidth >= 600;
  bool get _isDesktop => _screenWidth >= 1024;

  double get _pagePadding => _isDesktop ? 36 : (_isTablet ? 24 : 16);
  double get _titleSize => _isDesktop ? 28 : (_isTablet ? 26 : 22);
  double get _subtitleSize => _isTablet ? 14 : 13;
  double get _sectionGap => _isDesktop ? 32 : (_isTablet ? 28 : 20);
  double get _contentMaxWidth => 1200;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tableScrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    _SalesReport? report;
    Object? error;
    try {
      final results = await Future.wait<Object?>([
        _fetchSales(),
        Future<void>.delayed(const Duration(milliseconds: 600)),
      ]);
      report = results[0] as _SalesReport;
    } catch (e) {
      error = e;
    }

    if (!mounted) return;
    setState(() {
      _report = report;
      _error = error;
      _isLoading = false;
    });
  }

  Future<_SalesReport> _fetchSales() async {
    final db = Supabase.instance.client;

    final orders =
        await db.from('PREORDER').select('preorder_id').ilike('status', 'completed');
    final orderIds =
        (orders as List).map((o) => o['preorder_id'] as int).toList();
    if (orderIds.isEmpty) return _SalesReport([], 0);

    final items = await db
        .from('PREORDER_ITEMS')
        .select(
            'furniture_id, variant_id, quantity, item_total_price, item_name')
        .inFilter('preorder_id', orderIds) as List;

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

    final Map<String, Map<String, dynamic>> grouped = {};
    for (final item in items) {
      final fid = furnitureIdOf(item);

      final savedName = (item['item_name'] as String?)?.trim();
      final hasSavedName = savedName != null && savedName.isNotEmpty;

      final key = hasSavedName
          ? '${fid ?? 'x'}|$savedName'
          : (fid?.toString() ?? 'unknown');
      final row = grouped.putIfAbsent(
        key,
        () => {
          'furniture_name': hasSavedName
              ? savedName
              : (fid != null ? (names[fid] ?? 'Unknown Item') : 'Unknown Item'),
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _brown));
    }

    if (_error != null) {
      return _message(
        icon: Icons.error_outline_rounded,
        title: "Couldn't load sales",
        body: "$_error",
        isError: true,
      );
    }

    final report = _report;
    if (report == null || report.rows.isEmpty) {
      return _message(
        icon: Icons.receipt_long_rounded,
        title: "No Sales Records Yet",
        body:
            "Completed preorder transactions, total volumes, and generated revenue streams will appear here once orders are processed.",
      );
    }

    return RefreshIndicator(
      color: _brown,
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: _contentMaxWidth),
            child: Padding(
              padding: EdgeInsets.all(_pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Sales",
                                style: TextStyle(
                                    fontSize: _titleSize,
                                    fontWeight: FontWeight.bold,
                                    color: _darkBrown)),
                            const SizedBox(height: 4),
                            Text(
                              "Track your completed preorder transaction volumes and total revenue streams.",
                              style: TextStyle(
                                  fontSize: _subtitleSize, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: _isTablet ? 16 : 8),
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: _load,
                          tooltip: 'Refresh',
                          icon: const Icon(Icons.refresh, color: Colors.brown),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: _isTablet ? 24 : 16),

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
                        SizedBox(width: _isDesktop ? 16 : 12),
                        Expanded(child: cards[1]),
                        SizedBox(width: _isDesktop ? 16 : 12),
                        Expanded(child: cards[2]),
                      ],
                    );
                  }),
                  SizedBox(height: _sectionGap),

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
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final bool compact = constraints.maxWidth < 700;

                          final Widget table = Table(
                            columnWidths: const {
                              0: FlexColumnWidth(3),
                              1: FlexColumnWidth(1.3),
                              2: FlexColumnWidth(2),
                              3: FlexColumnWidth(1.2),
                            },
                            children: [
                              _headerRow([
                                "Furniture Name",
                                "Quantity Sold",
                                "Total Income",
                                "Share"
                              ], compact),
                              ...report.rows.map((r) {
                                final income = r['income'] as double;
                                final share = report.totalIncome == 0
                                    ? 0.0
                                    : income / report.totalIncome * 100;
                                return _dataRow([
                                  r['furniture_name'].toString(),
                                  "${r['quantity']} unit/s",
                                  _peso(income),
                                  "${share.toStringAsFixed(1)}%",
                                ], compact);
                              }),
                            ],
                          );

                          if (constraints.maxWidth >= _tableMinWidth) {
                            return table;
                          }

                          return Scrollbar(
                            controller: _tableScrollController,
                            thumbVisibility: true,
                            trackVisibility: true,
                            child: SingleChildScrollView(
                              controller: _tableScrollController,
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.only(bottom: 12),
                              child: SizedBox(
                                width: _tableMinWidth,
                                child: table,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon,
      {bool highlight = false}) {
    final double cardPadding = _isDesktop ? 24 : (_isTablet ? 20 : 16);
    final double valueSize = highlight
        ? (_isDesktop ? 32 : (_isTablet ? 28 : 24))
        : (_isDesktop ? 26 : (_isTablet ? 24 : 22));

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(cardPadding),
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
            padding: EdgeInsets.all(_isTablet ? 10 : 8),
            decoration: BoxDecoration(
              color: highlight ? Colors.white.withOpacity(0.6) : _sand.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _muted, size: _isTablet ? 22 : 20),
          ),
          SizedBox(width: _isTablet ? 16 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: _isTablet ? 13 : 12,
                        color: const Color(0xFF5C4E4B),
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      style: TextStyle(
                          fontSize: valueSize,
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
        padding: EdgeInsets.symmetric(horizontal: _isTablet ? 32 : 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(_isTablet ? 24 : 18),
                  decoration: BoxDecoration(
                    color: _sand.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon,
                      size: _isTablet ? 64 : 48,
                      color: isError ? Colors.red : _muted),
                ),
                const SizedBox(height: 24),
                Text(title,
                    style: TextStyle(
                        fontSize: _isTablet ? 20 : 18,
                        fontWeight: FontWeight.bold,
                        color: _brown),
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
                  onPressed: _load,
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
        ),
      ),
    );
  }

  TableRow _headerRow(List<String> headers, bool compact) {
    return TableRow(
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1.5)),
      ),
      children: headers
          .map((h) => Padding(
                padding: EdgeInsets.symmetric(
                    vertical: compact ? 12 : 16, horizontal: compact ? 12 : 24),
                child: Text(h,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _muted,
                        fontSize: compact ? 12 : 14)),
              ))
          .toList(),
    );
  }

  TableRow _dataRow(List<String> d, bool compact) {
    final pad = EdgeInsets.symmetric(
        vertical: compact ? 14 : 18, horizontal: compact ? 12 : 24);
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5))),
      ),
      children: [
        Padding(
            padding: pad,
            child: Text(d[0],
                style: TextStyle(
                    fontSize: compact ? 13 : 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF222222)))),
        Padding(
            padding: pad,
            child: Text(d[1],
                style: TextStyle(
                    fontSize: compact ? 12 : 14,
                    color: const Color(0xFF555555)))),
        Padding(
            padding: pad,
            child: Text(d[2],
                style: TextStyle(
                    fontSize: compact ? 13 : 15,
                    fontWeight: FontWeight.bold,
                    color: _brown))),
        Padding(
            padding: pad,
            child: Text(d[3],
                style: TextStyle(fontSize: compact ? 12 : 14, color: _muted))),
      ],
    );
  }
}