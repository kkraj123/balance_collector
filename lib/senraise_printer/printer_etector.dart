import 'package:device_info_plus/device_info_plus.dart';

enum PrinterType { sunmi, aidl, none }

class PrinterDetector {
  static PrinterType? _cached;

  static Future<PrinterType> detect() async {
    if (_cached != null) return _cached!;

    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    final manufacturer = androidInfo.manufacturer.toLowerCase();
    final model = androidInfo.model.toLowerCase();

    if (manufacturer.contains('sunmi')) {
      _cached = PrinterType.sunmi;
    } else if (manufacturer.contains('senraise') ||
        model.contains('h10') ||
        model.contains('p796')) {
      _cached = PrinterType.aidl;
    } else {
      _cached = PrinterType.none;
    }

    return _cached!;
  }
}