import 'package:flutter/material.dart';

class F {
  static late final Flavor flavor;
  static late final String baseUrl;
  static late final String appTitle;
  static late final Color primarySwatch;

  static void init(Flavor f) {
    flavor = f;
    switch (f) {
      case Flavor.infoBrain:
        appTitle = 'Infor Brains Collector';
        primarySwatch = const Color(0xFF1DB207);
        break;
      case Flavor.finalsol:
        appTitle = 'Finsol Collector';
        primarySwatch = const Color(0xFF0e75bd);
        break;
    }
  }
}

enum Flavor { infoBrain, finalsol }
