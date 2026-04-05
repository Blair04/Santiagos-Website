import 'package:flutter/material.dart';

class ManageReceipt extends StatefulWidget {
  const ManageReceipt({super.key});

  static String get routeName => '/manage-receipt';

  @override
  State<ManageReceipt> createState() => _ManageReceiptState();
}

class _ManageReceiptState extends State<ManageReceipt> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(249, 246, 241, 1.0),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // para sa search label
            const Text(
              "Search",
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),

            // for search bar
            SizedBox(
              width: 300,
              child: TextField(
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // container ng table
            Center(
              child: Container(
                width: 900,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
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

                    // ROWS
                    tableRow("3122131", "Nov 27, 2025",
                        "example@email.com", "3", "Pending"),
                    tableRow("1241444", "Nov 23, 2025",
                        "example@email.com", "1", "Approved"),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // for table example
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
          Expanded(child: Text(id)),
          Expanded(child: Text(date)),
          Expanded(child: Text(email)),
          Expanded(child: Text(items)),
          Expanded(child: Text(status)),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold, 
      ),
    );
  }
}