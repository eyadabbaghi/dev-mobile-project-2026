import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/image_service.dart';

class ProfileAvatar extends StatelessWidget {
  final String? imagePath;
  final String userId;
  final Function(String?) onImageChanged;
  final double radius;

  const ProfileAvatar({
    super.key,
    required this.imagePath,
    required this.userId,
    required this.onImageChanged,
    this.radius = 60.0,
  });

  Future<void> _showPicker(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galerie de photos'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final path = await ImageService.pickAndSaveImage(ImageSource.gallery, userId);
                  if (path != null) onImageChanged(path);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Prendre une photo'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final path = await ImageService.pickAndSaveImage(ImageSource.camera, userId);
                  if (path != null) onImageChanged(path);
                },
              ),
              if (imagePath != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Supprimer la photo', style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await ImageService.deleteImage(imagePath!);
                    onImageChanged(null);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            backgroundImage: imagePath != null ? FileImage(File(imagePath!)) : null,
            child: imagePath == null
                ? Icon(Icons.person, size: radius, color: Theme.of(context).colorScheme.primary)
                : null,
          ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
            ),
            child: Icon(
              imagePath == null ? Icons.add_a_photo : Icons.edit,
              size: 20,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
