import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

// Free Gemini key from Google AI Studio (do NOT enable billing to stay free).
// Run with: flutter run -d chrome --dart-define=GEMINI_KEY=your_key
const String _geminiKey = String.fromEnvironment('GEMINI_KEY');
const String _geminiModel = 'gemini-3.5-flash-lite';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class WeeklyRevenue {
  final DateTime weekStart;
  final double amount;
  final bool isProjected;
  const WeeklyRevenue(this.weekStart, this.amount, {this.isProjected = false});
}

class RevenueForecast {
  final List<WeeklyRevenue> history;
  final List<WeeklyRevenue> projection;
  final double projectedNextMonth;
  final double lastFourWeeks;
  final double growthPercent;
  final double rSquared;
  final bool reliable;

  const RevenueForecast({
    required this.history,
    required this.projection,
    required this.projectedNextMonth,
    required this.lastFourWeeks,
    required this.growthPercent,
    required this.rSquared,
    required this.reliable,
  });

  factory RevenueForecast.empty() => const RevenueForecast(
        history: [],
        projection: [],
        projectedNextMonth: 0,
        lastFourWeeks: 0,
        growthPercent: 0,
        rSquared: 0,
        reliable: false,
      );
}

enum StockUrgency { critical, high, watch }

class RestockSuggestion {
  final String name;
  final int stock;
  final double weeklyVelocity;
  final double weeksLeft;
  final int suggestedQty;
  final StockUrgency urgency;

  const RestockSuggestion({
    required this.name,
    required this.stock,
    required this.weeklyVelocity,
    required this.weeksLeft,
    required this.suggestedQty,
    required this.urgency,
  });
}

class BundleSuggestion {
  final String itemA;
  final String itemB;
  final int pairCount;
  final double support;
  final double confidence;
  final double lift;

  const BundleSuggestion({
    required this.itemA,
    required this.itemB,
    required this.pairCount,
    required this.support,
    required this.confidence,
    required this.lift,
  });
}

class SlowMover {
  final String name;
  final int stock;
  const SlowMover(this.name, this.stock);
}

class TopSeller {
  final String name;
  final int units;
  const TopSeller(this.name, this.units);
}

class InsightsResult {
  final RevenueForecast forecast;
  final List<RestockSuggestion> restock;
  final List<BundleSuggestion> bundles;
  final List<SlowMover> slowMovers;
  final List<TopSeller> topSellers;
  final List<String> catalog;
  final int completedOrders;
  final double velocityWeeks;

  const InsightsResult({
    required this.forecast,
    required this.restock,
    required this.bundles,
    required this.slowMovers,
    required this.topSellers,
    required this.catalog,
    required this.completedOrders,
    required this.velocityWeeks,
  });

  /// Compact JSON sent to the LLM (aggregates only, never raw orders).
  Map<String, dynamic> toAiPayload() => {
        'currency': 'PHP',
        'completed_orders': completedOrders,
        'forecast': {
          'projected_next_4_weeks': forecast.projectedNextMonth.round(),
          'last_4_weeks': forecast.lastFourWeeks.round(),
          'growth_percent': double.parse(forecast.growthPercent.toStringAsFixed(1)),
          'model_r2': double.parse(forecast.rSquared.toStringAsFixed(2)),
          'weeks_of_history': forecast.history.length,
        },
        'restock_candidates': [
          for (final r in restock.take(8))
            {
              'item': r.name,
              'stock': r.stock,
              'units_per_week': double.parse(r.weeklyVelocity.toStringAsFixed(2)),
              'weeks_left': double.parse(r.weeksLeft.toStringAsFixed(1)),
              'suggested_qty': r.suggestedQty,
            }
        ],
        'bought_together': [
          for (final b in bundles.take(5))
            {
              'items': [b.itemA, b.itemB],
              'orders': b.pairCount,
              'confidence': double.parse(b.confidence.toStringAsFixed(2)),
            }
        ],
        'slow_movers': [
          for (final s in slowMovers.take(5)) {'item': s.name, 'stock': s.stock}
        ],
        'top_sellers': [
          for (final t in topSellers.take(5)) {'item': t.name, 'units': t.units}
        ],
        'current_catalog': catalog.take(40).toList(),
      };

