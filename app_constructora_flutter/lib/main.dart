import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_constructora/theme/app_theme.dart';
import 'package:app_constructora/screens/login_screen.dart';
import 'package:app_constructora/providers/user_provider.dart';

import 'package:app_constructora/providers/notification_provider.dart';
import 'package:app_constructora/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Constructora App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const LoginScreen(),
    );
  }
}
