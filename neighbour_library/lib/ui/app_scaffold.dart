import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? floatingActionButton;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // dark base
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: Padding(padding: const EdgeInsets.all(16), child: body),
      floatingActionButton: floatingActionButton,
    );
  }
}