  /// Used when no API key is set or the API call fails.
  String templateSummary() {
    if (completedOrders == 0) {
      return 'No completed orders yet, so there is not enough data to forecast.';
    }
    final f = forecast;
    final dir = f.growthPercent >= 0 ? 'up' : 'down';
    final parts = <String>[
      'Projected sales for the next 4 weeks are '
          '\u20B1${f.projectedNextMonth.toStringAsFixed(0)} '
          '($dir ${f.growthPercent.abs().toStringAsFixed(1)}% vs the last 4 weeks).',
    ];
    if (restock.isNotEmpty) {
      final r = restock.first;
      parts.add('${r.name} is the most urgent restock: ${r.stock} left, '
          'about ${r.weeksLeft.toStringAsFixed(1)} weeks of supply.');
    }
    if (bundles.isNotEmpty) {
      parts.add('${bundles.first.itemA} and ${bundles.first.itemB} are often '
          'bought together, so stock them as a bundle.');
    }
    if (slowMovers.isNotEmpty) {
      parts.add('${slowMovers.first.name} has not sold recently; hold off on reordering it.');
    }
    return parts.join(' ');
  }
}

class AiRestock {
  final String item;
  final int qty;
  final String reason;
  const AiRestock(this.item, this.qty, this.reason);
}

class AiTrend {
  final String name;
  final String why;
  const AiTrend(this.name, this.why);
}

class AiPlan {
  final String summary;
  final List<AiRestock> restock;
  final List<String> bundles;
  final List<AiTrend> newTrends;
  final DateTime generatedAt;

