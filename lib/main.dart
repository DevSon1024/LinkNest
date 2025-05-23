import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/share_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sharing service
  ShareService.initialize();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Link Saver',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}