import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../ui/app_scaffold.dart';
import '../../ui/primary_button.dart';

class AddBookPage extends StatefulWidget {
  const AddBookPage({super.key});

  @override
  State<AddBookPage> createState() => _AddBookPageState();
}

class _AddBookPageState extends State<AddBookPage> {
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _isbnController = TextEditingController();
  final _client = Supabase.instance.client;

  bool _loading = false;

  Future<void> _saveBook() async {
    if (_titleController.text.trim().isEmpty) return;

    setState(() => _loading = true);

    try {
      final userId = _client.auth.currentUser!.id;

      await _client.from('books').insert({
        'title': _titleController.text.trim(),
        'author': _authorController.text.trim(),
        'isbn': _isbnController.text.trim(),
        'owner_id': userId,
      });

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Add Book',
      body: Column(
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          TextField(
            controller: _authorController,
            decoration: const InputDecoration(labelText: 'Author'),
          ),
          TextField(
            controller: _isbnController,
            decoration: const InputDecoration(labelText: 'ISBN'),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            text: 'Save Book',
            loading: _loading,
            onPressed: _saveBook,
          ),
        ],
      ),
    );
  }
}
