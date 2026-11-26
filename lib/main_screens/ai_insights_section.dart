import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'insights_service.dart';
import 'dart:async';

class AiInsightsSection extends StatefulWidget {
  final InsightsResult insights;

  const AiInsightsSection({super.key, required this.insights});

  @override
  State<AiInsightsSection> createState() => _AiInsightsSectionState();
}

class _AiInsightsSectionState extends State<AiInsightsSection> {
  static const Color _ink = Color(0xFF2C2221);
  static const Color _bronze = Color(0xFFC68B59);
  static const Color _darkBrown = Color(0xFF6D4C41);
  static const Color _sage = Color(0xFF438A5E);
  static const Color _mutedRed = Color(0xFFD9534F);
  static const Color _mutedOrange = Color(0xFFF0AD4E);

  AiPlan? _plan;
  bool _loading = false;
  String? _error;

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plan = await InsightsService.fetchAiPlan(widget.insights);
      if (!mounted) return;
      setState(() => _plan = plan);
    }catch (e) {
      if (!mounted) return;
      setState(() => _error = e is TimeoutException
          ? 'The AI took too long to respond. Please try again.'
          : e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.insights;
    final summary = _plan?.summary.trim().isNotEmpty == true
        ? _plan!.summary
        : data.templateSummary();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        if (_error != null) ...[
          _buildNotice(
            '$_error Showing the calculated results below instead.',
          ),
          const SizedBox(height: 16),
        ],
        _buildSummary(summary, fromAi: _plan != null),
        const SizedBox(height: 24),
        _pair(
          _buildForecastCard(data.forecast),
          _buildRestockCard(data.restock),
        ),
        const SizedBox(height: 24),
        _triple(
          _buildBundlesCard(data.bundles),
          _buildSlowMoversCard(data.slowMovers),
          _buildTrendsCard(),
        ),
      ],
    );
  }

  // ---- header / summary -----------------------------------------------------

  Widget _buildHeader() {
    return LayoutBuilder(builder: (context, c) {
      final narrow = c.maxWidth < 600;
      final title = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI Sales & Inventory Insights',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _ink,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Forecasts are calculated from your completed order slips. '
            'Recommendations are written by AI.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      );
      final button = FilledButton.icon(
        onPressed: _loading ? null : _generate,
        style: FilledButton.styleFrom(
          backgroundColor: _darkBrown,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: _loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.auto_awesome_rounded, size: 18),
        label: Text(_plan == null ? 'Generate AI plan' : 'Regenerate'),
      );
      if (narrow) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [title, const SizedBox(height: 14), button],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [Expanded(child: title), const SizedBox(width: 20), button],
      );
    });
  }

  Widget _buildSummary(String text, {required bool fromAi}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF6EDE3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _bronze.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              shape: BoxShape.circle,
            ),
            child: Icon(
              fromAi ? Icons.auto_awesome_rounded : Icons.lightbulb_outline_rounded,
              color: _bronze,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fromAi ? 'AI summary' : 'Quick summary',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                if (fromAi && _plan != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Generated at ${_time(_plan!.generatedAt)}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotice(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _mutedOrange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _mutedOrange.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: _mutedOrange, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
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

  // ---- 1) sales forecast ----------------------------------------------------

  Widget _buildForecastCard(RevenueForecast f) {
    final up = f.growthPercent >= 0;
    final badgeColor = up ? _sage : _mutedRed;

    return _card(
      title: 'Sales Forecast',
      subtitle: 'Linear regression on weekly completed sales',
      child: f.history.isEmpty
          ? _empty(Icons.show_chart_rounded,
              'Complete a few order slips to see a forecast.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Text(
                      _peso(f.projectedNextMonth),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (f.reliable)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              up
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              size: 16,
                              color: badgeColor,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${up ? '+' : ''}${f.growthPercent.toStringAsFixed(1)}% vs last 4 weeks',
                              style: TextStyle(
                                color: badgeColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Projected sales, next 4 weeks',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 18),
                SizedBox(height: 190, child: _ForecastBars(forecast: f)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _legendDot(const Color(0xFFE2C5AA), 'Actual'),
                    const SizedBox(width: 14),
                    _legendDot(_bronze, 'Projected'),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  f.reliable
                      ? 'Based on your last 8 weeks of sales'
                      : 'Fewer than 3 full weeks of data, so this is a simple average. Accuracy improves as orders grow.',
                  style: TextStyle(
                    color: f.reliable ? Colors.grey.shade500 : _mutedOrange,
                    fontSize: 11,
                    fontWeight: f.reliable ? FontWeight.w500 : FontWeight.w700,
                  ),
                ),
              ],
            ),
    );
  }

  // ---- 2) what to buy next --------------------------------------------------

  Widget _buildRestockCard(List<RestockSuggestion> items) {
    final reasons = <String, AiRestock>{
      for (final r in _plan?.restock ?? <AiRestock>[]) r.item.toLowerCase(): r,
    };

    return _card(
      title: 'What to Buy Next',
      subtitle: 'Sales per week vs. stock left (4-week target)',
      child: items.isEmpty
          ? _empty(Icons.check_circle_outline_rounded,
              'No fast-moving item is close to running out.')
          : Column(
              children: [
                for (var i = 0; i < items.length && i < 8; i++) ...[
                  _restockRow(items[i], reasons[items[i].name.toLowerCase()]),
                  if (i != items.length - 1 && i < 7) const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }

  Widget _restockRow(RestockSuggestion r, AiRestock? ai) {
    final color = switch (r.urgency) {
      StockUrgency.critical => _mutedRed,
      StockUrgency.high => _mutedOrange,
      StockUrgency.watch => _bronze,
    };
    final label = switch (r.urgency) {
      StockUrgency.critical => 'Order now',
      StockUrgency.high => 'Soon',
      StockUrgency.watch => 'Watch',
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF9F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${r.stock} in stock \u00B7 sells ${r.weeklyVelocity.toStringAsFixed(1)}/week \u00B7 '
                  'about ${r.weeksLeft.toStringAsFixed(1)} weeks left',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Order +${r.suggestedQty}',
                style: const TextStyle(
                  color: _darkBrown,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (ai != null && ai.reason.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    size: 14, color: _bronze),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    ai.reason,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ---- 3) product suggestions ----------------------------------------------

  Widget _buildBundlesCard(List<BundleSuggestion> bundles) {
    final aiNotes = _plan?.bundles ?? const <String>[];
    return _card(
      title: 'Bundles to Stock Together',
      subtitle: 'Items customers buy in the same order',
      child: bundles.isEmpty && aiNotes.isEmpty
          ? _empty(Icons.link_rounded,
              'No items have been bought together yet.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final b in bundles) ...[
                  _listTile(
                    icon: Icons.link_rounded,
                    title: '${b.itemA} + ${b.itemB}',
                    detail:
                        'Together in ${b.pairCount} ${b.pairCount == 1 ? 'order' : 'orders'} \u00B7 '
                        '${(b.confidence * 100).toStringAsFixed(0)}% of the time',
                  ),
                  const SizedBox(height: 10),
                ],
                for (final note in aiNotes) ...[
                  _listTile(
                    icon: Icons.auto_awesome_rounded,
                    title: note,
                    detail: null,
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }

  Widget _buildSlowMoversCard(List<SlowMover> slow) {
    return _card(
      title: 'Slow Movers',
      subtitle: 'In stock but no sales in recent weeks',
      child: slow.isEmpty
          ? _empty(Icons.speed_rounded, 'No slow-moving items found.')
          : Column(
              children: [
                for (final s in slow) ...[
                  _listTile(
                    icon: Icons.hourglass_bottom_rounded,
                    title: s.name,
                    detail: '${s.stock} units idle \u00B7 hold off on reordering',
                    color: _mutedOrange,
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }

  Widget _buildTrendsCard() {
    final trends = _plan?.newTrends ?? const <AiTrend>[];
    return _card(
      title: 'Trending Ideas',
      subtitle: 'New products to consider, from AI market knowledge',
      child: trends.isEmpty
          ? _empty(Icons.auto_awesome_rounded,
              'Press "Generate AI plan" to get new product ideas.')
          : Column(
              children: [
                for (final t in trends) ...[
                  _listTile(
                    icon: Icons.trending_up_rounded,
                    title: t.name,
                    detail: t.why,
                    color: _sage,
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }

  // ---- shared pieces --------------------------------------------------------

  Widget _listTile({
    required IconData icon,
    required String title,
    required String? detail,
    Color color = _bronze,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF9F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                if (detail != null && detail.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final isPhone = MediaQuery.of(context).size.width < 600;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isPhone ? 18 : 28),
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
          SizedBox(height: isPhone ? 18 : 24),
          child,
        ],
      ),
    );
  }

  Widget _empty(IconData icon, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 30),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF9F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFB5A6A1), size: 32),
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

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
      ],
    );
  }

  Widget _pair(Widget left, Widget right) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 760) {
        return Column(children: [left, const SizedBox(height: 24), right]);
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 2, child: left),
            const SizedBox(width: 24),
            Expanded(flex: 3, child: right),
          ],
        ),
      );
    });
  }

  Widget _triple(Widget a, Widget b, Widget c3) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 900) {
        return Column(children: [
          a,
          const SizedBox(height: 24),
          b,
          const SizedBox(height: 24),
          c3,
        ]);
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: a),
            const SizedBox(width: 24),
            Expanded(child: b),
            const SizedBox(width: 24),
            Expanded(child: c3),
          ],
        ),
      );
    });
  }

  String _peso(double value) {
    final digits = value.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final remaining = digits.length - i;
      buffer.write(digits[i]);
      if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
    }
    return '\u20B1$buffer';
  }

  String _time(DateTime t) {
    final h = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour);
    return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour >= 12 ? 'PM' : 'AM'}';
  }
}

