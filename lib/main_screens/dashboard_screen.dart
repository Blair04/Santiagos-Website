import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Totals used by both the preorder summary card and status donut chart.
class PreorderSummary {
  final int pendingCount;
  final int completedCount;
  final int cancelledCount;

  const PreorderSummary({
    required this.pendingCount,
    required this.completedCount,
    required this.cancelledCount,
  });

  int get total => pendingCount + completedCount + cancelledCount;
}

/// A catalog item that reached the dashboard's low-stock threshold.
class FurnitureStockAlert {
  final String furnitureName;
  final int stockLeft;

  const FurnitureStockAlert({
    required this.furnitureName,
    required this.stockLeft,
  });
}

/// Aggregated preorder demand for one furniture product.
class TopPreorderItem {
  final String name;
  final int quantity;

  const TopPreorderItem({required this.name, required this.quantity});
}

/// Number of submitted receipts recorded for one calendar day.
class DailyPreorderActivity {
  final DateTime date;
  final int count;

  const DailyPreorderActivity({required this.date, required this.count});
}

/// Current stock grouped by catalog category for the compact ranked panel.
class CategoryStockMetric {
  final String name;
  final int stockUnits;

  const CategoryStockMetric({required this.name, required this.stockUnits});
}

/// Receipt activity available from the existing dashboard select.
class RecentReceiptMetric {
  final DateTime? issuedAt;
  final String status;

  const RecentReceiptMetric({required this.issuedAt, required this.status});
}

/// Loads live store statistics from Supabase and presents the admin dashboard.
class DashboardScreen extends StatefulWidget {
  final VoidCallback? onViewProducts;

  const DashboardScreen({super.key, this.onViewProducts});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const Color _background = Color(0xFFF9F6F0);
  static const Color _ink = Color(0xFF2C2221);
  static const Color _bronze = Color(0xFFC68B59);
  static const Color _slateBlue = Color(0xFF4A7A96);
  static const Color _sage = Color(0xFF438A5E);
  static const Color _mutedRed = Color(0xFFD9534F);
  static const Color _mutedOrange = Color(0xFFF0AD4E);

  final SupabaseClient _supabase = Supabase.instance.client;

  DashboardData? _dashboardData;
  Object? _loadError;
  bool _isLoading = true;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  /// Reads the dashboard tables together so one refresh produces one
  /// consistent set of statistics instead of updating cards independently.
  Future<void> _fetchDashboardData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      // These independent selects run in parallel. Relational fields on
      // PREORDER_ITEMS and RECEIPT are resolved through Supabase foreign keys.
      final responses = await Future.wait<dynamic>([
        _supabase.from('PREORDER').select('preorder_id, status, total_price'),
        _supabase
            .from('FURNITURE')
            .select('furniture_id, furniture_name, stock, category_id'),
        _supabase
            .from('CATEGORY')
            .select('category_id, category_name')
            .order('category_name'),
        _supabase.from('PREORDER_ITEMS').select('''
          quantity,
          furniture_id,
          FURNITURE ( furniture_name ),
          VARIANT (
            FURNITURE ( furniture_name )
          ),
          PREORDER ( status )
        '''),
        _supabase.from('RECEIPT').select('''
          issued_at,
          PREORDER ( status )
        '''),
      ]);

      // Keep Supabase access in this method and calculation rules in
      // DashboardData so the widget-building methods only render prepared data.
      final data = DashboardData.fromRows(
        preorderRows: _asRows(responses[0]),
        furnitureRows: _asRows(responses[1]),
        categoryRows: _asRows(responses[2]),
        preorderItemRows: _asRows(responses[3]),
        receiptRows: _asRows(responses[4]),
      );

