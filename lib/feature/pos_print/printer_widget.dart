import 'package:flutter/material.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import 'package:sunmi_printer_plus/enums.dart';
import 'package:sunmi_printer_plus/sunmi_style.dart';
import 'package:intl/intl.dart';

class SunmiPrinterExample extends StatefulWidget {
  const SunmiPrinterExample({Key? key}) : super(key: key);

  @override
  _SunmiPrinterExampleState createState() => _SunmiPrinterExampleState();
}

class _SunmiPrinterExampleState extends State<SunmiPrinterExample> {
  @override
  void initState() {
    super.initState();
    initPrinter();
  }

  void initPrinter() async {
    try {
      await SunmiPrinter.bindingPrinter();
      print("Printer initialized successfully");
    } catch (e) {
      print("Error initializing printer: $e");
    }
  }

  void printSampleInvoice() async {
    try {
      await SunmiPrinter.startTransactionPrint(true);

      await SunmiPrinter.printText('Devanasoft Pvt. Ltd.',
          style: SunmiStyle(
              align: SunmiPrintAlign.CENTER,
              bold: true,
              fontSize: SunmiFontSize.LG));

      await SunmiPrinter.printText('Ghattaghar Kathmandu',
          style: SunmiStyle(
              align: SunmiPrintAlign.CENTER,
              bold: true,
              fontSize: SunmiFontSize.MD));

      await SunmiPrinter.printText('Invoice',
          style: SunmiStyle(
              align: SunmiPrintAlign.CENTER,
              bold: true,
              fontSize: SunmiFontSize.MD));

      await SunmiPrinter.lineWrap(1);

      await SunmiPrinter.printText('Bill No: 12345',
          style: SunmiStyle(bold: true, fontSize: SunmiFontSize.MD));

      await SunmiPrinter.printText(
          'Date: ${DateFormat('d LLL, yyyy HH:mm:ss').format(DateTime.now())}',
          style: SunmiStyle(bold: true, fontSize: SunmiFontSize.MD));

      await SunmiPrinter.lineWrap(1);

      await SunmiPrinter.printText('Item   Qty   Rate     Price',
          style: SunmiStyle(bold: true, align: SunmiPrintAlign.LEFT));

      await SunmiPrinter.printText('--------------------------------');

      await SunmiPrinter.printText('Product  1    100.00   100.00',
          style: SunmiStyle(align: SunmiPrintAlign.LEFT));

      await SunmiPrinter.printText('--------------------------------');

      await SunmiPrinter.printText('Total                    100.00',
          style: SunmiStyle(align: SunmiPrintAlign.LEFT, bold: true));

      await SunmiPrinter.printText('--------------------------------');
      await SunmiPrinter.printText('ONE HUNDRED RUPEES ONLY',
          style: SunmiStyle(align: SunmiPrintAlign.LEFT, bold: true));

      await SunmiPrinter.lineWrap(2);

      await SunmiPrinter.printText('Thank you for your purchase!',
          style: SunmiStyle(align: SunmiPrintAlign.CENTER));

      await SunmiPrinter.submitTransactionPrint();
      await SunmiPrinter.exitTransactionPrint(true);

      print("Printing completed successfully");
    } catch (e) {
      print("Error printing: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sunmi Printer Example'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: printSampleInvoice,
          child: Text('Print Sample Invoice'),
        ),
      ),
    );
  }
}
