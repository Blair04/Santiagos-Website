import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

/// Number of generated pre-order slips recorded for one calendar day.
class DailyPreorderActivity {
  final DateTime date;
  final int count;
  final double amount;

  const DailyPreorderActivity({
    required this.date,
    required this.count,
    this.amount = 0,
  });
}

/// Completed-order revenue grouped by preorder date for the trend chart.
class DailyRevenueMetric {
  final DateTime date;
  final double amount;
  const DailyRevenueMetric({required this.date, required this.amount});
}

/// Current stock grouped by catalog category for the compact ranked panel.
class CategoryStockMetric {
  final String name;
  final int stockUnits;

  const CategoryStockMetric({required this.name, required this.stockUnits});
}

class CategoryPerformanceMetric {
  final String name;
  final double revenue;
  final int unitsSold;
  final int preorderCount;

  const CategoryPerformanceMetric({
    required this.name,
    required this.revenue,
    required this.unitsSold,
    required this.preorderCount,
  });
}

class TopFurnitureRevenueMetric {
  final String name;
  final double revenue;
  final List<double> weeklyRevenue;

  const TopFurnitureRevenueMetric({
    required this.name,
    required this.revenue,
    required this.weeklyRevenue,
  });
}

/// Receipt activity available from the existing dashboard select.
class RecentReceiptMetric {
  final String receiptId;
  final String customerName;
  final DateTime? issuedAt;
  final double totalAmount;
  final String status;

  const RecentReceiptMetric({
    required this.receiptId,
    required this.customerName,
    required this.issuedAt,
    required this.totalAmount,
    required this.status,
  });
}

/// Loads live store statistics from Supabase and presents the admin dashboard.
class DashboardScreen extends StatefulWidget {
  final VoidCallback? onViewProducts;
  final VoidCallback? onViewSales;
  final VoidCallback? onViewReceipts;

  const DashboardScreen({
    super.key,
    this.onViewProducts,
    this.onViewSales,
    this.onViewReceipts,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const Color _background = Color(0xFFF9F6F0);
  static const Color _ink = Color(0xFF2C2221);
  static const Color _bronze = Color(0xFFC68B59);
  static const Color _slateBlue = Color(0xFF4A7A96);
  static const Color _darkBrown = Color(0xFF6D4C41);
  static const Color _sage = Color(0xFF438A5E);
  static const Color _mutedRed = Color(0xFFD9534F);
  static const Color _mutedOrange = Color(0xFFF0AD4E);

  final SupabaseClient _supabase = Supabase.instance.client;

  DashboardData? _dashboardData;
  Object? _loadError;
  bool _isLoading = true;
  DateTime? _lastUpdated;
  RealtimeChannel? _dashboardRealtimeChannel;
  bool _realtimeRefreshInProgress = false;
  bool _realtimeRefreshPending = false;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    _subscribeToDashboardChanges();
  }

  /// Listen for database changes so completed orders and stock edits are
  /// reflected without requiring the manager to press Refresh.
  void _subscribeToDashboardChanges() {
    final channel = _supabase.channel('dashboard-live-updates');

    for (final table in [
      'PREORDER',
      'PREORDER_ITEMS',
      'RECEIPT',
      'FURNITURE',
      'CATEGORY',
    ]) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => _refreshAfterRealtimeChange(),
      );
    }

