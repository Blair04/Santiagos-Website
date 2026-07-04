import 'package:flutter/material.dart';

class PreorderSummary {
  final int pendingCount;
  final int completedCount;
  final int cancelledCount;
  PreorderSummary({required this.pendingCount, required this.completedCount, required this.cancelledCount});
}

class FurnitureStockAlert {
  final String furnitureName;
  final String? variantColor;
  final int stockLeft;
  FurnitureStockAlert({required this.furnitureName, this.variantColor, required this.stockLeft});
}

class TopSaleItem {
  final String name;
  final int frequency;
  TopSaleItem({required this.name, required this.frequency});
}

class DashboardScreen extends StatelessWidget {
  final PreorderSummary preorderStats;
  final int totalFurnitureCount;
  final List<String> dynamicCategories;
  final List<TopSaleItem> topSales;
  final List<FurnitureStockAlert> stockAlerts;

  DashboardScreen({
    super.key,
    PreorderSummary? preorderStats,
    this.totalFurnitureCount = 148, 
    this.dynamicCategories = const ["Bed", "Cabinet", "Chair", "Sofa", "Table"],
    List<TopSaleItem>? topSales,
    List<FurnitureStockAlert>? stockAlerts,
  })  : preorderStats = preorderStats ?? PreorderSummary(pendingCount: 4, completedCount: 5, cancelledCount: 3),
        topSales = topSales ?? [
          TopSaleItem(name: "Bed Gray", frequency: 4),
          TopSaleItem(name: "L-Shape Leather Sofa", frequency: 3),
          TopSaleItem(name: "Cushioned Chair", frequency: 3),
          TopSaleItem(name: "Wooden Table", frequency: 2),
          TopSaleItem(name: "Wooden Cabinet", frequency: 2),
        ],
        stockAlerts = stockAlerts ?? [
          FurnitureStockAlert(furnitureName: "Couch", variantColor: "Gray", stockLeft: 12),
          FurnitureStockAlert(furnitureName: "Wooden Cabinet", variantColor: "Khaki", stockLeft: 3),
          FurnitureStockAlert(furnitureName: "L-Shape Leather Sofa", stockLeft: 1),
          FurnitureStockAlert(furnitureName: "Cushioned Chair", stockLeft: 24),
        ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F6F0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dashboard Header
            const Text(
              "Store Overview Dashboard",
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: Color(0xFF2C2221),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Real-time management system and furniture telemetry.",
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 36),

            LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        title: "Preorders Status",
                        value: "${preorderStats.pendingCount} Pending",
                        subtext: "${preorderStats.completedCount} Completed  •  ${preorderStats.cancelledCount} Cancelled",
                        icon: Icons.receipt_long_rounded,
                        accentColor: const Color(0xFFC68B59),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _buildSummaryCard(
                        title: "Furniture Catalog",
                        value: "$totalFurnitureCount Products",
                        subtext: "Live stock configurations in variant options",
                        icon: Icons.chair_rounded,
                        accentColor: const Color(0xFF4A7A96),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _buildSummaryCard(
                        title: "Active Categories",
                        value: "${dynamicCategories.length} Categories",
                        subtext: dynamicCategories.join(', '),
                        icon: Icons.dashboard_customize_rounded,
                        accentColor: const Color(0xFF438A5E),
                      ),
                    ),
                  ],
                );
              },
            ),
            
            const SizedBox(height: 40),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _buildContentSectionContainer(
                    title: "Top Product Sales Tracker",
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(4),
                        1: FlexColumnWidth(1.5),
                      },
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      children: [
                        _buildTableHeaderRow(["Furniture Model Item", "Frequency Tracking"]),
                        ...topSales.map((item) => _buildTableRow([item.name, "${item.frequency} times"])),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),

                Expanded(
                  flex: 2,
                  child: _buildContentSectionContainer(
                    title: "Stock Alert Snapshot",
                    child: Column(
                      children: stockAlerts.map((alert) {
                        final displayName = alert.variantColor != null 
                            ? "${alert.furnitureName} (${alert.variantColor})" 
                            : alert.furnitureName;
                        return _buildStockAlertItem(displayName, alert.stockLeft);
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2C2221).withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accentColor, size: 26),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w600, letterSpacing: 0.3),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF2C2221), letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          Text(
            subtext,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }

  Widget _buildContentSectionContainer({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2C2221).withOpacity(0.02),
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
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF2C2221), letterSpacing: -0.2),
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  // Modern Styled Data Table Parts
  TableRow _buildTableHeaderRow(List<String> headers) {
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1EDE9), width: 2)),
      ),
      children: headers.map((header) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14.0, top: 4.0),
          child: Text(
            header.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF9E8E8A), fontSize: 11, letterSpacing: 0.8),
          ),
        );
      }).toList(),
    );
  }

  TableRow _buildTableRow(List<String> data) {
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFFBF9F6))),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            data[0],
            style: const TextStyle(fontSize: 14, color: Color(0xFF2C2221), fontWeight: FontWeight.w600),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF4EFEA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                data[1],
                style: const TextStyle(fontSize: 12, color: Color(0xFF7A6865), fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStockAlertItem(String productName, int count) {
    Color statusColor;
    String statusLabel;

    if (count <= 2) {
      statusColor = const Color(0xFFD9534F);
      statusLabel = "Critical Stock";
    } else if (count <= 5) {
      statusColor = const Color(0xFFF0AD4E);
      statusLabel = "Low Stock";
    } else {
      statusColor = const Color(0xFF5CB85C);
      statusLabel = "Healthy";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF9F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                productName,
                style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2C2221), fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                statusLabel,
                style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
              )
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              "$count items left",
              style: TextStyle(fontWeight: FontWeight.w700, color: statusColor, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}