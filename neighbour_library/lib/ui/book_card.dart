import 'package:flutter/material.dart';

class BookCard extends StatelessWidget {
  final String title;
  final String author;
  final Widget? trailing;
  final Widget? subtitle;

  const BookCard({
    super.key,
    required this.title,
    required this.author,
    this.trailing,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(author, style: const TextStyle(color: Colors.white70)),
            if (subtitle != null) subtitle!,
          ],
        ),
        trailing: trailing,
      ),
    );
  }
}
