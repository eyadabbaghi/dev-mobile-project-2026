import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

Future<VideoPlayerController?> createCommunityVideoController(
  Uint8List bytes,
  String fileName,
) async {
  try {
    final directory = await getTemporaryDirectory();
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File(
      p.join(
        directory.path,
        'community_${DateTime.now().microsecondsSinceEpoch}_$safeName',
      ),
    );
    await file.writeAsBytes(bytes, flush: true);
    final controller = VideoPlayerController.file(file);
    await controller.initialize();
    return controller;
  } catch (_) {
    return null;
  }
}