class _ForecastBars extends StatelessWidget {
  final RevenueForecast forecast;
  const _ForecastBars({required this.forecast});

  @override
  Widget build(BuildContext context) {
    final bars = [
      ...forecast.history.length > 8
          ? forecast.history.sublist(forecast.history.length - 8)
          : forecast.history,
      ...forecast.projection,
    ];
    final maximum = bars.fold<double>(0, (m, b) => math.max(m, b.amount));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < bars.length; i++) ...[
          Expanded(
            child: Tooltip(
              message:
                  'Week of ${bars[i].weekStart.month}/${bars[i].weekStart.day}\n'
                  '\u20B1${bars[i].amount.toStringAsFixed(0)}'
                  '${bars[i].isProjected ? ' (projected)' : ''}',
              child: Column(
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      bars[i].amount >= 1000
                          ? '${(bars[i].amount / 1000).toStringAsFixed(1)}k'
                          : bars[i].amount.toStringAsFixed(0),
                      maxLines: 1,
                      style: const TextStyle(
                        color: Color(0xFF7A6865),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 22),
                        child: FractionallySizedBox(
                          heightFactor: maximum == 0
                              ? 0.04
                              : (bars[i].amount / maximum).clamp(0.04, 1.0),
                          widthFactor: 0.8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: bars[i].isProjected
                                  ? const Color(0xFFC68B59)
                                  : const Color(0xFFE2C5AA),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(6)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${bars[i].weekStart.month}/${bars[i].weekStart.day}',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (i != bars.length - 1) const SizedBox(width: 5),
        ],
      ],
    );
  }
}