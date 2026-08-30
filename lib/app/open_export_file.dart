import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart';

Future<void> _openExportedFile(BuildContext context) async {
  // Downloads path is fixed and predictable since we always write the
  // same filename via MediaStore's DirType.download.
  const path = '/storage/emulated/0/Download/collection_data.xlsx';
  final result = await OpenFile.open(path);
  if (result.type != ResultType.done && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open file: ${result.message}')),
    );
  }
}
