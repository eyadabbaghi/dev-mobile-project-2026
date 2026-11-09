// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:video_player/video_player.dart';

Future<VideoPlayerController?> createCommunityVideoController(
  Uint8List bytes,
  String fileName,
) async {
  try {
    final blob = html.Blob([bytes], 'video/mp4');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    await controller.initialize();
    return controller;
  } catch (_) {
    return null;
  }
}
