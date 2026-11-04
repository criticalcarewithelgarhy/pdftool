import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'theme.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsBinding binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  const licenseKey = String.fromEnvironment('SYNCFUSION_LICENSE', defaultValue: '');
  if (licenseKey.isNotEmpty) {
    SyncfusionLicense.registerLicense(licenseKey);
  }
  runApp(const PdfToolApp());
}

class PdfToolApp extends StatelessWidget {
  const PdfToolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Toolkit',
      theme: appTheme,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
