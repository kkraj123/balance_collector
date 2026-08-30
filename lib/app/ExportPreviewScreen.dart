import 'package:collector_app/app/ExcelExportService.dart';
import 'package:collector_app/common/app/theme.dart';
import 'package:collector_app/feature/database/cb_db.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';

class ExportPreviewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> accounts;

  const ExportPreviewScreen({super.key, required this.accounts});

  @override
  State<ExportPreviewScreen> createState() => _ExportPreviewScreenState();
}

class _ExportPreviewScreenState extends State<ExportPreviewScreen> {
  bool isExporting = false;
  bool isOpening = false;

  // Fixed path since saveToDownloads() always writes this same filename
  // into DirType.download — see ExcelExportService.
  static const String _downloadedFilePath =
      '/storage/emulated/0/Download/collection_data.xlsx';

  double get totalAmount => widget.accounts.fold<double>(0,
      (sum, acc) => sum + ((acc['input_amount'] as num?)?.toDouble() ?? 0.0));

  Future<void> _share() async {
    setState(() => isExporting = true);
    try {
      await ExcelExportService().exportAndShare(widget.accounts);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isExporting = false);
    }
  }

  Future<void> _saveToDevice() async {
    setState(() => isExporting = true);
    try {
      // Always pull the full history so the on-device file stays complete,
      // not just whatever subset is shown in this preview.
      final allCollected = await CBDB().CheckIfInserted();
      await ExcelExportService().saveToDownloads(allCollected);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Saved to Downloads/collection_data.xlsx')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isExporting = false);
    }
  }

  Future<void> _openExportedFile() async {
    setState(() => isOpening = true);
    try {
      final result = await OpenFile.open(_downloadedFilePath);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Could not open file (${result.message}). Try "Save to Device" first.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening file: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isOpening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Collection Data',
            style: TextStyle(color: Colors.white)),
        backgroundColor: CustomTheme.appThemeColorPrimary,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // IconButton(
          //   tooltip: 'Open saved file',
          //   icon: isOpening
          //       ? const SizedBox(
          //           width: 20,
          //           height: 20,
          //           child: CircularProgressIndicator(
          //               strokeWidth: 2, color: Colors.white),
          //         )
          //       : const Icon(Icons.open_in_new, color: Colors.white),
          //   onPressed: isOpening ? null : _saveCsvToDevice,
          // ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${widget.accounts.length} record(s)',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Total: ${totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: widget.accounts.isEmpty
                ? const Center(child: Text('No data to export'))
                : ListView.separated(
                    itemCount: widget.accounts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final acc = widget.accounts[index];
                      return ListTile(
                        title: Text(acc['ac_name']?.toString() ?? ''),
                        subtitle: Text(
                          "${acc['ac_no'] ?? ''} • ${acc['col_remarks'] ?? ''}",
                        ),
                        trailing: Text(
                          (acc['input_amount'] as num?)?.toStringAsFixed(2) ??
                              '0.00',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        isExporting || widget.accounts.isEmpty ? null : _share,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(
                          color: CustomTheme.appThemeColorPrimary),
                    ),
                    icon: const Icon(Icons.share_rounded,
                        color: CustomTheme.appThemeColorPrimary),
                    label: const Text('Share',
                        style:
                            TextStyle(color: CustomTheme.appThemeColorPrimary)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Future<void> _saveCsvToDevice() async {
  setState(() => isExporting = true);
  try {
    final allCollected = await CBDB().CheckIfInserted();
    await ExcelExportService().saveCsvToDownloads(allCollected);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to Downloads/collection_data.csv')),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  } finally {
    if (mounted) setState(() => isExporting = false);
  }
}
}
