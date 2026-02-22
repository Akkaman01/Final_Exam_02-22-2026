import 'package:flutter/material.dart';

import '../services/sqlite_service.dart';
import '../widgets/severity_dropdown.dart';
import 'home_screen.dart';

class SearchFilterScreen extends StatefulWidget {
  const SearchFilterScreen({super.key});

  @override
  State<SearchFilterScreen> createState() => _SearchFilterScreenState();
}

class _SearchFilterScreenState extends State<SearchFilterScreen> {
  final _keywordCtl = TextEditingController();
  String? _severity;
  bool _loading = false;
  List<Map<String, Object?>> _rows = [];

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _keywordCtl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    final data = await SqliteService.instance.searchReports(
      keyword: _keywordCtl.text.trim(),
      severity: _severity,
    );

    if (!mounted) return;
    setState(() {
      _rows = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search & Filter'),
        actions: [
          IconButton(
            tooltip: 'Home',
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _keywordCtl,
              decoration: const InputDecoration(
                labelText: 'Keyword',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 12),
            SeverityDropdown(
              value: _severity,
              onChanged: (v) {
                setState(() => _severity = v);
                _search();
              },
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _search,
                icon: const Icon(Icons.search),
                label: const Text('Search'),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _rows.isEmpty
                  ? const Center(child: Text('No records found'))
                  : ListView.builder(
                      itemCount: _rows.length,
                      itemBuilder: (_, index) {
                        final row = _rows[index];
                        return Card(
                          child: ListTile(
                            title: Text(
                              '${(row['reporter_name'] ?? '-')} - ${(row['type_name'] ?? '-')}',
                            ),
                            subtitle: Text(
                              '${(row['station_name'] ?? '-')}\n${(row['description'] ?? '-')}',
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
