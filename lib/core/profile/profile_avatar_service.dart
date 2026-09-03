import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileAvatarService {
  ProfileAvatarService._();
  static final instance = ProfileAvatarService._();

  static const bucket = 'profile-avatars';
  final _client = Supabase.instance.client;
  final _picker = ImagePicker();

  Future<String?> pickAndUpload() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 82,
    );
    if (image == null) return null;

    final bytes = await image.readAsBytes();
    final contentType = _contentType(image.mimeType, image.path);
    final extension = _extension(contentType);
    final path = '${user.id}/avatar.$extension';

    await _client.storage.from(bucket).uploadBinary(
      path,
      Uint8List.fromList(bytes),
      fileOptions: FileOptions(contentType: contentType, upsert: true),
    );

    final url = _client.storage.from(bucket).getPublicUrl(path);
    await _client.from('profiles').update({'avatar_url': url}).eq('id', user.id);
    return url;
  }

  Future<void> remove() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final path = '${user.id}/avatar.jpg';
    final pngPath = '${user.id}/avatar.png';
    final webpPath = '${user.id}/avatar.webp';
    await _client.storage.from(bucket).remove([path, pngPath, webpPath]);
    await _client.from('profiles').update({'avatar_url': null}).eq('id', user.id);
  }

  String _contentType(String? mime, String path) {
    if (mime == 'image/png') return 'image/png';
    if (mime == 'image/webp') return 'image/webp';
    return 'image/jpeg';
  }

  String _extension(String contentType) {
    switch (contentType) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      default:
        return 'jpg';
    }
  }
}
