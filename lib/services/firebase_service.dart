import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class OnlineSaveResult {
  final bool success;
  final String message;

  const OnlineSaveResult({required this.success, required this.message});
}

class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  Future<void> _ensureInitialized() async {
    if (Firebase.apps.isNotEmpty) return;
    await Firebase.initializeApp();
  }

  String? normalizePhotoForCloud(String? evidencePhoto) {
    if (evidencePhoto == null || evidencePhoto.trim().isEmpty) return null;
    final value = evidencePhoto.trim();
    final isUrl = value.startsWith('http://') || value.startsWith('https://');
    return isUrl ? value : 'OFFLINE_ONLY';
  }

  String _safeDocIdFromReporter(String? reporterName) {
    final raw = (reporterName ?? '').trim();
    if (raw.isEmpty) return 'unknown_reporter';
    return raw.replaceAll('/', '_');
  }

  Future<OnlineSaveResult> saveIncidentOnline(
    Map<String, Object?> payload,
  ) async {
    try {
      await _ensureInitialized();
      final cloned = Map<String, Object?>.from(payload);
      cloned['evidence_photo'] = normalizePhotoForCloud(
        cloned['evidence_photo']?.toString(),
      );
      final docId = _safeDocIdFromReporter(cloned['reporter_name']?.toString());
      await FirebaseFirestore.instance
          .collection('incident_report')
          .doc(docId)
          .set(cloned);
      return const OnlineSaveResult(success: true, message: 'Online saved');
    } on FirebaseException catch (e) {
      debugPrint('Firebase save failed: ${e.code} ${e.message}');
      return OnlineSaveResult(
        success: false,
        message: 'Firebase error: ${e.code} ${e.message ?? ''}'.trim(),
      );
    } catch (e) {
      return OnlineSaveResult(success: false, message: 'Unknown error: $e');
    }
  }

  Future<OnlineSaveResult> deleteIncidentOnlineByReporterName(
    String reporterName,
  ) async {
    try {
      await _ensureInitialized();
      final collection = FirebaseFirestore.instance.collection(
        'incident_report',
      );
      final docId = _safeDocIdFromReporter(reporterName);
      await collection.doc(docId).delete();

      final legacy = await collection
          .where('reporter_name', isEqualTo: reporterName)
          .get();
      for (final doc in legacy.docs) {
        await doc.reference.delete();
      }

      return const OnlineSaveResult(success: true, message: 'Online deleted');
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') {
        return const OnlineSaveResult(
          success: true,
          message: 'Online record not found',
        );
      }
      return OnlineSaveResult(
        success: false,
        message: 'Firebase error: ${e.code} ${e.message ?? ''}'.trim(),
      );
    } catch (e) {
      return OnlineSaveResult(success: false, message: 'Unknown error: $e');
    }
  }
}
