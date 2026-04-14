import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Initialize Supabase Client
final _supabase = Supabase.instance.client;

class ManageReceipt extends StatefulWidget {
  const ManageReceipt({super.key});

  static String get routeName => '/manage-receipt';

  @override
  State<ManageReceipt> createState() => _ManageReceiptState();
}

class _ManageReceiptState extends State<ManageReceipt> {
  final TextEditingController _searchController = TextEditingController();
  String query = "";
  List<Map<String, dynamic>> _allReceipts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSupabaseData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // FETCH: Reaches through all tables to get Furniture Names and Customer Emails
  Future<void> _fetchSupabaseData() async {
    try {
      final response = await _supabase.from('RECEIPT').select('''
        receipt_id,
        issued_at,
        preorder_id,
        PREORDER (
          status,
          customer_id,
          CUSTOMER (gmail),
          PREORDER_ITEMS (
            quantity,
            furniture_id,
            FURNITURE (furniture_name)
          )
        )
      ''');

      if (mounted) {
        setState(() {
          _allReceipts = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Fetch Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // UPDATE: Changes status of the preorder
  Future<void> _updateStatus(dynamic preorderId, String newStatus) async {
    try {
      await _supabase
          .from('PREORDER')
          .update({'status': newStatus})
          .eq('preorder_id', preorderId);

      if (mounted) {
        Navigator.pop(context); // Close modal
        _fetchSupabaseData();   // Refresh table data
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Receipt marked as $newStatus")),
        );
      }
    } catch (e) {
      debugPrint("Update Error: $e");
    }
  }

  // MODAL: Displays furniture names and quantity details
  void _showReceiptDetails(Map<String, dynamic> receipt, Map<String, dynamic> preorder) {
    final List itemsList = preorder['PREORDER_ITEMS'] ?? [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        backgroundColor: const Color(0xFFF9F6F1),
        content: SizedBox(
          width: 550,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Receipt ID: ${receipt['receipt_id']}", 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black54)),
                  Text("Email: ${preorder['CUSTOMER']['gmail']}", 
                    style: const TextStyle(color: Colors.black45, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 5),
              Align(
                alignment: Alignment.centerLeft,
                child: Text("Date: ${receipt['issued_at'].toString().substring(0, 10)}", 
                  style: const TextStyle(color: Colors.black45)),
              ),
              const Divider(height: 40, thickness: 1.2),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text("Items:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                  Padding(
                    padding: EdgeInsets.only(right: 20),
                    child: Text("Available:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: itemsList.length,
                  itemBuilder: (context, index) {
                    final item = itemsList[index];
                    final furnitureName = item['FURNITURE'] != null 
                        ? item['FURNITURE']['furniture_name'] 
                        : "Unknown Furniture";

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_box_outlined, size: 20),
                              const SizedBox(width: 10),
                              Text("$furnitureName (${item['quantity']})"),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black12),
                              borderRadius: BorderRadius.circular(15),
                              color: Colors.white,
                            ),
                            child: Row(
                              children: const [
                                Text("Yes", style: TextStyle(fontSize: 12)),
                                Icon(Icons.keyboard_arrow_down, size: 16),
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 40),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => _updateStatus(receipt['preorder_id'], 'Approved'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE6DED6),
                      foregroundColor: Colors.brown,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text("Approve Receipt"),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => _updateStatus(receipt['preorder_id'], 'Denied'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB06A6A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(249, 246, 241, 1.0),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Customer Receipts', 
                style: TextStyle(color: Colors.brown, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => query = value),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: "Search by Receipt ID...",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
              const SizedBox(height: 30),
              Center(
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 1000),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.black26, width: 1.5)),
                        ),
                        child: Row(
                          children: const [
                            Expanded(child: HeaderText("ID")),
                            Expanded(child: HeaderText("Date Submitted")),
                            Expanded(child: HeaderText("Customer Email")),
                            Expanded(child: HeaderText("Items")),
                            Expanded(child: HeaderText("Status")),
                            Expanded(child: HeaderText("Action")),
                          ],
                        ),
                      ),
                      if (_isLoading)
                        const Padding(padding: EdgeInsets.all(40.0), child: CircularProgressIndicator(color: Colors.brown))
                      else
                        Column(children: _filteredRows()),
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

  List<Widget> _filteredRows() {
    final filtered = _allReceipts.where((receipt) {
      return receipt['receipt_id'].toString().contains(query);
    }).toList();

    return filtered.map((receipt) {
      final dynamic preorderRaw = receipt['PREORDER'];
      Map<String, dynamic>? preorder;
      if (preorderRaw is List && preorderRaw.isNotEmpty) {
        preorder = preorderRaw.first;
      } else if (preorderRaw is Map<String, dynamic>) {
        preorder = preorderRaw;
      }

      String email = preorder?['CUSTOMER']?['gmail'] ?? 'N/A';
      
      int totalQuantity = 0;
      if (preorder != null && preorder['PREORDER_ITEMS'] != null) {
        for (var i in (preorder['PREORDER_ITEMS'] as List)) {
          totalQuantity += (i['quantity'] ?? 0) as int;
        }
      }

      return tableRow(
        receipt['receipt_id'].toString(),
        receipt['issued_at'].toString().substring(0, 10),
        email,
        totalQuantity.toString(),
        preorder?['status'] ?? 'Pending',
        onView: () => _showReceiptDetails(receipt, preorder!),
      );
    }).toList();
  }

  Widget tableRow(String id, String date, String email, String items, String status, {required VoidCallback onView}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black12))),
      child: Row(
        children: [
          Expanded(child: CellText(id)),
          Expanded(child: CellText(date)),
          Expanded(child: CellText(email)),
          Expanded(child: CellText(items)),
          Expanded(child: CellText(status)),
          Expanded(
            child: Center(
              child: InkWell(
                onTap: onView,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFE6DED6), borderRadius: BorderRadius.circular(20)),
                  child: const Text("View", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HeaderText extends StatelessWidget {
  final String text;
  const HeaderText(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Center(child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)));
}

class CellText extends StatelessWidget {
  final String text;
  const CellText(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(text, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, maxLines: 1);
}