// import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import 'package:sunmi_printer_plus/enums.dart';
import 'package:sunmi_printer_plus/sunmi_style.dart';

class CollectionAccount {
  final String accountType;
  final String accountNumber;
  final double amount;
  final String? comment;

  CollectionAccount({
    required this.accountType,
    required this.accountNumber,
    required this.amount,
    this.comment,
  });
}

class CollectionReceiptPrinter {
  static bool _isPrinterInitialized = false;

  static Future<bool> _initializePrinter() async {
    if (_isPrinterInitialized) return true;

    try {
      await SunmiPrinter.bindingPrinter();
      _isPrinterInitialized = true;
      print("Printer initialized successfully");
      return true;
    } catch (e) {
      print("Error initializing printer: $e");
      return false;
    }
  }

  static Future<bool> printCollectionReceipt({
    required String userName,
    required String groupName,
    required DateTime collectionDate,
    required String collectionLocation,
    required String idNumber,
    required List<CollectionAccount> accounts,
  }) async {
    bool isInitialized = await _initializePrinter();
    if (!isInitialized) {
      print("Printer initialization failed. Cannot print receipt.");
      return false;
    }

    try {
      await SunmiPrinter.startTransactionPrint(true);
      await _printCenteredBold('Info Brains Solutions',
          fontSize: SunmiFontSize.LG);
      await SunmiPrinter.lineWrap(1);
      await _printReceiptDetails(
        userName: userName,
        groupName: groupName,
        collectionDate: collectionDate,
        collectionLocation: collectionLocation,
        idNumber: idNumber,
      );
      await _printAccountDetails(accounts);
      await _printTotal(accounts);
      await SunmiPrinter.lineWrap(1);
      await SunmiPrinter.printText('Signature       ----------------');
      await SunmiPrinter.lineWrap(1);
      await _printCenteredBold('Thank You!');
      await SunmiPrinter.lineWrap(3);
      await SunmiPrinter.submitTransactionPrint();
      await SunmiPrinter.exitTransactionPrint(true);
      print("Collection Receipt Printed Successfully");
      return true;
    } catch (e) {
      print("Error printing collection receipt: $e");
      return false;
    }
  }

  static Future<void> _printReceiptDetails({
    required String userName,
    required String groupName,
    required DateTime collectionDate,
    required String collectionLocation,
    required String idNumber,
  }) async {
    // await _printDivider();
    await _printLeftAligned('Acc Name: $userName');
    await _printDivider();
    await _printLeftAlignedMainInfo('Group Name:', groupName);
    await _printLeftAlignedMainInfo(
        'Collection Date:', _formatDateTime(collectionDate));
    // await _printLeftAlignedMainInfo('Collection Location:', collectionLocation);
    await _printLeftAlignedMainInfo('ID Number: ', idNumber);
    await SunmiPrinter.lineWrap(1);
    await _printDivider();
  }

  static Future<void> _printAccountDetails(
      List<CollectionAccount> accounts) async {
    await _printLeftAligned('Acc Type   Acc No.   Amount');
    await _printDivider();

    for (var account in accounts) {
      String accountLine = _formatAccountLine(
          account.accountType, account.accountNumber, account.amount);
      await _printLeftAlignedPlain(accountLine);

      if (account.comment != null) {
        await _printLeftAlignedPlain('(Comment: ${account.comment})');
      }
      await SunmiPrinter.lineWrap(1);
    }
  }

  static Future<void> _printTotal(List<CollectionAccount> accounts) async {
    await _printDivider();
    double total = accounts.fold(0, (sum, account) => sum + account.amount);
    await _printCenteredBold('Total: Rs.${total.toStringAsFixed(1)}');
    await _printDivider();
  }

  static Future<void> _printLeftAligned(String text) async {
    await SunmiPrinter.printText(text,
        style: SunmiStyle(bold: true, fontSize: SunmiFontSize.MD));
  }

  // static Future<void> _printLeftAlignedMainInfo(
  //     String text, String text2) async {
  //   await SunmiPrinter.printText(text,
  //       style: SunmiStyle(bold: true, fontSize: SunmiFontSize.MD));
  //   await SunmiPrinter.printText(text2,
  //       style: SunmiStyle(bold: false, fontSize: SunmiFontSize.MD));
  // }
  static Future<void> _printLeftAlignedMainInfo(
      String text, String text2) async {
    await SunmiPrinter.printText('$text $text2',
        style: SunmiStyle(
          bold: true,
        ));
  }

  static Future<void> _printLeftAlignedPlain(String text) async {
    await SunmiPrinter.printText(text,
        style: SunmiStyle(align: SunmiPrintAlign.LEFT));
  }

  static Future<void> _printCenteredBold(String text,
      {SunmiFontSize? fontSize = SunmiFontSize.LG}) async {
    await SunmiPrinter.printText(text,
        style: SunmiStyle(
            align: SunmiPrintAlign.CENTER, bold: true, fontSize: fontSize));
  }

  static Future<void> _printDivider() async {
    await SunmiPrinter.printText('--------------------------------');
  }

  static String _formatDateTime(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd').format(dateTime);
  }

  static String _formatAccountLine(
      String accountType, String accountNo, double amount) {
    return '${accountType.padRight(10)}  ${accountNo.padRight(7)}  Rs.${amount.toStringAsFixed(0)}';
  }
}
