import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
// import 'package:scan/scan.dart';

class QrUtils {
  static Future<bool> requestCameraPermission(BuildContext context) async {
    final status = await Permission.camera.request();

    if (!status.isGranted) {
      if (context.mounted) {
        _showSnackBar(context, "Camera permission is required", Colors.red);
      }
    }
    return status.isGranted;
  }

  static Future<String?> scanQRFromGallery(BuildContext context) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
      );

      if (image == null) return null;

      // final String? result = await Scan.parse(image.path);
      const  String result = 'data found';

      return result;
    } catch (e) {
      if (context.mounted) {
        _showSnackBar(context, "Error: $e", Colors.red);
      }

      return null;
    }
  }

  static void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }
}
