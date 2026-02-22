import 'package:flutter/material.dart';

import '../models/polling_station.dart';
import '../services/sqlite_service.dart';
import '../widgets/station_edit_alert_dialog.dart';
import 'home_screen.dart';

class EditStationFormScreen extends StatefulWidget {
  final PollingStation station;

  const EditStationFormScreen({super.key, required this.station});

  @override
  State<EditStationFormScreen> createState() => _EditStationFormScreenState();
}

class _EditStationFormScreenState extends State<EditStationFormScreen> {
  static const _allowedPrefixes = <String>[
    'โรงเรียน',
    'วัด',
    'เต็นท์',
    'ศาลา',
    'หอประชุม',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtl;
  late final TextEditingController _zoneCtl;
  late final TextEditingController _provinceCtl;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController(text: widget.station.stationName);
    _zoneCtl = TextEditingController(text: widget.station.zone);
    _provinceCtl = TextEditingController(text: widget.station.province);
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _zoneCtl.dispose();
    _provinceCtl.dispose();
    super.dispose();
  }

  bool _isNamePrefixValid(String name) {
    return _allowedPrefixes.any(name.startsWith);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final stationName = _nameCtl.text.trim();
    final zone = _zoneCtl.text.trim();
    final province = _provinceCtl.text.trim();

    if (!_isNamePrefixValid(stationName)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ชื่อหน่วยไม่ถูกต้อง: ต้องขึ้นต้นด้วย โรงเรียน, วัด, เต็นท์, ศาลา, หอประชุม',
          ),
        ),
      );
      return;
    }

    final isDuplicate = await SqliteService.instance.isDuplicateStationName(
      stationId: widget.station.stationId,
      stationName: stationName,
    );
    if (isDuplicate) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ชื่อหน่วยซ้ำกับรายการอื่นในระบบ')),
      );
      return;
    }

    setState(() => _saving = true);
    final incidentCount = await SqliteService.instance
        .countIncidentsByStationId(widget.station.stationId);

    var confirmed = true;
    if (incidentCount > 0 && mounted) {
      final result = await showDialog<bool>(
        context: context,
        builder: (_) => StationEditAlertDialog(incidentCount: incidentCount),
      );
      confirmed = result == true;
    }

    if (!confirmed) {
      if (mounted) setState(() => _saving = false);
      return;
    }

    final updated = widget.station.copyWith(
      stationName: stationName,
      zone: zone,
      province: province,
    );

    await SqliteService.instance.updateStation(updated);
    if (!mounted) return;

    setState(() => _saving = false);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Station'),
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
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                initialValue: widget.station.stationId,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Station ID',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtl,
                decoration: const InputDecoration(
                  labelText: 'Station Name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please enter station name'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _zoneCtl,
                decoration: const InputDecoration(
                  labelText: 'Zone',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please enter zone'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _provinceCtl,
                decoration: const InputDecoration(
                  labelText: 'Province',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please enter province'
                    : null,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
