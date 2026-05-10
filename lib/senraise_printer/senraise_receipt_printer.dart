import 'package:collector_app/common/models/users.dart';
import 'package:collector_app/feature/pos_print/printer_util.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class SenraiseReceiptPrinter {
  static const MethodChannel _channel = MethodChannel('printer_channel');

  static const String _divider = '--------------------------------';

  // ── low-level helpers ──────────────────────────────────────────────────────

  static Future<void> _print(String text) async {
    await _channel.invokeMethod('printText', {'text': '$text\n'});
  }

  static Future<void> _printCentered(String text,
      {int width = 32, bool bold = false}) async {
    final padded = _center(text, width);
    await _print(padded);
  }

  static Future<void> _printDivider() => _print(_divider);

  static Future<void> _printKV(String key, String value,
      {int width = 32}) async {
    // Key left-aligned, value right-aligned, total = width
    final available = width - key.length;
    final val = value.length > available
        ? value.substring(0, available)
        : value.padLeft(available);
    await _print('$key$val');
  }

  // ── string utils ──────────────────────────────────────────────────────────
  static String _center(String text, int width) {
    if (text.length >= width) return text;
    final totalPad = width - text.length;
    final leftPad = totalPad ~/ 2;
    final rightPad = totalPad - leftPad;
    return ' ' * leftPad + text + ' ' * rightPad;
  }

  // static String _center(String text, int width) {
  //   if (text.length >= width) return text;
  //   final totalPad = width - text.length;
  //   final leftPad = totalPad ~/ 2;
  //   return ' ' * leftPad + text;
  // }

  static String _formatDate(DateTime dt) =>
      DateFormat('yyyy-MM-dd hh:mm a').format(dt);

  static String _formatAccountLine(String acNo, double amount) {
    final amtStr = 'Rs.${amount.toStringAsFixed(0)}';

    // Left-align account number, right-align amount, total width = 32
    final maxAccNoWidth = 32 - amtStr.length;
    final a = acNo.length > maxAccNoWidth
        ? acNo.substring(0, maxAccNoWidth)
        : acNo.padRight(maxAccNoWidth);

    return '$a$amtStr';
  }

  // ── public API ─────────────────────────────────────────────────────────────

  static Future<bool> printCollectionReceipt({
    User? userData,
    required String userName,
    required String groupName,
    required DateTime collectionDate,
    required String collectionLocation,
    required String idNumber,
    required List<CollectionAccount> accounts,
  }) async {
    try {
      // Header
      await _printCentered(userData!.client.cleintName ?? '');
      await _printCentered('COLLECTION RECEIPT');
      await _printDivider();

      // Customer info
      await _print('Acc Name: $userName');
      await _printDivider();
      if (groupName.isNotEmpty) await _printKV('Group Name:', groupName);
      await _printKV('Col. Date:', _formatDate(collectionDate));
      await _printKV('ID Number:', idNumber);
      // await _print('');
      await _printDivider();

      // Account table header
      // await _print('Acc No.     Amount');
      await _printKV('Acc No.', 'Amount');
      await _printDivider();

      // Account rows
      for (final account in accounts) {
        await _print(_formatAccountLine(
          // account.accountType,
          account.accountNumber,
          account.amount,
        ));
        // if (account.comment != null && account.comment!.isNotEmpty) {
        //   await _print('(Comment: ${account.comment})');
        // }
        await _print('');
      }

      // Total
      await _printDivider();
      final total = accounts.fold<double>(0, (sum, a) => sum + a.amount);
      await _printCentered('Total: Rs.${total.toStringAsFixed(1)}');
      await _printDivider();

      // Footer
      await _print('');
      await _printKV('Signature', '-------------------');
      await _printKV(userData.officer.fullName , '');
      // await _print('Signature'       '-----------------');
      // await _print('       ${userData.officer.fullName}');
      // await _print('');
      await _printDivider();
      await _printCentered('Generated On');
      await _printCentered('Balance Core Banking Solution');
      await _printCentered('Infobrain Technologies Pvt. Ltd.');
      await _printCentered('9851159727, 9851414714');
      await _print('');
      await _printCentered('Thank You!');

      // Feed paper
      await _print('\n\n\n');

      return true;
    } catch (e) {
      print('SenraiseReceiptPrinter error: $e');
      return false;
    }
  }
}