    _dashboardRealtimeChannel = channel;
    channel.subscribe();
  }

  Future<void> _refreshAfterRealtimeChange() async {
    if (_realtimeRefreshInProgress) {
      _realtimeRefreshPending = true;
      return;
    }

    _realtimeRefreshInProgress = true;
    do {
      _realtimeRefreshPending = false;
      await _fetchDashboardData(showLoading: false);
    } while (_realtimeRefreshPending && mounted);
    _realtimeRefreshInProgress = false;
  }

  @override
  void dispose() {
    final channel = _dashboardRealtimeChannel;
    if (channel != null) {
      _supabase.removeChannel(channel);
    }
    super.dispose();
  }

  /// Reads the dashboard tables together so one refresh produces one
  /// consistent set of statistics instead of updating cards independently.
  Future<void> _fetchDashboardData({bool showLoading = true}) async {
    if (mounted && showLoading) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      // These independent selects run in parallel. Relational fields on
      // PREORDER_ITEMS and RECEIPT are resolved through Supabase foreign keys.
      final responses = await Future.wait<dynamic>([
        _supabase.from('PREORDER').select('preorder_id, status, total_price, preordered_at'),
        _supabase
            .from('FURNITURE')
            .select('furniture_id, furniture_name, stock, category_id')
            .eq('is_archived', false),
        _supabase
            .from('CATEGORY')
            .select('category_id, category_name')
            .order('category_name'),
        _supabase.from('PREORDER_ITEMS').select('''
          quantity,
          furniture_id,
          preorder_id,
          FURNITURE ( furniture_name, price, category_id ),
          VARIANT (
            FURNITURE ( furniture_name, price, category_id )
          ),
          PREORDER ( status, preordered_at )
        '''),
        _supabase.from('RECEIPT').select('''
          receipt_id,
          issued_at,
          preorder_id,
          PREORDER (
            status,
            total_price,
            customer_id,
            CUSTOMER ( full_name )
          )
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
        _loadError = null;
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
          '${_greetingFor(now)}, Manager! 👋',
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
      ],
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_lastUpdated != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFECE5DE)),
              boxShadow: [
                BoxShadow(
                  color: _ink.withValues(alpha: 0.035),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                
Icon(
  Icons.schedule_rounded,
  size: 17,
  color: Colors.grey.shade600,
),
const SizedBox(width: 8),
Text(
  'Updated ${_formatTime(_lastUpdated!)}',
  style: TextStyle(
    fontSize: 14,
    color: Colors.grey.shade700,
    fontWeight: FontWeight.w600,
  ),
),

              ],
            ),
          ),
          const SizedBox(width: 12),
        ],
        Tooltip(
          message: 'Refresh dashboard data',
          child: IconButton.filled(
            onPressed: _isLoading ? null : _fetchDashboardData,
            style: IconButton.styleFrom(
              backgroundColor: _darkBrown,
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
          right: _buildOrderSlipStatusSection(data.preorderStats),
        ),
        const SizedBox(height: 24),
        _buildStockOverview(data),
        const SizedBox(height: 24),
        _buildResponsivePair(
          leftFlex: 3,
          rightFlex: 2,
          left: _buildRecentReceiptsSection(data.recentReceipts),
          right: _buildCategoryPerformanceSection(data.categoryPerformance),
        ),
      ],
    );
  }

  Widget _buildPreorderCountCard({
    required String title,
    required int count,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return _buildContentSectionContainer(
      title: title,
      subtitle: subtitle,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 20),
          Text(
            '$count',
            style: const TextStyle(
              color: _ink,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Text(
            'orders',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueTrendsSection(DashboardData data) {
    return _buildContentSectionContainer(
      title: 'Revenue Trends',
      subtitle: 'Completed pre-orders grouped by preorder date · Last 7 days',
      child: SizedBox(
        height: 260,
        child: _WeeklyRevenueChart(activity: data.weeklyRevenue),
      ),
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
        final spacing = constraints.maxWidth < 600 ? 16.0 : 24.0;
        // Three summary cards share one row on desktop/tablet widths.
        // On narrow screens, cards stack or use two columns as space allows.
        final columns = constraints.maxWidth >= 800 ? 3 : 1;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: width,
              child: _buildSummaryCard(
                title: 'Total Sales',
                value: _formatCurrency(data.completedRevenue),
                subtext: '${data.preorderStats.completedCount} completed slips',
                icon: Icons.monetization_on_outlined,
                accentColor: _bronze,
                sparkValues: data.activitySparkline,
                showSparkline: true,
                onTap: widget.onViewSales,
              ),
            ),
            SizedBox(
              width: width,
              child: _buildSummaryCard(
                title: 'Total Products',
                value: '${data.totalFurnitureCount}',
                subtext: 'Active, non-archived furniture',
                icon: Icons.chair_alt_outlined,
                accentColor: _sage,
                sparkValues: const [],
                showSparkline: false,
                onTap: widget.onViewProducts,
              ),
            ),
            SizedBox(
              width: width,
              child: _buildSummaryCard(
                title: 'Top Furniture Product',
                value: data.topFurniture.name.isEmpty
                    ? 'No sales yet'
                    : data.topFurniture.name,
                subtext: 'Top product revenue: ${_formatCurrency(data.topFurniture.revenue)}',
                icon: Icons.star_outline_rounded,
                accentColor: _slateBlue,
                sparkValues: const [],
                showSparkline: false,
                valueFontSize: 19,
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
    bool showSparkline = true,
    double valueFontSize = 26,
    VoidCallback? onTap,
  }) {
    final card = Container(
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
              if (onTap != null)
                SizedBox(
                  width: 34,
                  height: 34,
                  child: IconButton(
                    tooltip: 'Open $title',
                    onPressed: onTap,
                    padding: EdgeInsets.zero,
                    splashRadius: 18,
                    style: IconButton.styleFrom(
                      foregroundColor: accentColor,
                      backgroundColor: Colors.transparent,
                      hoverColor: accentColor.withValues(alpha: 0.12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
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
              maxLines: 1,
              style: TextStyle(
                fontSize: valueFontSize,
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
          if (showSparkline)
            SizedBox(
              height: 34,
              width: double.infinity,
              child: CustomPaint(
                painter: _SparklinePainter(
                  values: sparkValues.isEmpty ? const [0, 0, 0, 0, 0, 0, 0] : sparkValues,
                  color: accentColor,
                ),
              ),
            )
          else
            const SizedBox(height: 34),
        ],
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: card,
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
        if (constraints.maxWidth < 760) {
          return Column(children: [left, const SizedBox(height: 24), right]);
        }

        return _EqualHeightRow(
          flexes: [leftFlex, rightFlex],
          spacing: 24,
          children: [left, right],
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
        // Stack all three rather than wrapping 2 + 1, so the row never ends
        // up with one card twice as wide as the others.
        if (constraints.maxWidth < 800) {
          return Column(
            children: [
              first,
              const SizedBox(height: 24),
              second,
              const SizedBox(height: 24),
              third,
            ],
          );
        }

        return _EqualHeightRow(
          flexes: const [1, 1, 1],
          spacing: 24,
          children: [first, second, third],
        );
      },
    );
  }

  Widget _buildSalesActivitySection(DashboardData data) {
    return _buildContentSectionContainer(
      title: 'Sales Activity',
      subtitle: 'Completed order slips and money earned · Last 7 days',
      child: SizedBox(
        height: 260,
        child: _WeeklyActivityChart(activity: data.weeklyActivity),
      ),
    );
  }

  Widget _buildOrderSlipStatusSection(PreorderSummary stats) {
    return _buildContentSectionContainer(
      title: 'Order Slip Status Breakdown',
      subtitle: '${stats.total} tracked order slips',
      child: _buildStatusDonut(stats),
    );
  }

  Widget _buildStatusDonut(PreorderSummary stats) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final chart = SizedBox(
          width: 168,
          height: 168,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size.square(168),
                painter: _DonutChartPainter(
                  values: [stats.pendingCount, stats.completedCount, stats.cancelledCount],
                  colors: const [_bronze, _sage, _mutedRed],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${stats.total}',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _ink)),
                  Text('SLIPS',
                      style: TextStyle(fontSize: 9, letterSpacing: 1, fontWeight: FontWeight.w700, color: Colors.grey.shade500)),
                ],
              ),
            ],
          ),
        );
        final legend = Column(
          children: [
            _buildLegendItem(label: 'Pending', value: stats.pendingCount, color: _bronze),
            const SizedBox(height: 10),
            _buildLegendItem(label: 'Completed', value: stats.completedCount, color: _sage),
            const SizedBox(height: 10),
            _buildLegendItem(label: 'Cancelled', value: stats.cancelledCount, color: _mutedRed),
          ],
        );
        if (constraints.maxWidth < 480) {
          return Column(children: [chart, const SizedBox(height: 20), legend]);
        }
        return Row(children: [chart, const SizedBox(width: 20), Expanded(child: legend)]);
      },
    );
  }

  Widget _buildInventoryOverviewSection(DashboardData data) {
    final lowStockOnly = math.max(data.lowStockCount - data.outOfStockCount, 0);
    final totalProducts = math.max(data.totalFurnitureCount, 1);

    return _buildContentSectionContainer(
      title: 'Inventory Status',
      subtitle: '${data.totalFurnitureCount} active, non-archived products monitored',
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
      subtitle: 'Latest order slips · showing up to 5 transactions',
      trailing: TextButton.icon(
        onPressed: widget.onViewReceipts,
        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
        label: const Text('View all'),
        style: TextButton.styleFrom(
          foregroundColor: _darkBrown,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (receipts.isEmpty)
            _buildEmptySection(
              icon: Icons.receipt_long_outlined,
              message: 'No recent transactions are available.',
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll(const Color(0xFFFBF8F5)),
                columns: const [
                  DataColumn(label: Text('Slip ID')),
                  DataColumn(label: Text('Customer')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Total amount')),
                  DataColumn(label: Text('Status')),
                ],
                rows: receipts.map((receipt) {
                  
            final normalizedStatus = receipt.status.trim().toLowerCase();
            final status = normalizedStatus.isEmpty? 'Pending'
             : '${normalizedStatus[0].toUpperCase()}${normalizedStatus.substring(1)}';

            final color = _isCompletedStatus(normalizedStatus)
            ? _sage: _isCancelledStatus(normalizedStatus)
            ? _mutedRed : _bronze;

                  return DataRow(cells: [
                    DataCell(Text('#${receipt.receiptId}')),
                    DataCell(Text(receipt.customerName, overflow: TextOverflow.ellipsis)),
                    DataCell(Text(receipt.issuedAt == null
                        ? '—'
                        : _formatShortDate(receipt.issuedAt!))),
                    DataCell(Text(_formatCurrency(receipt.totalAmount))),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
                    )),
                  ]);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryPerformanceSection(List<CategoryPerformanceMetric> categories) {
    return _buildContentSectionContainer(
      title: 'Category Performance',
      subtitle: 'Revenue and completed preorder activity by category',
      child: categories.isEmpty
          ? _buildEmptySection(
              icon: Icons.category_outlined,
              message: 'No completed category sales are available.',
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    // Fill the snapshot width when the columns fit, but allow
                    // horizontal scrolling if a narrow window needs more room.
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    
child: DataTable(
  horizontalMargin: 10,
  columnSpacing: 18,
  headingRowHeight: 46,
  dataRowMinHeight: 48,
  dataRowMaxHeight: 58,
  headingRowColor: const WidgetStatePropertyAll(
    Color(0xFFFBF8F5),
  ),
  columns: const [
    DataColumn(label: Text('Category')),
    DataColumn(label: Text('Total Revenue')),
    DataColumn(
      columnWidth: FixedColumnWidth(100),
      label: Center(child: Text('Units Sold')),
    ),
    DataColumn(
      columnWidth: FixedColumnWidth(130),
      label: Center(child: Text('Total Pre-orders')),
    ),
  ],
  rows: categories.map((category) => DataRow(
    cells: [
      DataCell(
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150),
          child: Text(
            category.name,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      DataCell(Text(_formatCurrency(category.revenue))),
      DataCell(
        SizedBox(
          width: double.infinity,
          child: Center(
            child: Text('${category.unitsSold}'),
          ),
        ),
      ),
      DataCell(
        SizedBox(
          width: double.infinity,
          child: Center(
            child: Text('${category.preorderCount}'),
          ),
        ),
      ),
    ],
  )).toList(),
),

                  ),
                );
              },
            ),
    );
  }


Widget _buildStockOverview(DashboardData data) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: _ink.withValues(alpha: 0.025),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Card title
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFFBF8F5),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                color: _darkBrown,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Stock Overview',
              style: TextStyle(
                color: _ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),

        const SizedBox(height: 22),

        // Total stock count
        Text(
          data.totalStockCount.toString(),
          style: const TextStyle(
            color: _ink,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Total units currently in stock',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 20),
        Divider(
          color: Colors.grey.shade200,
          height: 1,
        ),
        const SizedBox(height: 16),

        // Bottom action row
        LayoutBuilder(
          builder: (context, constraints) {
            final action = FilledButton.icon(
              onPressed: widget.onViewProducts,
              icon: const Icon(
                Icons.arrow_forward_rounded,
                size: 16,
              ),
              label: const Text(
                'View Stock',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _darkBrown,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );

            if (constraints.maxWidth < 420) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Manage your furniture inventory',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: action,
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child: Text(
                    'Manage your furniture inventory',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                action,
              ],
            );
          },
        ),
      ],
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
    Widget? trailing,
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
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
      'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec',];
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
  final List<DailyRevenueMetric> weeklyRevenue;
  final List<RecentReceiptMetric> recentReceipts;
  final List<CategoryPerformanceMetric> categoryPerformance;
  final TopFurnitureRevenueMetric topFurniture;

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
    required this.weeklyRevenue,
    required this.recentReceipts,
    required this.categoryPerformance,
    required this.topFurniture,
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
      weeklyRevenue: List.generate(7, (index) => DailyRevenueMetric(date: today.subtract(Duration(days: 6 - index)), amount: 0)),
      weeklyActivity: List.generate(
        7,
        (index) => DailyPreorderActivity(
          date: today.subtract(Duration(days: 6 - index)),
          count: 0,
        ),
      ),
      recentReceipts: const [],
      categoryPerformance: const [],
      topFurniture: const TopFurnitureRevenueMetric(
        name: '',
        revenue: 0,
        weeklyRevenue: [0, 0, 0, 0, 0, 0, 0],
      ),
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

    // The donut is an order-slip breakdown, so count statuses from RECEIPT
    // rows rather than counting every preorder record in the database.
    pendingCount = 0;
    completedCount = 0;
    cancelledCount = 0;
    completedRevenue = 0;
    for (final receipt in receiptRows) {
      final preorder = _relationMap(receipt['PREORDER'] ?? receipt['preorder']);
      final status = _normalizeStatus(preorder?['status']);
      if (status == 'pending') {
        pendingCount++;
      } else if (_isCompletedStatus(status)) {
        completedCount++;
        completedRevenue += _asDouble(preorder?['total_price']);
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

    final completedCategoryRevenue = <String, double>{};
    final completedCategoryUnits = <String, int>{};
    final completedCategoryPreorders = <String, Set<String>>{};
    final furnitureRevenue = <String, double>{};
    final furnitureDailyRevenue = <String, Map<DateTime, double>>{};
    final today = _dateOnly(DateTime.now());
    final weekDates = List.generate(
      7,
      (index) => today.subtract(Duration(days: 6 - index)),
    );

    for (final item in preorderItemRows) {
      final preorder = _relationMap(item['PREORDER'] ?? item['preorder']);
      if (!_isCompletedStatus(_normalizeStatus(preorder?['status']))) continue;

      final directFurniture = _relationMap(item['FURNITURE'] ?? item['furniture']);
      final variant = _relationMap(item['VARIANT'] ?? item['variant']);
      final variantFurniture = _relationMap(variant?['FURNITURE'] ?? variant?['furniture']);
      final furniture = directFurniture ?? variantFurniture;
      final furnitureName = furniture?['furniture_name']?.toString().trim().isNotEmpty == true
          ? furniture!['furniture_name'].toString().trim()
          : 'Unknown Furniture';
      final quantity = _asInt(item['quantity']);
      final lineRevenue = quantity * _asDouble(furniture?['price']);
      final categoryName = categoryById['${furniture?['category_id']}'] ?? 'Uncategorized';

      furnitureRevenue.update(furnitureName, (value) => value + lineRevenue,
          ifAbsent: () => lineRevenue);
      completedCategoryRevenue.update(categoryName, (value) => value + lineRevenue,
          ifAbsent: () => lineRevenue);
      completedCategoryUnits.update(categoryName, (value) => value + quantity,
          ifAbsent: () => quantity);
      final preorderId = (item['preorder_id'] ?? preorder?['preorder_id'] ?? '').toString();
      completedCategoryPreorders.putIfAbsent(categoryName, () => <String>{});
      if (preorderId.isNotEmpty) completedCategoryPreorders[categoryName]!.add(preorderId);

      final placedAt = DateTime.tryParse(preorder?['preordered_at']?.toString() ?? '')?.toLocal();
      if (placedAt != null) {
        final date = _dateOnly(placedAt);
        furnitureDailyRevenue.putIfAbsent(furnitureName, () => <DateTime, double>{});
        if (weekDates.contains(date)) {
          furnitureDailyRevenue[furnitureName]!.update(date, (value) => value + lineRevenue,
              ifAbsent: () => lineRevenue);
        }
      }
    }

    final categoryPerformance = completedCategoryRevenue.entries.map((entry) {
      return CategoryPerformanceMetric(
        name: entry.key,
        revenue: entry.value,
        unitsSold: completedCategoryUnits[entry.key] ?? 0,
        preorderCount: completedCategoryPreorders[entry.key]?.length ?? 0,
      );
    }).toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    final topFurnitureEntry = furnitureRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topFurnitureName = topFurnitureEntry.isEmpty ? '' : topFurnitureEntry.first.key;
    final topFurniture = TopFurnitureRevenueMetric(
      name: topFurnitureName,
      revenue: topFurnitureEntry.isEmpty ? 0 : topFurnitureEntry.first.value,
      weeklyRevenue: [
        for (final date in weekDates)
          furnitureDailyRevenue[topFurnitureName]?[date] ?? 0,
      ],
    );

    // The activity chart counts completed receipts only and attaches the
    // matching completed preorder amount to the receipt's issue date.
    final weeklyCounts = <DateTime, int>{
      for (final date in weekDates) date: 0,
    };
    final revenueByDate = <DateTime, double>{
      for (final date in weekDates) date: 0.0,
    };

    for (final receipt in receiptRows) {
      final preorder = _relationMap(receipt['PREORDER'] ?? receipt['preorder']);
      if (!_isCompletedStatus(_normalizeStatus(preorder?['status']))) continue;
      final issuedAt = DateTime.tryParse(receipt['issued_at']?.toString() ?? '')?.toLocal();
      if (issuedAt == null) continue;
      final date = _dateOnly(issuedAt);
      if (!weeklyCounts.containsKey(date)) continue;
      weeklyCounts[date] = (weeklyCounts[date] ?? 0) + 1;
      revenueByDate[date] = (revenueByDate[date] ?? 0) + _asDouble(preorder?['total_price']);
    }

    final weeklyRevenue = List.generate(7, (index) {
      final date = today.subtract(Duration(days: 6 - index));
      return DailyRevenueMetric(date: date, amount: revenueByDate[date] ?? 0);
    });

    final weeklyActivity = List.generate(7, (index) {
      final date = weekDates[index];
      return DailyPreorderActivity(
        date: date,
        count: weeklyCounts[date] ?? 0,
        amount: revenueByDate[date] ?? 0,
      );
    });
    final recentReceipts = receiptRows.map((receipt) {
      final preorder = _relationMap(receipt['PREORDER'] ?? receipt['preorder']);
      final customer = _relationMap(preorder?['CUSTOMER'] ?? preorder?['customer']);
      return RecentReceiptMetric(
        receiptId: (receipt['receipt_id'] ?? '').toString(),
        customerName: customer?['full_name']?.toString() ?? 'Unknown Customer',
        issuedAt: DateTime.tryParse(receipt['issued_at']?.toString() ?? '')?.toLocal(),
        totalAmount: _asDouble(preorder?['total_price']),
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
      weeklyRevenue: weeklyRevenue,
      recentReceipts: recentReceipts.take(5).toList(),
      categoryPerformance: categoryPerformance.take(8).toList(),
      topFurniture: topFurniture,
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

/// Lays children side by side with flex-proportional widths and stretches them
/// all to the tallest child's height. IntrinsicHeight cannot be used here
/// because the section cards contain LayoutBuilders.
class _EqualHeightRow extends MultiChildRenderObjectWidget {
  final List<int> flexes;
  final double spacing;

  const _EqualHeightRow({
    required this.flexes,
    required this.spacing,
    required super.children,
  }) : assert(flexes.length == children.length);

  @override
  _RenderEqualHeightRow createRenderObject(BuildContext context) {
    return _RenderEqualHeightRow(flexes: flexes, spacing: spacing);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderEqualHeightRow renderObject,
  ) {
    renderObject
      ..flexes = flexes
      ..spacing = spacing;
  }
}

class _EqualHeightRowParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderEqualHeightRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _EqualHeightRowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _EqualHeightRowParentData> {
  _RenderEqualHeightRow({required List<int> flexes, required double spacing})
    : _flexes = flexes,
      _spacing = spacing;

  List<int> _flexes;
  set flexes(List<int> value) {
    if (_listEquals(_flexes, value)) return;
    _flexes = value;
    markNeedsLayout();
  }

  double _spacing;
  set spacing(double value) {
    if (_spacing == value) return;
    _spacing = value;
    markNeedsLayout();
  }

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _EqualHeightRowParentData) {
      child.parentData = _EqualHeightRowParentData();
    }
  }

  @override
  void performLayout() {
    final children = getChildrenAsList();
    final totalFlex = _flexes.fold<int>(0, (sum, flex) => sum + flex);
    final available = math.max(
      constraints.maxWidth - _spacing * (children.length - 1),
      0.0,
    );
    final widths = [
      for (final flex in _flexes) available * flex / math.max(totalFlex, 1),
    ];

    // First pass measures each child's natural height at its column width;
    // the second pass forces every child to the tallest of those heights.
    var rowHeight = 0.0;
    for (var i = 0; i < children.length; i++) {
      children[i].layout(
        BoxConstraints.tightFor(width: widths[i]),
        parentUsesSize: true,
      );
      rowHeight = math.max(rowHeight, children[i].size.height);
    }

    var x = 0.0;
    for (var i = 0; i < children.length; i++) {
      children[i].layout(
        BoxConstraints.tightFor(width: widths[i], height: rowHeight),
      );
      (children[i].parentData! as _EqualHeightRowParentData).offset = Offset(
        x,
        0,
      );
      x += widths[i] + _spacing;
    }

    size = constraints.constrain(Size(constraints.maxWidth, rowHeight));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}

/// Scales completed-slip revenue across the last seven days.
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
    final maximum = activity.fold<double>(
      0,
      (current, day) => math.max(current, day.amount),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < activity.length; index++) ...[
          Expanded(
            child: Tooltip(
              message: '${_dayNames[activity[index].date.weekday - 1]}\n'
                  '${activity[index].count} completed slips\n'
                  'Earned: ₱${activity[index].amount.toStringAsFixed(2)}',
              child: Semantics(
                label:
                    '${_dayNames[activity[index].date.weekday - 1]}, ${activity[index].count} completed slips, earned ${activity[index].amount.toStringAsFixed(2)} pesos',
                child: Column(
                  children: [
                  Text(
                    activity[index].amount >= 1000
                        ? '₱${(activity[index].amount / 1000).toStringAsFixed(1)}k'
                        : '₱${activity[index].amount.toStringAsFixed(0)}',
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
                            : activity[index].amount / maximum;
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
          ),
          if (index != activity.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

/// Seven-day revenue chart based only on completed (paid) pre-orders.
class _WeeklyRevenueChart extends StatelessWidget {
  final List<DailyRevenueMetric> activity;
  const _WeeklyRevenueChart({required this.activity});

  @override
  Widget build(BuildContext context) {
    final maximum = activity.fold<double>(0, (value, day) => math.max(value, day.amount));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < activity.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Text(activity[i].amount.toStringAsFixed(0), style: const TextStyle(color: Color(0xFF7A6865), fontSize: 10, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Expanded(
                  child: LayoutBuilder(builder: (context, constraints) {
                    final factor = maximum == 0 ? 0.04 : activity[i].amount / maximum;
                    return Align(
                      alignment: Alignment.bottomCenter,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 24,
                        height: math.max(6, constraints.maxHeight * factor),
                        decoration: BoxDecoration(
                          color: i == activity.length - 1 ? const Color(0xFF438A5E) : const Color(0xFFBBD4C2),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 10),
                Text(['MON','TUE','WED','THU','FRI','SAT','SUN'][activity[i].date.weekday - 1], style: TextStyle(color: Colors.grey.shade500, fontSize: 9, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          if (i != activity.length - 1) const SizedBox(width: 8),
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
  return status == 'completed';
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
