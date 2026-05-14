import 'package:collector_app/common/models/users.dart';
import 'package:collector_app/feature/pos_print/printer_util.dart';
import 'package:collector_app/senraise_printer/printer_etector.dart';
import 'package:collector_app/senraise_printer/senraise_receipt_printer.dart';
import 'package:flutter/services.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import 'package:sunmi_printer_plus/enums.dart';

class PrinterService {
  static const MethodChannel _channel = MethodChannel('printer_channel');
  static bool _sunmiInitialized = false;

  static Future<void> _initSunmi() async {
    if (!_sunmiInitialized) {
      await SunmiPrinter.bindingPrinter();
      await SunmiPrinter.initPrinter();
      _sunmiInitialized = true;
    }
  }

  static Future<bool> isReady() async {
    final type = await PrinterDetector.detect();
    switch (type) {
      case PrinterType.sunmi:
        await _initSunmi();
        return true;
      case PrinterType.aidl:
        return await _channel.invokeMethod('isReady') ?? false;
      case PrinterType.none:
        return false;
    }
  }

  static Future<void> printText(String text) async {
    final type = await PrinterDetector.detect();
    switch (type) {
      case PrinterType.sunmi:
        await SunmiPrinter.printText(text);
        await SunmiPrinter.lineWrap(1);
        break;
      case PrinterType.aidl:
        await _channel.invokeMethod('printText', {'text': text});
        break;
      case PrinterType.none:
        throw Exception('No supported printer found on this device');
    }
  }

  static Future<void> printQRCode(String data) async {
    final type = await PrinterDetector.detect();
    switch (type) {
      case PrinterType.sunmi:
        await SunmiPrinter.printQRCode(data);
        break;
      case PrinterType.aidl:
        await _channel.invokeMethod('printQRCode', {'data': data});
        break;
      case PrinterType.none:
        throw Exception('No supported printer found on this device');
    }
  }

  static Future<void> printBarcode(String data) async {
    final type = await PrinterDetector.detect();
    switch (type) {
      case PrinterType.sunmi:
        await SunmiPrinter.printBarCode(
          data,
          barcodeType: SunmiBarcodeType.CODE128,
          height: 100,
          width: 2,
          textPosition: SunmiBarcodeTextPos.TEXT_UNDER,
        );
        break;
      case PrinterType.aidl:
        await _channel.invokeMethod('printBarcode', {'data': data});
        break;
      case PrinterType.none:
        throw Exception('No supported printer found on this device');
    }
  }

  // Call this once before a print job (handles both printer types)
  static Future<void> startJob() async {
    final type = await PrinterDetector.detect();
    if (type == PrinterType.sunmi) {
      await _initSunmi();
      await SunmiPrinter.startTransactionPrint(true);
    }
  }

  // Call this after all print calls
  static Future<void> endJob() async {
    final type = await PrinterDetector.detect();
    if (type == PrinterType.sunmi) {
      await SunmiPrinter.submitTransactionPrint();
    }
  }
  static Future<bool> printReceipt({
    required User? userData,
  required String userName,
  required String groupName,
  required DateTime collectionDate,
  required String collectionLocation,
  required String idNumber,
  required String clientAlia,
  required List<CollectionAccount> accounts,
}) async {
  final type = await PrinterDetector.detect();
  switch (type) {
    case PrinterType.sunmi:
      return CollectionReceiptPrinter.printCollectionReceipt(
        userData: userData,
        userName: userName,
        groupName: groupName,
        collectionDate: collectionDate,
        collectionLocation: collectionLocation,
        idNumber: idNumber,
        accounts: accounts,
      );
    case PrinterType.aidl:
      return SenraiseReceiptPrinter.printCollectionReceipt(
        userData: userData,
        userName: userName,
        groupName: groupName,
        collectionDate: collectionDate,
        collectionLocation: collectionLocation,
        idNumber: idNumber,
        accounts: accounts,
        clietAlia: clientAlia
      );
    case PrinterType.none:
      return false;
  }
}
}