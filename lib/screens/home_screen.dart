import 'package:flutter/material.dart';
import '../services/sqlite_service.dart';
import 'edit_station_list_screen.dart';
import 'report_form.dart';
import 'report_list.dart';
import 'search_filter_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  bool _hadDatabase = false;
  DashboardSummary? _summary;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    final hadDb = await SqliteService.instance.hasDatabaseFile();
    await SqliteService.instance.ensureInitialized();
    final summary = await SqliteService.instance.getDashboardSummary();
    if (!mounted) return;
    setState(() {
      _hadDatabase = hadDb;
      _summary = summary;
      _loading = false;
    });
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    await _init();
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    return Scaffold(
      appBar: AppBar(title: const Text('Election Watch')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _init,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Dashboard',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _hadDatabase
                                ? 'SQLite: พบไฟล์ฐานข้อมูลแล้ว'
                                : 'SQLite: ยังไม่พบไฟล์เดิม ระบบสร้างไฟล์ใหม่แล้ว',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'จำนวนการแจ้งเหตุทั้งหมด (Offline): ${summary?.totalOfflineReports ?? 0}',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Top 3 หน่วยเลือกตั้งที่ถูกร้องเรียน',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          if (summary == null || summary.topStations.isEmpty)
                            const Text('- ไม่มีข้อมูล -')
                          else
                            ...summary.topStations.asMap().entries.map((entry) {
                              final rank = entry.key + 1;
                              final row = entry.value;
                              final name =
                                  row['station_name']?.toString() ?? '-';
                              final count =
                                  row['report_count']?.toString() ?? '0';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('$rank. $name ($count เรื่อง)'),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () => _open(const ReportFormScreen()),
                    icon: const Icon(Icons.add_alert),
                    label: const Text('Report Incident'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _open(const EditStationListScreen()),
                    icon: const Icon(Icons.edit_location_alt),
                    label: const Text('Edit Polling Station'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _open(const ReportListScreen()),
                    icon: const Icon(Icons.list_alt),
                    label: const Text('Incident List'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _open(const SearchFilterScreen()),
                    icon: const Icon(Icons.manage_search),
                    label: const Text('Search & Filter'),
                  ),
                ],
              ),
            ),
    );
  }
}
