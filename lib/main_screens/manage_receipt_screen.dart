import 'dart:math' as math; 
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _supabase = Supabase.instance.client;

class ManageReceipt extends StatefulWidget {
  const ManageReceipt({super.key});

  static String get routeName => '/manage-receipt';

  @override
  State<ManageReceipt> createState() => _ManageReceiptState();
}

class _ManageReceiptState extends State<ManageReceipt> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _refreshIconController; 

  String query = "";
  String selectedTab = 'Pending';

  List<Map<String, dynamic>> _allReceipts = [];
  bool _isLoading = true;
  bool _isActionLoading = false; 
  bool _isAscending = true;      

  @override
  void initState() {
    super.initState();
    _refreshIconController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fetchSupabaseData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _refreshIconController.dispose();
    super.dispose();
  }

  Future<void> _fetchSupabaseData() async {
    try {
      if (mounted && !_isLoading) {
        _refreshIconController.repeat();
      }

      final response = await _supabase.from('RECEIPT').select('''
        receipt_id,
        issued_at,
        preorder_id,
        message,
        PREORDER (
          status,
          customer_id,
          total_price,
          CUSTOMER (
            gmail,
            full_name,
            phone
          ),
          PREORDER_ITEMS (
            quantity,
            furniture_id,
            FURNITURE (
              furniture_name,
              price
            )
          )
        )
      ''');

      if (mounted) {
        setState(() {
          _allReceipts = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
        _refreshIconController.forward(from: _refreshIconController.value).then((_) {
          _refreshIconController.reset();
        });
      }
    } catch (e) {
      debugPrint("❌ Fetch Error: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        _refreshIconController.reset();
      }
    }
  }

  Future<void> _showDenyDialog(dynamic preorderId, dynamic receiptId) async {
    final TextEditingController messageController = TextEditingController();
    bool confirmed = false;
    String enteredMessage = '';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFFF9F6F1),
        title: const Text(
          "Deny Receipt",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Please provide a reason for denying this receipt:",
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: messageController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Enter denial reason...",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.brown),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.black38)),
          ),
          ElevatedButton(
            onPressed: () {
              enteredMessage = messageController.text.trim();
              confirmed = true;
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB06A6A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text("Confirm Deny"),
          ),
        ],
      ),
    );

    messageController.dispose();

    if (confirmed && mounted) {
      Navigator.pop(context);
      await _updateStatus(preorderId, 'Denied', receiptId: receiptId, message: enteredMessage);
    }
  }

  Future<void> _updateStatus(
    dynamic preorderId,
    String newStatus, {
    dynamic receiptId,
    String? message,
  }) async {
    try {
      if (mounted) setState(() => _isActionLoading = true);

      final updatedPreorder = await _supabase
          .from('PREORDER')
          .update({'status': newStatus})
          .eq('preorder_id', preorderId)
          .select();

      debugPrint("✅ PREORDER update result: $updatedPreorder");

      if (updatedPreorder == null || updatedPreorder.isEmpty) {
        debugPrint("⚠️ No PREORDER rows updated. Check RLS.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("PREORDER update failed! Check Supabase RLS write permissions."),
              backgroundColor: Colors.orange,
            ),
          );
          setState(() => _isActionLoading = false);
        }
        return;
      }

      if (newStatus == 'Denied' && receiptId != null) {
        debugPrint("📝 Writing message to RECEIPT receipt_id=$receiptId: '$message'");

        final updatedReceipt = await _supabase
            .from('RECEIPT')
            .update({'message': message ?? ''})
            .eq('receipt_id', receiptId)
            .select();

        debugPrint("✅ RECEIPT message update result: $updatedReceipt");

        if (updatedReceipt == null || updatedReceipt.isEmpty) {
          debugPrint("⚠️ RECEIPT message update failed. Check RLS UPDATE policy for RECEIPT table.");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Message save failed! Check Supabase RLS UPDATE policy for RECEIPT table."),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }

      if (mounted) {
        setState(() {
          selectedTab = newStatus;
          _isActionLoading = false;
        });
        await _fetchSupabaseData();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'Denied'
                  ? "Receipt denied${message != null && message.isNotEmpty ? ': $message' : '.'}"
                  : "Receipt marked as $newStatus",
            ),
            backgroundColor: newStatus.toLowerCase() == 'approved'
                ? Colors.green
                : Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ Update Error: $e");
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  List<Map<String, dynamic>> _getFilteredReceiptsList() {
    final filtered = _allReceipts.where((receipt) {
      final dynamic preorderRaw = receipt['PREORDER'] ?? receipt['preorder'];
      Map<String, dynamic>? preorder;

      if (preorderRaw is List && preorderRaw.isNotEmpty) {
        preorder = preorderRaw.first;
      } else if (preorderRaw is Map<String, dynamic>) {
        preorder = preorderRaw;
      }

      final status = preorder?['status'] ?? 'Pending';
      final matchesSearch = receipt['receipt_id'].toString().contains(query);
      final matchesTab = status.toString().toLowerCase() == selectedTab.toLowerCase();

      return matchesSearch && matchesTab;
    }).toList();

    filtered.sort((a, b) {
      final idA = int.tryParse(a['receipt_id'].toString()) ?? 0;
      final idB = int.tryParse(b['receipt_id'].toString()) ?? 0;
      return _isAscending ? idA.compareTo(idB) : idB.compareTo(idA);
    });

    return filtered;
  }

  String _getEmptyMessage() {
    if (query.isNotEmpty) {
      return 'There are no receipts matching "$query" under $selectedTab';
    }
    switch (selectedTab.toLowerCase()) {
      case 'approved':
        return 'There are no "approved" receipts';
      case 'denied':
        return 'There are no "denied" receipts';
      default:
        return 'There are no "pending" receipts';
    }
  }

  void _showReceiptDetails(
    Map<String, dynamic> receipt,
    Map<String, dynamic> preorder,
  ) {
    final customerData = preorder['CUSTOMER'] ?? preorder['customer'];
    final currentCustomerId = preorder['customer_id'];
    final customerEmail = customerData != null ? (customerData['gmail'] ?? 'N/A') : 'N/A';
    final customerName = customerData != null ? (customerData['full_name'] ?? 'Unknown Customer') : 'Unknown Customer';
    final customerPhone = customerData != null ? (customerData['phone'] ?? 'N/A') : 'N/A';
    final targetPreorderId = receipt['preorder_id'];
    final targetReceiptId = receipt['receipt_id'];
    final String? denialMessage = receipt['message'] as String?;
    final String currentStatus = (preorder['status'] ?? 'Pending').toString();

    final List<Map<String, dynamic>> flattenedCustomerItems = [];
    double calculatedGrandTotal = 0.0;

    for (var r in _allReceipts) {
      final dynamic pRaw = r['PREORDER'] ?? r['preorder'];
      Map<String, dynamic>? p;

      if (pRaw is List && pRaw.isNotEmpty) {
        p = pRaw.first;
      } else if (pRaw is Map<String, dynamic>) {
        p = pRaw;
      }

      if (p != null && p['customer_id'] == currentCustomerId) {
        final List itemsList = p['PREORDER_ITEMS'] ?? p['preorder_items'] ?? [];
        for (var item in itemsList) {
          final furnitureData = item['FURNITURE'] ?? item['furniture'];
          final String name = furnitureData != null
              ? (furnitureData['furniture_name'] ?? "Unknown Furniture")
              : "Unknown Furniture";
          final int qty = (item['quantity'] ?? 0) as int;
          final double unitPrice =
              furnitureData != null ? (furnitureData['price'] ?? 0.0).toDouble() : 0.0;
          final double computedLineTotal = qty * unitPrice;
          calculatedGrandTotal += computedLineTotal;

          flattenedCustomerItems.add(<String, dynamic>{
            'furniture_name': name,
            'quantity': qty,
            'line_total': computedLineTotal,
          });
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          backgroundColor: const Color(0xFFF9F6F1),
          content: SizedBox(
            width: 550,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Receipt ID: $targetReceiptId",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black54),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Name: $customerName",
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14, color: Colors.brown),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Email: $customerEmail",
                            style: const TextStyle(color: Colors.black45, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text("Phone: $customerPhone",
                            style: const TextStyle(color: Colors.black45, fontSize: 14)),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 30, thickness: 1.2),

                if (currentStatus.toLowerCase() == 'denied' &&
                    denialMessage != null &&
                    denialMessage.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.cancel_outlined, color: Colors.red.shade400, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Denial Reason",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.red.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                denialMessage,
                                style: TextStyle(fontSize: 13, color: Colors.red.shade800),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Expanded(
                      flex: 4,
                      child: Text("All Preordered Furniture:",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text("Item Price",
                          textAlign: TextAlign.end,
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                WidgetBC(flattenedCustomerItems: flattenedCustomerItems),
                const SizedBox(height: 10),
                const Divider(thickness: 1.0, color: Colors.black12),

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Total Price:",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black54)),
                      Text(
                        "₱${calculatedGrandTotal.toStringAsFixed(2)}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18, color: Colors.brown),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (currentStatus.toLowerCase() == 'pending')
                  _isActionLoading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(color: Colors.brown),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton(
                              onPressed: () async {
                                setModalState(() => _isActionLoading = true);
                                Navigator.pop(context);
                                await _updateStatus(targetPreorderId, 'Approved');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE6DED6),
                                foregroundColor: Colors.brown,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                              child: const Text("Approve Receipt"),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () => _showDenyDialog(targetPreorderId, targetReceiptId),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFB06A6A),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                              child: const Text("Deny Receipt"),
                            ),
                            const SizedBox(width: 12),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Close", style: TextStyle(color: Colors.black38)),
                            ),
                          ],
                        )
                else
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Close", style: TextStyle(color: Colors.black38)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChromeTab(String title) {
    int count = 0;
    for (var receipt in _allReceipts) {
      final dynamic preorderRaw = receipt['PREORDER'] ?? receipt['preorder'];
      Map<String, dynamic>? preorder;

      if (preorderRaw is List && preorderRaw.isNotEmpty) {
        preorder = preorderRaw.first;
      } else if (preorderRaw is Map<String, dynamic>) {
        preorder = preorderRaw;
      }

      final status = preorder?['status'] ?? 'Pending';
      if (status.toString().toLowerCase() == title.toLowerCase()) count++;
    }

    final bool isSelected = selectedTab.toLowerCase() == title.toLowerCase();

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedTab = title),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.only(top: 18, bottom: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? const Color(0xFF7A9E9F) : Colors.black12,
                width: isSelected ? 3 : 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.black87 : Colors.black45,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7A9E9F),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    count.toString(),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredReceipts = _getFilteredReceiptsList();

    return Scaffold(
      backgroundColor: const Color.fromRGBO(249, 246, 241, 1.0),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Customer Receipts',
                style: TextStyle(
                    color: Colors.brown, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => query = value),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: "Search by Receipt ID...",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                    child: AnimatedBuilder(
                      animation: _refreshIconController,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _refreshIconController.value * 2 * math.pi,
                          child: child,
                        );
                      },
                      child: IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.brown),
                        onPressed: _fetchSupabaseData,
                        tooltip: "Refresh database data",
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              
              Center(
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 1000),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, left: 16, right: 16),
                        child: Row(
                          children: [
                            _buildChromeTab('Pending'),
                            _buildChromeTab('Approved'),
                            _buildChromeTab('Denied'),
                          ],
                        ),
                      ),

                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 16),
                        decoration: const BoxDecoration(
                          border: Border(
                              bottom:
                                  BorderSide(color: Colors.black12, width: 1.5)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () {
                                  setState(() {
                                    _isAscending = !_isAscending;
                                  });
                                },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const HeaderText("ID"),
                                    const SizedBox(width: 4),
                                    Icon(
                                      _isAscending ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                                      size: 18,
                                      color: Colors.brown,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Expanded(child: HeaderText("Date Submitted")),
                            const Expanded(child: HeaderText("Customer Email")),
                            const Expanded(child: HeaderText("Total Items")),
                            const Expanded(child: HeaderText("Status")),
                            const Expanded(child: HeaderText("Action")),
                          ],
                        ),
                      ),

                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.all(40.0),
                          child: CircularProgressIndicator(color: Colors.brown),
                        )
                      else if (filteredReceipts.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(50.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.assignment_turned_in_outlined,
                                  size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                _getEmptyMessage(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Column(
                          children: filteredReceipts.map((receipt) {
                            final dynamic preorderRaw =
                                receipt['PREORDER'] ?? receipt['preorder'];
                            Map<String, dynamic>? preorder;

                            if (preorderRaw is List && preorderRaw.isNotEmpty) {
                              preorder = preorderRaw.first;
                            } else if (preorderRaw is Map<String, dynamic>) {
                              preorder = preorderRaw;
                            }

                            final customerData = preorder != null
                                ? (preorder['CUSTOMER'] ?? preorder['customer'])
                                : null;
                            final String email = customerData != null
                                ? (customerData['gmail'] ?? 'N/A')
                                : 'N/A';
                            int totalQuantity = 0;

                            if (preorder != null) {
                              final List itemsList =
                                  preorder['PREORDER_ITEMS'] ??
                                      preorder['preorder_items'] ??
                                      [];
                              for (var i in itemsList) {
                                totalQuantity += (i['quantity'] ?? 0) as int;
                              }
                            }

                            return tableRow(
                              receipt['receipt_id'].toString(),
                              receipt['issued_at'].toString().substring(0, 10),
                              email,
                              totalQuantity.toString(),
                              preorder != null
                                  ? (preorder['status'] ?? 'Pending')
                                  : 'Pending',
                              onView: () =>
                                  _showReceiptDetails(receipt, preorder!),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget tableRow(
    String id,
    String date,
    String email,
    String items,
    String status, {
    required VoidCallback onView,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: Row(
        children: [
          Expanded(child: CellText(id)),
          Expanded(child: CellText(date)),
          Expanded(child: CellText(email)),
          Expanded(child: CellText(items)),
          Expanded(
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: status.toLowerCase() == 'pending'
                      ? const Color(0xFFEBE3D5)
                      : status.toLowerCase() == 'approved'
                          ? Colors.green.shade100
                          : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    color: status.toLowerCase() == 'pending'
                        ? Colors.black87
                        : status.toLowerCase() == 'approved'
                            ? Colors.green.shade800
                            : Colors.red.shade800,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: InkWell(
                onTap: onView,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F4F0),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    "View",
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WidgetBC extends StatelessWidget {
  const WidgetBC({
    super.key,
    required this.flattenedCustomerItems,
  });

  final List<Map<String, dynamic>> flattenedCustomerItems;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 200),
      child: flattenedCustomerItems.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text("No items found for this customer.",
                  style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
            )
          : ListView.builder(
              shrinkWrap: true,
              itemCount: flattenedCustomerItems.length,
              itemBuilder: (context, index) {
                final item = flattenedCustomerItems[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        flex: 4,
                        child: Row(
                          children: [
                            const Icon(Icons.lens, size: 10, color: Colors.brown),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "${item['furniture_name']} (${item['quantity']})",
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14, color: Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          "₱${item['line_total'].toStringAsFixed(2)}",
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class HeaderText extends StatelessWidget {
  final String text;
  const HeaderText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
          fontWeight: FontWeight.bold, color: Colors.black87),
    );
  }
}

class CellText extends StatelessWidget {
  final String text;
  const CellText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }
}