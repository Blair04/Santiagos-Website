import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _supabase = Supabase.instance.client;

class Preorder extends StatefulWidget {
  const Preorder({super.key});

  static String get routeName => '/preorder';

  @override
  State<Preorder> createState() => _PreorderState();
}

class _PreorderState extends State<Preorder> {
  final TextEditingController _searchController = TextEditingController();
  List<String> searchHistory = [];
  String query = "";

  List<Map<String, dynamic>> _popularItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPopularItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Fetches furniture names and counts how many times each has been preordered
  Future<void> _fetchPopularItems() async {
    try {
      // We join PREORDER with FURNITURE to get the names
      final response = await _supabase
          .from('PREORDER')
          .select('FURNITURE(furniture_name)');

      // Logic to count frequency of each furniture name
      Map<String, int> counts = {};
      for (var item in response) {
        String name = item['FURNITURE']['furniture_name'] ?? 'Unknown';
        counts[name] = (counts[name] ?? 0) + 1;
      }

      // Sort by frequency (descending)
      var sortedList = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      if (mounted) {
        setState(() {
          _popularItems = sortedList.map((e) => {'name': e.key, 'count': e.value}).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
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
      body: SingleChildScrollView( // Allows the whole page to scroll as the table grows
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  "POPULAR ITEMS",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: Colors.brown,
                  ),
                ),
              ),
              const SizedBox(height: 25),
              TextField(
                controller: _searchController,
                onSubmitted: (value) => addToHistory(value),
                onChanged: (value) => setState(() => query = value),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: "Search furniture...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // ADAPTIVE CONTAINER
              Center(
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
                    mainAxisSize: MainAxisSize.min, // Shrink-wraps height
                    children: [
                      // HEADER
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.black26, width: 1.5),
                          ),
                        ),
                        child: Row(
                          children: const [
                            Expanded(child: HeaderText("Furniture")),
                            Expanded(child: HeaderText("Frequency")),
                          ],
                        ),
                      ),

                      // DATA ROWS
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.all(40.0),
                          child: CircularProgressIndicator(color: Colors.brown),
                        )
                      else if (_popularItems.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(40.0),
                          child: Text("No preorders recorded yet."),
                        )
                      else
                        Column(
                          children: _filteredRows(),
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

  List<Widget> _filteredRows() {
    final filtered = _popularItems.where((item) {
      return item['name'].toString().toLowerCase().contains(query.toLowerCase());
    }).toList();

    return filtered
        .map((item) => _buildRow(item['name'], item['count'].toString()))
        .toList();
  }

  Widget _buildRow(String name, String freq) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.black12),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: CellText(name)),
          Expanded(child: CellText(freq)),
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
        style: const TextStyle(fontWeight: FontWeight.bold),
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