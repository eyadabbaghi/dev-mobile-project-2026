import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

class ImageService {
  static final ImagePicker _picker = ImagePicker();

  static Future<String?> pickAndSaveImage(ImageSource source, String userId) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (pickedFile == null) return null;

      final appDir = await getApplicationDocumentsDirectory();
      // Generate a unique filename to avoid caching issues when replacing the image
      final fileName = 'profile_${userId}_${DateTime.now().millisecondsSinceEpoch}${p.extension(pickedFile.path)}';
      final savedImage = await File(pickedFile.path).copy(p.join(appDir.path, fileName));
      
      return savedImage.path;
    } catch (e) {
      return null;
    }
  }

  static Future<void> deleteImage(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Ignore
    }
  }
}
