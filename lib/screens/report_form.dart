import 'dart:io';

import 'package:flutter/material.dart';

import '../models/incident_report.dart';
import '../models/polling_station.dart';
import '../models/violation_type.dart';
import '../services/ai_inference_service.dart';
import '../services/firebase_service.dart';
import '../services/image_picker_service.dart';
import '../services/sqlite_service.dart';
import '../widgets/form_text_field.dart';
import 'home_screen.dart';

class ReportFormScreen extends StatefulWidget {
  final int? editReportId;

  const ReportFormScreen({super.key, this.editReportId});

  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _reporterCtl = TextEditingController();
  final _descCtl = TextEditingController();
  final _photoCtl = TextEditingController();
  final _aiResultCtl = TextEditingController();
  final _aiConfCtl = TextEditingController();

  List<PollingStation> _stations = [];
  List<ViolationType> _types = [];

  String? _stationId;
  String? _typeId;
  bool _loading = true;
  bool _saving = false;
  int? _reportId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _reporterCtl.dispose();
    _descCtl.dispose();
    _photoCtl.dispose();
    _aiResultCtl.dispose();
    _aiConfCtl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    await SqliteService.instance.ensureInitialized();
    await AiInferenceService.instance.loadModel();

    final stations = await SqliteService.instance.getStations();
    final types = await SqliteService.instance.getViolationTypes();

    _stations = stations;
    _types = types;

    if (widget.editReportId != null) {
      final row = await SqliteService.instance.getReportByIdJoin(
        widget.editReportId!,
      );
      if (row != null) {
        _reportId = row['report_id'] as int;
        _stationId = row['station_id'] as String;
        _typeId = row['type_id'] as String;
        _reporterCtl.text = (row['reporter_name'] ?? '').toString();
        _descCtl.text = (row['description'] ?? '').toString();
        _photoCtl.text = (row['evidence_photo'] ?? '').toString();
        _aiResultCtl.text = (row['ai_result'] ?? '').toString();
        _aiConfCtl.text = row['ai_confidence']?.toString() ?? '';
      }
    } else {
      _stationId = _stations.isNotEmpty ? _stations.first.stationId : null;
      _typeId = _types.isNotEmpty ? _types.first.typeId : null;
    }

    setState(() => _loading = false);
  }

  String _nowText() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)} ${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
  }

  Future<void> _pickFromCamera() async {
    final path = await ImagePickerService.instance.pickFromCamera();
    if (path == null || !mounted) return;
    setState(() => _photoCtl.text = path);
  }

  Future<void> _pickFromGallery() async {
    final path = await ImagePickerService.instance.pickFromGallery();
    if (path == null || !mounted) return;
    setState(() => _photoCtl.text = path);
  }

  Future<void> _runAi() async {
    final photoPath = _photoCtl.text.trim();
    if (photoPath.isEmpty) return;
    final result = await AiInferenceService.instance.classifyImage(photoPath);
    final mappedTypeName = AiInferenceService.instance.mapResultToViolationName(
      result,
    );
    String? mappedTypeId;
    if (mappedTypeName.isNotEmpty) {
      mappedTypeId = await SqliteService.instance.findViolationTypeIdByName(
        mappedTypeName,
      );
    }

    if (!mounted) return;
    setState(() {
      _aiResultCtl.text = result.label;
      _aiConfCtl.text = result.confidence.toStringAsFixed(2);
      if (mappedTypeId != null) _typeId = mappedTypeId;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_stationId == null || _typeId == null) return;

    setState(() => _saving = true);
    final aiConf = _aiConfCtl.text.trim().isEmpty
        ? null
        : double.tryParse(_aiConfCtl.text.trim());

    final report = IncidentReport(
      reportId: _reportId,
      stationId: _stationId!,
      typeId: _typeId!,
      reporterName: _reporterCtl.text.trim(),
      description: _descCtl.text.trim().isEmpty ? null : _descCtl.text.trim(),
      evidencePhoto: _photoCtl.text.trim().isEmpty
          ? null
          : _photoCtl.text.trim(),
      timestamp: _nowText(),
      aiResult: _aiResultCtl.text.trim().isEmpty
          ? null
          : _aiResultCtl.text.trim(),
      aiConfidence: aiConf,
    );

    if (_reportId == null) {
      await SqliteService.instance.insertReport(report);
    } else {
      await SqliteService.instance.updateReport(report);
    }

    final onlineResult = await FirebaseService.instance.saveIncidentOnline(
      report.toMap(),
    );
    if (!mounted) return;

    setState(() => _saving = false);
    if (onlineResult.success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saved: Offline + Online')));
      Navigator.pop(context, true);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved offline only. ${onlineResult.message}')),
    );
  }

  Widget _buildPhotoPreview() {
    Widget placeholder() {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          'assets/images/download.png',
          height: 180,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }

    final value = _photoCtl.text.trim();
    if (value.isEmpty) return placeholder();

    final isUrl = value.startsWith('http://') || value.startsWith('https://');
    if (isUrl) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          value,
          height: 180,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => placeholder(),
        ),
      );
    }

    final file = File(value);
    if (file.existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          file,
          height: 180,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }
    return placeholder();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editReportId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Report' : 'Report Incident'),
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
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _stationId,
                      decoration: const InputDecoration(
                        labelText: 'Polling Station',
                        border: OutlineInputBorder(),
                      ),
                      items: _stations
                          .map(
                            (s) => DropdownMenuItem(
                              value: s.stationId,
                              child: Text('${s.stationName} (${s.province})'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _stationId = v),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Please select a polling station'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _typeId,
                      decoration: const InputDecoration(
                        labelText: 'Violation Type',
                        border: OutlineInputBorder(),
                      ),
                      items: _types
                          .map(
                            (t) => DropdownMenuItem(
                              value: t.typeId,
                              child: Text('${t.typeName} (${t.severity})'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _typeId = v),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Please select a violation type'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    FormTextField(
                      label: 'Reporter Name',
                      controller: _reporterCtl,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter reporter name'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    FormTextField(
                      label: 'Description',
                      controller: _descCtl,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickFromCamera,
                            icon: const Icon(Icons.photo_camera),
                            label: const Text('Camera'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickFromGallery,
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Gallery'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildPhotoPreview(),
                    const SizedBox(height: 12),
                    FormTextField(
                      label: 'Evidence Photo Path',
                      controller: _photoCtl,
                    ),
                    const SizedBox(height: 12),
                    FormTextField(label: 'AI Result', controller: _aiResultCtl),
                    const SizedBox(height: 12),
                    FormTextField(
                      label: 'AI Confidence (0-1)',
                      controller: _aiConfCtl,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _runAi,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Run AI'),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: const Text('Save (Offline + Online)'),
                      onPressed: _saving ? null : _save,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