  const AiPlan({
    required this.summary,
    required this.restock,
    required this.bundles,
    required this.newTrends,
    required this.generatedAt,
  });
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class InsightsService {
  /// Runs all three analyses from rows the dashboard already fetched.
  /// No SQL views, RPCs or new tables: plain client-side aggregation.
  static InsightsResult analyze({
    required List<Map<String, dynamic>> preorderRows,
    required List<Map<String, dynamic>> preorderItemRows,
    required Map<String, int> stockByName,
    DateTime? now,
    int targetWeeks = 4,
    int windowWeeks = 8,
  }) {
    final today = _dateOnly(now ?? DateTime.now());
    final forecast = _forecastRevenue(preorderRows, today);

    // ---- collect completed sale lines ------------------------------------
    final sales = <_Sale>[];
    for (final item in preorderItemRows) {
      final preorder = _relationMap(item['PREORDER'] ?? item['preorder']);
      if (!_isCompleted(preorder?['status'])) continue;

      final direct = _relationMap(item['FURNITURE'] ?? item['furniture']);
      final variant = _relationMap(item['VARIANT'] ?? item['variant']);
      final viaVariant =
          _relationMap(variant?['FURNITURE'] ?? variant?['furniture']);
      final name =
          (direct ?? viaVariant)?['furniture_name']?.toString().trim() ?? '';
      final qty = _asInt(item['quantity']);
      if (name.isEmpty || qty <= 0) continue;

      final at = DateTime.tryParse(preorder?['preordered_at']?.toString() ?? '')
          ?.toLocal();
      sales.add(_Sale(
        name,
        qty,
        at == null ? null : _dateOnly(at),
        '${item['preorder_id'] ?? preorder?['preorder_id'] ?? ''}',
      ));
    }

    // ---- 2) What to buy next: sales velocity vs stock --------------------
    final dated = sales.where((s) => s.date != null).toList();
    var windowStart = _addDays(today, -windowWeeks * 7);
    if (dated.isNotEmpty) {
      final first =
          dated.map((s) => s.date!).reduce((a, b) => a.isBefore(b) ? a : b);
      if (first.isAfter(windowStart)) windowStart = first;
    }
    final weeks =
        math.max(1.0, today.difference(windowStart).inHours / 24.0 / 7.0);

    final unitsInWindow = <String, int>{};
    final unitsAllTime = <String, int>{};
    for (final s in sales) {
      unitsAllTime.update(s.name, (v) => v + s.qty, ifAbsent: () => s.qty);
      if (s.date != null && !s.date!.isBefore(windowStart)) {
        unitsInWindow.update(s.name, (v) => v + s.qty, ifAbsent: () => s.qty);
      }
    }

    final restock = <RestockSuggestion>[];
    unitsInWindow.forEach((name, units) {
      final stock = stockByName[name];
      if (stock == null) return; // archived or removed product
      final velocity = units / weeks;
      if (velocity <= 0) return;
      final weeksLeft = stock / velocity;
      if (weeksLeft >= targetWeeks) return;
      final qty = math.max(1, (velocity * targetWeeks - stock).ceil());
      restock.add(RestockSuggestion(
        name: name,
        stock: stock,
        weeklyVelocity: velocity,
        weeksLeft: weeksLeft,
        suggestedQty: qty,
        urgency: weeksLeft <= 1
            ? StockUrgency.critical
            : weeksLeft <= 2
                ? StockUrgency.high
                : StockUrgency.watch,
      ));
    });
    restock.sort((a, b) => a.weeksLeft.compareTo(b.weeksLeft));

    // ---- 3a) Slow movers --------------------------------------------------
    final slow = <SlowMover>[];
    if (sales.isNotEmpty) {
      for (final e in stockByName.entries) {
        if (e.value > 0 && (unitsInWindow[e.key] ?? 0) == 0) {
          slow.add(SlowMover(e.key, e.value));
        }
      }
      slow.sort((a, b) => b.stock.compareTo(a.stock));
    }

    // ---- 3b) Association rules: items bought together --------------------
    final basket = <String, Set<String>>{};
    for (final s in sales) {
      if (s.preorderId.isEmpty) continue;
      basket.putIfAbsent(s.preorderId, () => <String>{}).add(s.name);
    }
    final totalOrders = basket.length;
    final itemOrders = <String, int>{};
    final pairOrders = <String, int>{};
    for (final items in basket.values) {
      for (final i in items) {
        itemOrders.update(i, (v) => v + 1, ifAbsent: () => 1);
      }
      final list = items.toList()..sort();
      for (var i = 0; i < list.length; i++) {
        for (var j = i + 1; j < list.length; j++) {
          pairOrders.update('${list[i]}\u0000${list[j]}', (v) => v + 1,
              ifAbsent: () => 1);
        }
      }
    }

    List<BundleSuggestion> buildBundles(int minCount) {
      final out = <BundleSuggestion>[];
      pairOrders.forEach((key, count) {
        if (count < minCount) return;
        final parts = key.split('\u0000');
        final a = parts[0], b = parts[1];
        final countA = itemOrders[a] ?? 1;
        final countB = itemOrders[b] ?? 1;
        final confidence = count / math.min(countA, countB);
        final lift = (count / totalOrders) /
            ((countA / totalOrders) * (countB / totalOrders));
        out.add(BundleSuggestion(
          itemA: a,
          itemB: b,
          pairCount: count,
          support: count / totalOrders,
          confidence: confidence,
          lift: lift,
        ));
      });
      out.sort((x, y) {
        final c = y.pairCount.compareTo(x.pairCount);
        return c != 0 ? c : y.lift.compareTo(x.lift);
      });
      return out;
    }

    var bundles = buildBundles(2);
    if (bundles.isEmpty) bundles = buildBundles(1); // small datasets

    final topSellers = unitsAllTime.entries
        .map((e) => TopSeller(e.key, e.value))
        .toList()
      ..sort((a, b) => b.units.compareTo(a.units));

    return InsightsResult(
      forecast: forecast,
      restock: restock,
      bundles: bundles.take(5).toList(),
      slowMovers: slow.take(5).toList(),
      topSellers: topSellers.take(5).toList(),
      catalog: stockByName.keys.toList(),
      completedOrders: totalOrders,
      velocityWeeks: weeks,
    );
  }

  // ---- 1) Sales prediction: linear regression on weekly revenue -----------
  static RevenueForecast _forecastRevenue(
    List<Map<String, dynamic>> preorderRows,
    DateTime today,
  ) {
    final currentWeek = _weekStart(today);
    final byWeek = <DateTime, double>{};
    for (final p in preorderRows) {
      if (!_isCompleted(p['status'])) continue;
      final at =
          DateTime.tryParse(p['preordered_at']?.toString() ?? '')?.toLocal();
      if (at == null) continue;
      final w = _weekStart(_dateOnly(at));
      final amount = _asDouble(p['total_price']);
      byWeek.update(w, (v) => v + amount, ifAbsent: () => amount);
    }
    if (byWeek.isEmpty) return RevenueForecast.empty();

    // Use only full weeks (the current week is still in progress).
    final fullWeeks = byWeek.keys.where((w) => w.isBefore(currentWeek)).toList()
      ..sort();
    final DateTime first;
    final DateTime last;
    if (fullWeeks.isNotEmpty) {
      first = fullWeeks.first;
      last = _addDays(currentWeek, -7);
    } else {
      first = byWeek.keys.reduce((a, b) => a.isBefore(b) ? a : b);
      last = first;
    }

    var history = <WeeklyRevenue>[];
    for (var w = first; !w.isAfter(last); w = _addDays(w, 7)) {
      history.add(WeeklyRevenue(w, byWeek[w] ?? 0));
    }
    if (history.length > 12) history = history.sublist(history.length - 12);

    final n = history.length;
    final ys = history.map((h) => h.amount).toList();
    final mean = ys.reduce((a, b) => a + b) / n;

    double slope = 0, intercept = mean, r2 = 0;
    final reliable = n >= 3;
    if (reliable) {
      final xMean = (n - 1) / 2.0;
      var sxy = 0.0, sxx = 0.0, ssTot = 0.0;
      for (var i = 0; i < n; i++) {
        sxy += (i - xMean) * (ys[i] - mean);
        sxx += (i - xMean) * (i - xMean);
        ssTot += (ys[i] - mean) * (ys[i] - mean);
      }
      slope = sxx == 0 ? 0 : sxy / sxx;
      intercept = mean - slope * xMean;
      var ssRes = 0.0;
      for (var i = 0; i < n; i++) {
        final fit = intercept + slope * i;
        ssRes += (ys[i] - fit) * (ys[i] - fit);
      }
      r2 = ssTot == 0 ? 0 : (1 - ssRes / ssTot).clamp(0.0, 1.0).toDouble();
    }

    final projection = <WeeklyRevenue>[];
    for (var k = 0; k < 4; k++) {
      final value = math.max(0.0, intercept + slope * (n + k));
      projection.add(WeeklyRevenue(
        _addDays(history.last.weekStart, 7 * (k + 1)),
        value,
        isProjected: true,
      ));
    }

    final recent = ys.sublist(math.max(0, n - 4));
    final lastFour = recent.reduce((a, b) => a + b) / recent.length * 4;
    final projected = projection.fold<double>(0, (s, p) => s + p.amount);
    final growth = lastFour > 0 ? (projected - lastFour) / lastFour * 100 : 0.0;

    return RevenueForecast(
      history: history,
      projection: projection,
      projectedNextMonth: projected,
      lastFourWeeks: lastFour,
      growthPercent: growth,
      rSquared: r2,
      reliable: reliable,
    );
  }

  // ---- Generative layer (free Gemini key) ---------------------------------
  /// Throws an Exception with a readable message on failure.
  static Future<AiPlan> fetchAiPlan(InsightsResult insights) async {
    if (_geminiKey.isEmpty) {
      throw Exception('No API key set. Run with --dart-define=GEMINI_KEY=...');
    }

    final res = await http
        .post(
          Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/'
              '$_geminiModel:generateContent?key=$_geminiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'systemInstruction': {
              'parts': [
                {
                  'text': 'You are an inventory and sales advisor for a furniture '
                      'store in the Philippines. Use ONLY the data provided for '
                      'restock and bundle decisions; never invent sales numbers. '
                      'For "new_trends", suggest 2-3 trending furniture product '
                      'ideas NOT already in current_catalog, based on general '
                      'market knowledge. Write short, plain-language reasons. '
                      'Return JSON only, exactly in this shape: '
                      '{"summary":"","restock":[{"item":"","qty":0,"reason":""}],'
                      '"bundles":[""],"new_trends":[{"name":"","why":""}]}'
                }
              ]
            },
            'contents': [
              {
                'parts': [
                  {'text': jsonEncode(insights.toAiPayload())}
                ]
              }
            ],
            'generationConfig': {
              'temperature': 0.3,
              'responseMimeType': 'application/json',
            },
          }),
        )
        .timeout(const Duration(seconds: 90));

    if (res.statusCode == 429) {
      throw Exception('Free API limit reached. Try again in a minute.');
    }
    /*if (res.statusCode != 200) {
      throw Exception('AI request failed (${res.statusCode}).');
    }*/
        if (res.statusCode != 200) {
      var detail = '';
      try {
        detail = jsonDecode(res.body)['error']['message'].toString();
      } catch (_) {}
      throw Exception('AI request failed (${res.statusCode}). $detail');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final text = body['candidates'][0]['content']['parts'][0]['text'] as String;
    final json = jsonDecode(
      text.replaceAll(RegExp(r'```json|```'), '').trim(),
    ) as Map<String, dynamic>;

    return AiPlan(
      summary: json['summary']?.toString() ?? '',
      restock: [
        for (final r in (json['restock'] as List? ?? []))
          if (r is Map)
            AiRestock(
              r['item']?.toString() ?? '',
              _asInt(r['qty']),
              r['reason']?.toString() ?? '',
            ),
      ],
      bundles: [
        for (final b in (json['bundles'] as List? ?? [])) b.toString(),
      ],
      newTrends: [
        for (final t in (json['new_trends'] as List? ?? []))
          if (t is Map)
            AiTrend(t['name']?.toString() ?? '', t['why']?.toString() ?? ''),
      ],
      generatedAt: DateTime.now(),
    );
  }
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

class _Sale {
  final String name;
  final int qty;
  final DateTime? date;
  final String preorderId;
  const _Sale(this.name, this.qty, this.date, this.preorderId);
}

Map<String, dynamic>? _relationMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is List && value.isNotEmpty && value.first is Map) {
    return Map<String, dynamic>.from(value.first as Map);
  }
  return null;
}

bool _isCompleted(dynamic status) {
  final s = status?.toString().trim().toLowerCase() ?? '';
  return s == 'completed' ||
      s == 'complete' ||
      s == 'done' ||
      s == 'paid' ||
      s == 'fulfilled';
}

int _asInt(dynamic v) =>
    v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

double _asDouble(dynamic v) =>
    v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

DateTime _weekStart(DateTime d) => _addDays(d, -(d.weekday - 1)); // Monday