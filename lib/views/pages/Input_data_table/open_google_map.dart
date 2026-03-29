import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openGoogleMaps(String coordinates, BuildContext context) async {
  if (coordinates.isEmpty) {
    return;
  }

  final Uri uri =
      Uri.parse("https://www.google.com/maps/search/?api=1&query=$coordinates");

  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not launch Google Maps for $coordinates',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error launching Google Maps: $e',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(milliseconds: 1500),
        ),
      );
    }
  }
}
