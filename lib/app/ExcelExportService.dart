import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

class ExcelExportService {
  static const _headers = [
    'AC Type', 'Account No', 'Account Name', 'Center Name', 'ID No',
    'Contact', 'Input Amount', 'Remarks', 'Collection Date', 'Location',
    'Session ID',
  ];

  Uint8List _buildWorkbookBytes(
    List<Map<String, dynamic>> accounts, {
    String sheetName = 'Collections',
  }) {
    final excel = Excel.createExcel();
    final Sheet sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);
    if (excel.sheets.containsKey('Sheet1') && sheetName != 'Sheet1') {
      excel.delete('Sheet1');
    }

    sheet.appendRow(_headers.map((h) => TextCellValue(h)).toList());

    for (final acc in accounts) {
      sheet.appendRow([
        TextCellValue(acc['account_type_name']?.toString() ?? ''),
        TextCellValue(acc['ac_no']?.toString() ?? ''),
        TextCellValue(acc['ac_name']?.toString() ?? ''),
        TextCellValue(acc['center_name']?.toString() ?? ''),
        TextCellValue(acc['id_no']?.toString() ?? ''),
        TextCellValue(acc['contact']?.toString() ?? ''),
        DoubleCellValue((acc['input_amount'] as num?)?.toDouble() ?? 0.0),
        TextCellValue(acc['col_remarks']?.toString() ?? ''),
        TextCellValue(acc['col_date_time']?.toString() ?? ''),
        TextCellValue(acc['col_location']?.toString() ?? ''),
        TextCellValue(acc['col_group_id']?.toString() ?? ''),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Failed to encode the Excel file');
    return Uint8List.fromList(bytes);
  }

  /// Kept for the share-sheet flow — writes to app-private storage.
  Future<String> exportAccountsToExcel(
    List<Map<String, dynamic>> accounts, {
    String sheetName = 'Collections',
  }) async {
    final bytes = _buildWorkbookBytes(accounts, sheetName: sheetName);
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filePath = '${dir.path}/collections_$timestamp.xlsx';
    await File(filePath).writeAsBytes(bytes, flush: true);
    return filePath;
  }

  Future<void> exportAndShare(List<Map<String, dynamic>> accounts) async {
    if (accounts.isEmpty) throw Exception('No data to export');
    final path = await exportAccountsToExcel(accounts);
    await Share.shareXFiles([XFile(path)], text: 'Collection data export');
  }

  /// Writes ONE fixed-name file into the public Downloads folder, replacing
  /// whatever was there before — so this is always "the same file",
  /// updated with the full current dataset on every call.
  Future<void> saveToDownloads(
    List<Map<String, dynamic>> accounts, {
    String fileName = 'collection_data.xlsx',
  }) async {
    if (accounts.isEmpty) throw Exception('No data to save');
    final bytes = _buildWorkbookBytes(accounts, sheetName: 'AllCollections');

    // MediaStore copies FROM a temp file path — it doesn't take raw bytes.
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$fileName');
    await tempFile.writeAsBytes(bytes, flush: true);

    await MediaStore().saveFile(
      tempFilePath: tempFile.path,
      dirType: DirType.download,
      dirName: DirName.download,
    );

    await tempFile.delete();
  }
  String _escapeCsvField(dynamic value) {
    final str = value?.toString() ?? '';
    // Quote the field if it contains a comma, quote, or newline — the
    // standard CSV escaping rule so data doesn't shift into wrong columns.
    if (str.contains(',') || str.contains('"') || str.contains('\n')) {
      return '"${str.replaceAll('"', '""')}"';
    }
    return str;
  }
   String _buildCsvContent(List<Map<String, dynamic>> accounts) {
    final buffer = StringBuffer();
    buffer.writeln(_headers.map(_escapeCsvField).join(','));

    for (final acc in accounts) {
      final row = [
        acc['account_type_name'],
        acc['ac_no'],
        acc['ac_name'],
        acc['center_name'],
        acc['id_no'],
        acc['contact'],
        (acc['input_amount'] as num?)?.toStringAsFixed(2) ?? '0.00',
        acc['col_remarks'],
        acc['col_date_time'],
        acc['col_location'],
        acc['col_group_id'],
      ];
      buffer.writeln(row.map(_escapeCsvField).join(','));
    }
    return buffer.toString();
  }
   Future<void> saveCsvToDownloads(
    List<Map<String, dynamic>> accounts, {
    String fileName = 'collection_data.csv',
  }) async {
    if (accounts.isEmpty) throw Exception('No data to save');
    final content = _buildCsvContent(accounts);
    final bytes = Uint8List.fromList(utf8.encode(content));

    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$fileName');
    await tempFile.writeAsBytes(bytes, flush: true);

    await MediaStore().saveFile(
      tempFilePath: tempFile.path,
      dirType: DirType.download,
      dirName: DirName.download,
    );

    await tempFile.delete();
  }
  Future<String> exportAccountsToCsv(List<Map<String, dynamic>> accounts) async {
    final content = _buildCsvContent(accounts);
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filePath = '${dir.path}/collections_$timestamp.csv';
    await File(filePath).writeAsBytes(utf8.encode(content), flush: true);
    return filePath;
  }

  Future<void> exportAndShareCsv(List<Map<String, dynamic>> accounts) async {
    if (accounts.isEmpty) throw Exception('No data to export');
    final path = await exportAccountsToCsv(accounts);
    await Share.shareXFiles([XFile(path)], text: 'Collection data export (CSV)');
  }
}