      if (!mounted) return;
      setState(() {
        _dashboardData = data;
        _lastUpdated = DateTime.now();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _asRows(dynamic response) {
    if (response is! List) return <Map<String, dynamic>>[];
    return response
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: LayoutBuilder(
        builder: (context, viewportConstraints) {
          final viewportWidth = viewportConstraints.maxWidth;
          // Use the actual dashboard content width. This remains correct when
          // the desktop side menu takes part of the browser width.
          final horizontalPadding = viewportWidth < 600
              ? 18.0
              : viewportWidth < 1000
              ? 24.0
              : 40.0;

          return RefreshIndicator(
            color: _bronze,
            onRefresh: _fetchDashboardData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                viewportWidth < 600 ? 24 : 40,
                horizontalPadding,
                48,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(viewportWidth),
                      const SizedBox(height: 32),
                      if (_isLoading && _dashboardData == null)
                        _buildLoadingState()
                      else if (_loadError != null && _dashboardData == null)
                        _buildErrorState()
                      else
                        _buildDashboardContent(
                          _dashboardData ?? DashboardData.empty(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(double viewportWidth) {
    final isMobile = viewportWidth < 600;
    final now = DateTime.now();

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_greetingFor(now)}, Administrator! 👋',
          style: TextStyle(
            fontSize: isMobile ? 28 : 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: _ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Here’s an overview of Santiago’s Furniture.',
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w400,
          ),
        ),
        if (_lastUpdated != null) ...[
          const SizedBox(height: 7),
          Text(
            'Updated ${_formatTime(_lastUpdated!)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _ink.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                color: _bronze,
                size: 19,
              ),
              const SizedBox(width: 9),
              Text(
                _formatDate(now),
                style: const TextStyle(
                  color: _ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Tooltip(
          message: 'Refresh dashboard data',
          child: IconButton.filled(
            onPressed: _isLoading ? null : _fetchDashboardData,
            style: IconButton.styleFrom(
              backgroundColor: _ink,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _ink.withValues(alpha: 0.55),
              fixedSize: const Size(46, 46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: _isLoading
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, size: 20),
          ),
        ),
      ],
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [titleBlock, const SizedBox(height: 18), actions],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: titleBlock),
        const SizedBox(width: 24),
        actions,
      ],
    );
  }

  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 420),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _bronze),
            SizedBox(height: 18),
            Text(
              'Loading dashboard statistics...',
              style: TextStyle(
                color: Color(0xFF7A6865),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, color: _mutedRed, size: 44),
          const SizedBox(height: 14),
          const Text(
            'Dashboard data could not be loaded',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check the connection and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _fetchDashboardData,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  /// Composes the reference-style overview without changing the existing
  /// Supabase reads. Detailed preorder and stock panels remain available below.
  /// A refresh error keeps the previous data visible and adds a warning above
  /// it instead of replacing the dashboard with an empty error screen.
  Widget _buildDashboardContent(DashboardData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_loadError != null) ...[
          _buildStaleDataNotice(),
          const SizedBox(height: 18),
        ],
        _buildSummaryGrid(data),
        const SizedBox(height: 24),
        _buildResponsivePair(
          leftFlex: 3,
          rightFlex: 2,
          left: _buildSalesActivitySection(data),
          right: _buildInventoryOverviewSection(data),
        ),
        const SizedBox(height: 24),
        _buildResponsiveTriple(
          first: _buildMostPreorderedSection(data.topPreorders),
          second: _buildCategoryStockSection(data.categoryStock),
          third: _buildRecentReceiptsSection(data.recentReceipts),
        ),
        const SizedBox(height: 24),
        _buildLowStockBanner(data),
        const SizedBox(height: 30),
        _buildResponsivePair(
          left: _buildPreorderStatusSection(data.preorderStats),
          right: _buildStockAlertSection(data.stockAlerts),
        ),
      ],
    );
  }

  Widget _buildStaleDataNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: _mutedOrange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _mutedOrange.withValues(alpha: 0.35)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: _mutedOrange, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'The latest refresh failed. Previously loaded statistics are still displayed.',
              style: TextStyle(
                color: _ink,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(DashboardData data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        // Four columns fit wide desktops, two fit tablets, and one prevents
        // card content from being squeezed on mobile screens.
        final columns = availableWidth >= 1040
            ? 4
            : availableWidth >= 620
            ? 2
            : 1;
        final spacing = availableWidth < 600 ? 16.0 : 24.0;
        final cardWidth =
            (availableWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildSummaryCard(
                title: 'Total Sales',
                value: _formatCurrency(data.completedRevenue),
                subtext:
                    '${data.preorderStats.completedCount} completed preorders',
                icon: Icons.monetization_on_outlined,
                accentColor: _bronze,
                sparkValues: data.activitySparkline,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildSummaryCard(
                title: 'Total Products',
                value: '${data.totalFurnitureCount}',
                subtext: '${data.totalStockCount} catalog units recorded',
                icon: Icons.chair_alt_outlined,
                accentColor: _bronze,
                sparkValues: data.productSparkline,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildSummaryCard(
                title: 'Categories',
                value: '${data.categoryNames.length}',
                subtext: 'Active furniture categories',
                icon: Icons.inventory_2_outlined,
                accentColor: _slateBlue,
                sparkValues: data.categorySparkline,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildSummaryCard(
                title: 'Total Receipts',
                value: '${data.receiptCount}',
                subtext: 'Receipts recorded in the system',
                icon: Icons.receipt_long_outlined,
                accentColor: _sage,
                sparkValues: data.activitySparkline,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color accentColor,
    required List<double> sparkValues,
  }) {
    return Container(
      height: 210,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: _ink,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtext,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: accentColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 34,
            width: double.infinity,
            child: CustomPaint(
              painter: _SparklinePainter(
                values: sparkValues,
                color: accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsivePair({
    required Widget left,
    required Widget right,
    int leftFlex = 1,
    int rightFlex = 1,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Each analytics pair becomes a vertical stack before its text or
        // chart labels can overflow.
        if (constraints.maxWidth < 960) {
          return Column(children: [left, const SizedBox(height: 24), right]);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: leftFlex, child: left),
            const SizedBox(width: 24),
            Expanded(flex: rightFlex, child: right),
          ],
        );
      },
    );
  }

  Widget _buildResponsiveTriple({
    required Widget first,
    required Widget second,
    required Widget third,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1120
            ? 3
            : constraints.maxWidth >= 700
            ? 2
            : 1;
        const spacing = 24.0;
        final width =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(width: width, child: first),
            SizedBox(width: width, child: second),
            SizedBox(width: width, child: third),
          ],
        );
      },
    );
  }

  Widget _buildSalesActivitySection(DashboardData data) {
    return _buildContentSectionContainer(
      title: 'Sales Activity',
      subtitle:
          '${_formatCurrency(data.completedRevenue)} completed revenue • '
          'receipts issued over the last 7 days',
      child: SizedBox(
        height: 260,
        child: _WeeklyActivityChart(activity: data.weeklyActivity),
      ),
    );
  }

  Widget _buildInventoryOverviewSection(DashboardData data) {
    final lowStockOnly = math.max(data.lowStockCount - data.outOfStockCount, 0);
    final totalProducts = math.max(data.totalFurnitureCount, 1);

    return _buildContentSectionContainer(
      title: 'Inventory Overview',
      subtitle: '${data.totalFurnitureCount} products monitored',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final donut = SizedBox(
            width: 168,
            height: 168,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size.square(168),
                  painter: _DonutChartPainter(
                    values: [
                      data.inStockCount,
                      lowStockOnly,
                      data.outOfStockCount,
                    ],
                    colors: const [_sage, _mutedOrange, _mutedRed],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${data.totalFurnitureCount}',
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'PRODUCTS',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );

          final legend = Column(
            children: [
              _buildInventoryLegend(
                'In Stock',
                data.inStockCount,
                data.inStockCount / totalProducts * 100,
                _sage,
              ),
              const SizedBox(height: 16),
              _buildInventoryLegend(
                'Low Stock',
                lowStockOnly,
                lowStockOnly / totalProducts * 100,
                _mutedOrange,
              ),
              const SizedBox(height: 16),
              _buildInventoryLegend(
                'Out of Stock',
                data.outOfStockCount,
                data.outOfStockCount / totalProducts * 100,
                _mutedRed,
              ),
            ],
          );

          if (constraints.maxWidth < 420) {
            return Column(
              children: [donut, const SizedBox(height: 24), legend],
            );
          }
          return Row(
            children: [
              donut,
              const SizedBox(width: 24),
              Expanded(child: legend),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInventoryLegend(
    String label,
    int count,
    double percent,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          '$count (${percent.toStringAsFixed(1)}%)',
          style: const TextStyle(
            color: _ink,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryStockSection(List<CategoryStockMetric> categories) {
    final maximum = categories.fold<int>(
      0,
      (current, category) => math.max(current, category.stockUnits),
    );
    return _buildContentSectionContainer(
      title: 'Inventory by Category',
      subtitle: 'Recorded catalog units',
      child: categories.isEmpty
          ? _buildEmptySection(
              icon: Icons.category_outlined,
              message: 'No category inventory is available.',
            )
          : Column(
              children: [
                for (var index = 0; index < categories.length; index++) ...[
                  _buildCategoryStockRow(categories[index], maximum),
                  if (index != categories.length - 1)
                    const SizedBox(height: 17),
                ],
              ],
            ),
    );
  }

  Widget _buildCategoryStockRow(CategoryStockMetric category, int maximum) {
    final factor = maximum == 0 ? 0.0 : category.stockUnits / maximum;
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _bronze.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.chair_alt_outlined,
                color: _bronze,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${category.stockUnits}',
              style: const TextStyle(
                color: _ink,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: factor.clamp(0.0, 1.0),
            minHeight: 7,
            color: _bronze,
            backgroundColor: _bronze.withValues(alpha: 0.1),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentReceiptsSection(List<RecentReceiptMetric> receipts) {
    return _buildContentSectionContainer(
      title: 'Recent Transactions',
      subtitle: 'Latest receipt activity',
      child: receipts.isEmpty
          ? _buildEmptySection(
              icon: Icons.receipt_long_outlined,
              message: 'No recent receipts are available.',
            )
          : Column(
              children: [
                for (var index = 0; index < receipts.length; index++) ...[
                  _buildRecentReceiptRow(receipts[index]),
                  if (index != receipts.length - 1) const SizedBox(height: 11),
                ],
              ],
            ),
    );
  }

  Widget _buildRecentReceiptRow(RecentReceiptMetric receipt) {
    final isCompleted = _isCompletedStatus(receipt.status);
    final isCancelled = _isCancelledStatus(receipt.status);
    final statusColor = isCompleted
        ? _sage
        : isCancelled
        ? _mutedRed
        : _mutedOrange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFAF8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _bronze.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: _bronze,
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Receipt recorded',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  receipt.issuedAt == null
                      ? 'Date unavailable'
                      : _formatShortDate(receipt.issuedAt!),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              receipt.status.isEmpty ? 'Recorded' : receipt.status,
              style: TextStyle(
                color: statusColor,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockBanner(DashboardData data) {
    final message = data.lowStockCount == 0
        ? 'Inventory levels are healthy.'
        : 'You have ${data.lowStockCount} low stock '
              '${data.lowStockCount == 1 ? 'item' : 'items'}.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
      decoration: BoxDecoration(
        color: const Color(0xFFF6EDE3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _bronze.withValues(alpha: 0.12)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final copy = Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.75),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: _bronze,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      data.lowStockCount == 0
                          ? 'Continue monitoring catalog movement.'
                          : 'Please restock to avoid running out of inventory.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final button = FilledButton(
            onPressed: widget.onViewProducts,
            style: FilledButton.styleFrom(
              backgroundColor: _bronze,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            child: const Text(
              'View Low Stock',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          );

          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [copy, const SizedBox(height: 15), button],
            );
          }
          return Row(
            children: [
              Expanded(child: copy),
              const SizedBox(width: 20),
              button,
            ],
          );
        },
      ),
    );
  }

  Widget _buildPreorderStatusSection(PreorderSummary stats) {
    return _buildContentSectionContainer(
      title: 'Preorder Status Breakdown',
      subtitle: '${stats.total} tracked preorders',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final chart = SizedBox(
            width: 168,
            height: 168,
            child: Semantics(
              label:
                  '${stats.pendingCount} pending, ${stats.completedCount} completed, and ${stats.cancelledCount} cancelled preorders',
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size.square(168),
                    painter: _DonutChartPainter(
                      values: [
                        stats.pendingCount,
                        stats.completedCount,
                        stats.cancelledCount,
                      ],
                      colors: const [_bronze, _sage, _mutedRed],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${stats.total}',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      Text(
                        'TOTAL',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );

          final legend = Column(
            children: [
              _buildLegendItem(
                label: 'Pending',
                value: stats.pendingCount,
                color: _bronze,
              ),
              const SizedBox(height: 12),
              _buildLegendItem(
                label: 'Completed',
                value: stats.completedCount,
                color: _sage,
              ),
              const SizedBox(height: 12),
              _buildLegendItem(
                label: 'Cancelled',
                value: stats.cancelledCount,
                color: _mutedRed,
              ),
            ],
          );

          if (constraints.maxWidth < 480) {
            return Column(
              children: [chart, const SizedBox(height: 24), legend],
            );
          }

          return Row(
            children: [
              chart,
              const SizedBox(width: 28),
              Expanded(child: legend),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLegendItem({
    required String label,
    required int value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF9F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _ink,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMostPreorderedSection(List<TopPreorderItem> topPreorders) {
    return _buildContentSectionContainer(
      title: 'Most Pre-Ordered Furniture',
      subtitle: 'Demand based on non-cancelled preorder quantities',
      child: topPreorders.isEmpty
          ? _buildEmptySection(
              icon: Icons.bar_chart_rounded,
              message: 'No preorder item activity is available yet.',
            )
          : Column(
              children: [
                for (var index = 0; index < topPreorders.length; index++) ...[
                  _buildDemandBar(
                    item: topPreorders[index],
                    maximum: topPreorders.first.quantity,
                    rank: index + 1,
                  ),
                  if (index != topPreorders.length - 1)
                    const SizedBox(height: 18),
                ],
              ],
            ),
    );
  }

  Widget _buildDemandBar({
    required TopPreorderItem item,
    required int maximum,
    required int rank,
  }) {
    final factor = maximum == 0 ? 0.0 : item.quantity / maximum;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _bronze.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: _bronze,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${item.quantity} units',
              style: const TextStyle(
                color: Color(0xFF7A6865),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            minHeight: 9,
            value: factor.clamp(0.0, 1.0),
            color: _bronze,
            backgroundColor: const Color(0xFFF4EFEA),
          ),
        ),
      ],
    );
  }

  Widget _buildStockAlertSection(List<FurnitureStockAlert> stockAlerts) {
    return _buildContentSectionContainer(
      title: 'Low Stock Snapshot',
      subtitle: 'Catalog items with 5 or fewer units recorded',
      child: stockAlerts.isEmpty
          ? _buildEmptySection(
              icon: Icons.inventory_2_outlined,
              message: 'No low-stock catalog items were found.',
            )
          : Column(
              children: stockAlerts
                  .map(
                    (alert) => _buildStockAlertItem(
                      alert.furnitureName,
                      alert.stockLeft,
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildContentSectionContainer({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.02),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _ink,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildEmptySection({required IconData icon, required String message}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 34),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF9F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFB5A6A1), size: 34),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF7A6865),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockAlertItem(String productName, int count) {
    final isCritical = count <= 2;
    final statusColor = isCritical ? _mutedRed : _mutedOrange;
    final statusLabel = isCritical ? 'Critical Stock' : 'Low Stock';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF9F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _ink,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              '$count left',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: statusColor,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double value) {
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    final digits = parts.first;
    final buffer = StringBuffer();

    for (var index = 0; index < digits.length; index++) {
      final remaining = digits.length - index;
      buffer.write(digits[index]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }

    return '\u20B1${buffer.toString()}.${parts.last}';
  }

  String _greetingFor(DateTime time) {
    if (time.hour < 12) return 'Good morning';
    if (time.hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  String _formatDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatShortDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTime(DateTime time) {
    final hour = time.hour == 0
        ? 12
        : time.hour > 12
        ? time.hour - 12
        : time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

/// Immutable, display-ready statistics calculated from raw Supabase rows.
///
/// Keeping these calculations outside the widgets makes the rendering code
/// simpler and gives every card and graph the same normalized source values.
class DashboardData {
  final PreorderSummary preorderStats;
  final double completedRevenue;
  final int totalFurnitureCount;
  final int totalStockCount;
  final int inStockCount;
  final int lowStockCount;
  final int outOfStockCount;
  final int receiptCount;
  final List<double> activitySparkline;
  final List<double> productSparkline;
  final List<double> categorySparkline;
  final List<String> categoryNames;
  final List<CategoryStockMetric> categoryStock;
  final List<TopPreorderItem> topPreorders;
  final List<FurnitureStockAlert> stockAlerts;
  final List<DailyPreorderActivity> weeklyActivity;
  final List<RecentReceiptMetric> recentReceipts;

  const DashboardData({
    required this.preorderStats,
    required this.completedRevenue,
    required this.totalFurnitureCount,
    required this.totalStockCount,
    required this.inStockCount,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.receiptCount,
    required this.activitySparkline,
    required this.productSparkline,
    required this.categorySparkline,
    required this.categoryNames,
    required this.categoryStock,
    required this.topPreorders,
    required this.stockAlerts,
    required this.weeklyActivity,
    required this.recentReceipts,
  });

  factory DashboardData.empty() {
    final today = _dateOnly(DateTime.now());
    return DashboardData(
      preorderStats: const PreorderSummary(
        pendingCount: 0,
        completedCount: 0,
        cancelledCount: 0,
      ),
      completedRevenue: 0,
      totalFurnitureCount: 0,
      totalStockCount: 0,
      inStockCount: 0,
      lowStockCount: 0,
      outOfStockCount: 0,
      receiptCount: 0,
      activitySparkline: List<double>.filled(7, 0),
      productSparkline: List<double>.filled(7, 0),
      categorySparkline: List<double>.filled(7, 0),
      categoryNames: const [],
      categoryStock: const [],
      topPreorders: const [],
      stockAlerts: const [],
      weeklyActivity: List.generate(
        7,
        (index) => DailyPreorderActivity(
          date: today.subtract(Duration(days: 6 - index)),
          count: 0,
        ),
      ),
      recentReceipts: const [],
    );
  }

  factory DashboardData.fromRows({
    required List<Map<String, dynamic>> preorderRows,
    required List<Map<String, dynamic>> furnitureRows,
    required List<Map<String, dynamic>> categoryRows,
    required List<Map<String, dynamic>> preorderItemRows,
    required List<Map<String, dynamic>> receiptRows,
  }) {
    var pendingCount = 0;
    var completedCount = 0;
    var cancelledCount = 0;
    var completedRevenue = 0.0;

    // Normalize status text before counting so casing and accepted aliases do
    // not split one business state into several dashboard categories.
    for (final preorder in preorderRows) {
      final status = _normalizeStatus(preorder['status']);
      if (status == 'pending') {
        pendingCount++;
      } else if (_isCompletedStatus(status)) {
        completedCount++;
        completedRevenue += _asDouble(preorder['total_price']);
      } else if (_isCancelledStatus(status)) {
        cancelledCount++;
      }
    }

    var totalStockCount = 0;
    var inStockCount = 0;
    var lowStockCount = 0;
    var outOfStockCount = 0;
    final stockAlerts = <FurnitureStockAlert>[];
    final categoryById = <String, String>{
      for (final category in categoryRows)
        '${category['category_id']}':
            category['category_name']?.toString().trim() ?? 'Uncategorized',
    };
    final categoryStockByName = <String, int>{
      for (final name in categoryById.values) name: 0,
    };

    // Negative or invalid stock values are treated as zero. Items with five or
    // fewer units are retained for the low-stock panel.
    for (final furniture in furnitureRows) {
      final stock = math.max(_asInt(furniture['stock']), 0);
      final categoryName =
          categoryById['${furniture['category_id']}'] ?? 'Uncategorized';
      totalStockCount += stock;
      categoryStockByName.update(
        categoryName,
        (value) => value + stock,
        ifAbsent: () => stock,
      );

      if (stock <= 5) {
        lowStockCount++;
        if (stock == 0) outOfStockCount++;
        stockAlerts.add(
          FurnitureStockAlert(
            furnitureName:
                furniture['furniture_name']?.toString() ?? 'Unnamed furniture',
            stockLeft: stock,
          ),
        );
      } else {
        inStockCount++;
      }
    }

    stockAlerts.sort((left, right) {
      final stockComparison = left.stockLeft.compareTo(right.stockLeft);
      if (stockComparison != 0) return stockComparison;
      return left.furnitureName.compareTo(right.furnitureName);
    });

    final categoryNames = categoryRows
        .map((category) => category['category_name']?.toString().trim() ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
    final categoryStock =
        categoryStockByName.entries
            .map(
              (entry) =>
                  CategoryStockMetric(name: entry.key, stockUnits: entry.value),
            )
            .toList()
          ..sort((left, right) {
            final comparison = right.stockUnits.compareTo(left.stockUnits);
            if (comparison != 0) return comparison;
            return left.name.compareTo(right.name);
          });

    final preorderDemand = <String, int>{};
    // Demand combines direct furniture items and variant-backed items. Orders
    // with a cancelled status are excluded from the recommendation signal.
    for (final item in preorderItemRows) {
      final preorder = _relationMap(item['PREORDER'] ?? item['preorder']);
      final status = _normalizeStatus(preorder?['status']);
      if (_isCancelledStatus(status)) continue;

      final directFurniture = _relationMap(
        item['FURNITURE'] ?? item['furniture'],
      );
      final variant = _relationMap(item['VARIANT'] ?? item['variant']);
      final variantFurniture = _relationMap(
        variant?['FURNITURE'] ?? variant?['furniture'],
      );
      final furnitureName =
          directFurniture?['furniture_name']?.toString().trim() ??
          variantFurniture?['furniture_name']?.toString().trim() ??
          'Furniture ${item['furniture_id'] ?? ''}'.trim();

      preorderDemand.update(
        furnitureName,
        (value) => value + _asInt(item['quantity']),
        ifAbsent: () => _asInt(item['quantity']),
      );
    }

    final topPreorders =
        preorderDemand.entries
            .map(
              (entry) =>
                  TopPreorderItem(name: entry.key, quantity: entry.value),
            )
            .where((item) => item.quantity > 0)
            .toList()
          ..sort((left, right) {
            final quantityComparison = right.quantity.compareTo(left.quantity);
            if (quantityComparison != 0) return quantityComparison;
            return left.name.compareTo(right.name);
          });

    final today = _dateOnly(DateTime.now());
    // Pre-create all seven dates so days without receipts still render as
    // zero-height bars instead of disappearing from the activity graph.
    final weeklyCounts = <DateTime, int>{
      for (var index = 0; index < 7; index++)
        today.subtract(Duration(days: index)): 0,
    };

    for (final receipt in receiptRows) {
      final issuedAt = DateTime.tryParse(
        receipt['issued_at']?.toString() ?? '',
      )?.toLocal();
      if (issuedAt == null) continue;

      final date = _dateOnly(issuedAt);
      if (!weeklyCounts.containsKey(date)) continue;
      weeklyCounts[date] = (weeklyCounts[date] ?? 0) + 1;
    }

    final weeklyActivity = List.generate(7, (index) {
      final date = today.subtract(Duration(days: 6 - index));
      return DailyPreorderActivity(date: date, count: weeklyCounts[date] ?? 0);
    });
    final recentReceipts =
        receiptRows.map((receipt) {
          final preorder = _relationMap(
            receipt['PREORDER'] ?? receipt['preorder'],
          );
          return RecentReceiptMetric(
            issuedAt: DateTime.tryParse(
              receipt['issued_at']?.toString() ?? '',
            )?.toLocal(),
            status: _normalizeStatus(preorder?['status']),
          );
        }).toList()..sort((left, right) {
          if (left.issuedAt == null && right.issuedAt == null) return 0;
          if (left.issuedAt == null) return 1;
          if (right.issuedAt == null) return -1;
          return right.issuedAt!.compareTo(left.issuedAt!);
        });
    final activitySparkline = weeklyActivity
        .map((activity) => activity.count.toDouble())
        .toList();
    final productSparkline = List<double>.filled(
      7,
      furnitureRows.length.toDouble(),
    );
    final categorySparkline = List<double>.filled(
      7,
      categoryNames.length.toDouble(),
    );

    return DashboardData(
      preorderStats: PreorderSummary(
        pendingCount: pendingCount,
        completedCount: completedCount,
        cancelledCount: cancelledCount,
      ),
      completedRevenue: completedRevenue,
      totalFurnitureCount: furnitureRows.length,
      totalStockCount: totalStockCount,
      inStockCount: inStockCount,
      lowStockCount: lowStockCount,
      outOfStockCount: outOfStockCount,
      receiptCount: receiptRows.length,
      activitySparkline: activitySparkline,
      productSparkline: productSparkline,
      categorySparkline: categorySparkline,
      categoryNames: categoryNames,
      categoryStock: categoryStock.take(5).toList(),
      topPreorders: topPreorders.take(5).toList(),
      stockAlerts: stockAlerts.take(5).toList(),
      weeklyActivity: weeklyActivity,
      recentReceipts: recentReceipts.take(5).toList(),
    );
  }
}

/// Draws the preorder distribution without adding a chart dependency.
class _DonutChartPainter extends CustomPainter {
  final List<int> values;
  final List<Color> colors;

  const _DonutChartPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 13;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const strokeWidth = 18.0;
    final total = values.fold<int>(0, (sum, value) => sum + value);

    final backgroundPaint = Paint()
      ..color = const Color(0xFFF1EDE9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, backgroundPaint);

    if (total == 0) return;

    var startAngle = -math.pi / 2;
    for (var index = 0; index < values.length; index++) {
      if (values[index] == 0) continue;
      // Convert each status count into its proportional slice of a full circle.
      final sweepAngle = (values[index] / total) * math.pi * 2;
      final segmentPaint = Paint()
        ..color = colors[index]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, startAngle, sweepAngle, false, segmentPaint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.colors != colors;
  }
}

/// Draws the compact reference-style trend line used by each headline card.
class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  const _SparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.isEmpty) return;

    final minimum = values.reduce(math.min);
    final maximum = values.reduce(math.max);
    final spread = maximum - minimum;
    final step = values.length == 1 ? 0.0 : size.width / (values.length - 1);

    Offset pointAt(int index) {
      final factor = spread == 0 ? 0.5 : (values[index] - minimum) / spread;
      return Offset(
        index * step,
        size.height - (factor * (size.height - 7)) - 3.5,
      );
    }

    final line = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var index = 1; index < values.length; index++) {
      final point = pointAt(index);
      line.lineTo(point.dx, point.dy);
    }

    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.16),
            color.withValues(alpha: 0.01),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}

/// Scales the seven receipt counts against the busiest day in the period.
class _WeeklyActivityChart extends StatelessWidget {
  static const List<String> _dayNames = [
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
  ];

  final List<DailyPreorderActivity> activity;

  const _WeeklyActivityChart({required this.activity});

  @override
  Widget build(BuildContext context) {
    final maximum = activity.fold<int>(
      0,
      (current, day) => math.max(current, day.count),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < activity.length; index++) ...[
          Expanded(
            child: Semantics(
              label:
                  '${_dayNames[activity[index].date.weekday - 1]}, ${activity[index].count} preorder submissions',
              child: Column(
                children: [
                  Text(
                    '${activity[index].count}',
                    style: const TextStyle(
                      color: Color(0xFF7A6865),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final factor = maximum == 0
                            ? 0.04
                            : activity[index].count / maximum;
                        return Align(
                          alignment: Alignment.bottomCenter,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: constraints.maxWidth < 28
                                ? constraints.maxWidth * 0.55
                                : 24,
                            height: math.max(6, constraints.maxHeight * factor),
                            decoration: BoxDecoration(
                              color: index == activity.length - 1
                                  ? const Color(0xFFC68B59)
                                  : const Color(0xFFE2C5AA),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _dayNames[activity[index].date.weekday - 1],
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (index != activity.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

Map<String, dynamic>? _relationMap(dynamic value) {
  // PostgREST relations can be returned as one map or as a one-item list,
  // depending on the relationship cardinality. Normalize both shapes here.
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  if (value is List && value.isNotEmpty && value.first is Map) {
    return Map<String, dynamic>.from(value.first as Map);
  }
  return null;
}

String _normalizeStatus(dynamic value) {
  return value?.toString().trim().toLowerCase() ?? '';
}

bool _isCompletedStatus(String status) {
  return status == 'completed' || status == 'approved' || status == 'confirmed';
}

bool _isCancelledStatus(String status) {
  return status == 'cancelled' ||
      status == 'canceled' ||
      status == 'declined' ||
      status == 'denied';
}

int _asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime _dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}
