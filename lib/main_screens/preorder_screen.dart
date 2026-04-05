import 'package:flutter/material.dart';

class Preorder extends StatefulWidget {
  const Preorder({super.key});

  static String get routeName => '/preorder';

  @override
  State<Preorder> createState() => _PreorderState();
}

class _PreorderState extends State<Preorder> {
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(249, 246, 241, 1.0),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                "POPULAR ITEMS",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: Color.fromARGB(255, 56, 37, 29),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // para sa search
            const Text(
              "Search",
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 8),

            SizedBox(
              width: 280,
              height: 40,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.brown.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.brown),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // for table
            Center(
              child: Container(
                width: 1000,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.brown.shade300,
                            width: 2, // 
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: const [
                          Text("Furniture",
                              style: TextStyle(
                                  fontWeight: FontWeight.w500)),
                          Text("Frequency",
                              style: TextStyle(
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),

                    _buildRow("Model B", "39"),
                    _buildRow("Model A", "32"),
                    _buildRow("Model D", "19"),
                    _buildRow("Model C", "14"),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String name, String freq) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.brown.shade100,
            width: 0.8, 
          ),
        ),
      ),                                                                                                                                     
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name),
          Text(freq),
        ],
      ),
    );
  }
}