import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F5), // Light warm layout canvas background
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(36.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dashboard Welcome Header
            const Text(
              "Store Overview Dashboard",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A3E3D),
              ),
            ),
            const Text(
              "Here's what's happening with your furniture store today.",
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),

            // Top Summary Analytics Cards Grid Row
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    title: "Pending Receipts",
                    value: "4 Pending",
                    subtext: "5 Completed | 3 Cancelled",
                    icon: Icons.receipt_long_outlined,
                    iconColor: const Color(0xFFB5835A),
                    bgColor: const Color(0xFFF7EBE1),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildSummaryCard(
                    title: "Furniture Catalog & Stocks",
                    value: "148 Products",
                    subtext: "8 Categories configured",
                    icon: Icons.chair_outlined,
                    iconColor: const Color(0xFF5A8DB5),
                    bgColor: const Color(0xFFE1F0F7),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildSummaryCard(
                    title: "Active Categories",
                    value: "5 Main Categories",
                    subtext: "Bed, Cabinet, Chair, Sofa, Table",
                    icon: Icons.category_outlined,
                    iconColor: const Color(0xFF5AB56E),
                    bgColor: const Color(0xFFE1F7E6),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 40),

            // Main Lower Split-Layout (Left Side: Sales List / Right Side: Stock Snapshot)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // PRODUCT SALES HIGHLIGHT DATA TABLE SECTION
                Expanded(
                  flex: 3,
                  child: _buildContentSectionContainer(
                    title: "Top Product Sales Tracker",
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(3),
                        1: FlexColumnWidth(1),
                      },
                      children: [
                        _buildTableHeaderRow(["Furniture", "Frequency"]),
                        _buildTableRow(["Bed Gray", "4 times"]),
                        _buildTableRow(["L-Shape Leather Sofa", "3 times"]),
                        _buildTableRow(["Cushioned Chair", "3 times"]),
                        _buildTableRow(["Wooden Table", "2 times"]),
                        _buildTableRow(["Wooden Cabinet", "2 times"]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),

                // QUICK STOCKS SNAPSHOT STATS VIEW
                Expanded(
                  flex: 2,
                  child: _buildContentSectionContainer(
                    title: "Stock Alert Snapshot",
                    child: Column(
                      children: [
                        _buildStockAlertItem("Couch (Gray)", 12, Colors.green),
                        const Divider(),
                        _buildStockAlertItem("Wooden Cabinet (Khaki)", 3, Colors.orange),
                        const Divider(),
                        _buildStockAlertItem("L-Shape Leather Sofa", 1, Colors.red),
                        const Divider(),
                        _buildStockAlertItem("Cushioned Chair", 24, Colors.green),
                      ],
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

  // Cards Builder Utility
  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: bgColor,
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF4A3E3D)),
          ),
          const SizedBox(height: 6),
          Text(
            subtext,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // Shared Data Area Wrapper Layout Card
  Widget _buildContentSectionContainer({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4A3E3D)),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  // Custom Table Header Stylist Helper
  TableRow _buildTableHeaderRow(List<String> headers) {
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1.5)),
      ),
      children: headers.map((header) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Text(
            header,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7D6E6A), fontSize: 14),
          ),
        );
      }).toList(),
    );
  }

  // Custom Table Content Row Builder 
  TableRow _buildTableRow(List<String> data) {
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFFAFAFA))),
      ),
      children: data.map((cellText) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 14.0),
          child: Text(
            cellText,
            style: const TextStyle(fontSize: 14, color: Color(0xFF222222), fontWeight: FontWeight.w400),
          ),
        );
      }).toList(),
    );
  }

  // Stock Alert Indicators Subcomponents
  Widget _buildStockAlertItem(String productName, int count, Color statusColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            productName,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                "$count left",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: statusColor == Colors.red ? Colors.red : const Color(0xFF4A3E3D),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}