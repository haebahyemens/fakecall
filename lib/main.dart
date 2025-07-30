import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const LANFileTransferApp());
}

class LANFileTransferApp extends StatelessWidget {
  const LANFileTransferApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LAN File Transfer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}