import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class MedicationImageService {
  static const bucket = 'medication-images';
  final SupabaseClient _client = Supabase.instance.client;

  String pathFor({required String patientId, required String medicationId}) =>
      '$patientId/$medicationId.jpg';

  Future<String> upload({
    required String patientId,
    required String medicationId,
    required Uint8List bytes,
  }) async {
    final path = pathFor(patientId: patientId, medicationId: medicationId);
    await _client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    return path;
  }

  Future<String?> signedUrl(String? storagePath) async {
    if (storagePath == null || storagePath.isEmpty) return null;
    // Backward compatible with any legacy absolute URL already stored.
    if (storagePath.startsWith('http://') || storagePath.startsWith('https://')) {
      return storagePath;
    }
    return _client.storage.from(bucket).createSignedUrl(storagePath, 3600);
  }

  Future<void> delete(String? storagePath) async {
    if (storagePath == null || storagePath.isEmpty) return;
    if (storagePath.startsWith('http://') || storagePath.startsWith('https://')) return;
    await _client.storage.from(bucket).remove([storagePath]);
  }
}
