import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'auth/session_host.dart';
import 'ui/app_theme.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'NguyenTanTai Attendance',
    debugShowCheckedModeBanner: false,
    locale: const Locale('vi'),
    supportedLocales: const [Locale('vi')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    home: const SessionHost(),
  );
}
