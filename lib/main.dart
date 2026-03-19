import 'package:flutter/material.dart';
import 'screens/authentication/login.dart';
import 'screens/dashboard/dashboard.dart';
import 'screens/profile/profile_settings.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AFP Flutter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // Define routes
      home: const LoginPage(),
      routes: {
        '/dashboard': (context) => const Dashboard(),
        '/profile-settings': (context) => const ProfileSettingsPage(),
      },
    );
  }
}