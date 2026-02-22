import 'package:flutter/material.dart';

import '../models/polling_station.dart';
import '../services/sqlite_service.dart';
import 'edit_station_form_screen.dart';
import 'home_screen.dart';

class EditStationListScreen extends StatefulWidget {
  const EditStationListScreen({super.key});

  @override
  State<EditStationListScreen> createState() => _EditStationListScreenState();
}

class _EditStationListScreenState extends State<EditStationListScreen> {
  bool _loading = true;
  List<PollingStation> _stations = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await SqliteService.instance.getStations();
    if (!mounted) return;
    setState(() {
      _stations = rows;
      _loading = false;
    });
  }

  Future<void> _openEdit(PollingStation station) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditStationFormScreen(station: station),
      ),
    );

    if (changed == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Polling Station'),
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _stations.isEmpty
          ? const Center(child: Text('No polling stations'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _stations.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, index) {
                final s = _stations[index];
                return Card(
                  child: ListTile(
                    title: Text(s.stationName),
                    subtitle: Text('${s.zone} - ${s.province}'),
                    trailing: const Icon(Icons.edit),
                    onTap: () => _openEdit(s),
                  ),
                );
              },
            ),
    );
  }
}
