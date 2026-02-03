import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final String message;
  final Widget? action;

  const EmptyState({super.key, required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.menu_book, size: 64, color: Colors.white38),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.white70)),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
