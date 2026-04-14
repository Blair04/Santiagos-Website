import 'package:flutter/material.dart';

class ManageReceipt extends StatefulWidget {
  const ManageReceipt({super.key});

  static String get routeName => '/manage-receipt';

  @override
  State<ManageReceipt> createState() => _ManageReceiptState();
}

class _ManageReceiptState extends State<ManageReceipt> {
  final TextEditingController _searchController = TextEditingController();
  List<String> searchHistory = [];
  String query = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void addToHistory(String value) {
    if (value.isNotEmpty && !searchHistory.contains(value)) {
      setState(() {
        searchHistory.insert(0, value);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(249, 246, 241, 1.0),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Customer Receipts',
              style: TextStyle(
                color: Colors.brown,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            // Search bar
            TextField(
              controller: _searchController,
              onSubmitted: (value) {
                addToHistory(value);
              },
              onChanged: (value) {
                setState(() {
                  query = value;
                });
              },
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: "Search receipts...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),

            const SizedBox(height: 30),

            Expanded(
              child: Center(
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 900),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // HEADER
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 16),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.black26,
                              width: 1.5,
                            ),
                          ),
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

                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: _filteredRows(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _filteredRows() {
    final data = [
      ["3122131", "Nov 27, 2025", "example@email.com", "3", "Pending"],
      ["1241444", "Nov 23, 2025", "example@email.com", "1", "Approved"],
    ];

    final filtered = data.where((row) {
      return row.any((element) =>
          element.toLowerCase().contains(query.toLowerCase()));
    }).toList();

    return filtered
        .map((row) => tableRow(
            row[0], row[1], row[2], row[3], row[4]))
        .toList();
  }

  Widget tableRow(String id, String date, String email, String items, String status) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.black12),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: CellText(id)),
          Expanded(child: CellText(date)),
          Expanded(child: CellText(email)),
          Expanded(child: CellText(items)),
          Expanded(child: CellText(status)),
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6DED6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text("View"),
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
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
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
