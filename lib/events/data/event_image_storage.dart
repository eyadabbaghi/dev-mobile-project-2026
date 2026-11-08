import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class EventImageStorage {
  EventImageStorage._();

  static final EventImageStorage instance = EventImageStorage._();

  Future<String> persistImage(String eventId, String sourcePath) async {
    final directory = await getApplicationDocumentsDirectory();
    final imageDirectory = Directory(p.join(directory.path, 'event_images'));
    await imageDirectory.create(recursive: true);

    final extension = p.extension(sourcePath);
    final destination = p.join(
      imageDirectory.path,
      '$eventId-${DateTime.now().microsecondsSinceEpoch}$extension',
    );
    return (await File(sourcePath).copy(destination)).path;
  }

  Future<void> deleteImage(String? imagePath) async {
    if (imagePath == null) return;
    final imageFile = File(imagePath);
    if (await imageFile.exists()) await imageFile.delete();
  }
}
