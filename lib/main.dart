import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_agrocare/screens/splash_screen.dart';
import 'models/scan_record.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(ScanRecordAdapter());
  await Hive.openBox<ScanRecord>('scan_records');

  runApp(const SmartAgroCareApp());
}

class SmartAgroCareApp extends StatelessWidget {
  const SmartAgroCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart AgroCare',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildTheme(),
      home: const SplashScreen(),
    );
  }
}
