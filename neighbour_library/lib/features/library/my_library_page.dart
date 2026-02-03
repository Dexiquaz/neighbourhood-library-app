import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../ui/app_scaffold.dart';
import '../../ui/book_card.dart';
import '../../ui/empty_state.dart';
import 'add_book_page.dart';

class MyLibraryPage extends StatefulWidget {
  const MyLibraryPage({super.key});

  @override
  State<MyLibraryPage> createState() => _MyLibraryPageState();
}

class _MyLibraryPageState extends State<MyLibraryPage> {
  final _client = Supabase.instance.client;
  List<dynamic> _books = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchBooks();
  }

  Future<void> _fetchBooks() async {
    final userId = _client.auth.currentUser!.id;

    final data = await _client
        .from('books')
        .select()
        .eq('owner_id', userId)
        .order('created_at', ascending: false);

    if (!mounted) return;

    setState(() {
      _books = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'My Library',
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddBookPage()),
          );
          _fetchBooks(); // refresh after add
        },
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _books.isEmpty
          ? const EmptyState(message: 'No books in your library')
          : ListView.builder(
              itemCount: _books.length,
              itemBuilder: (context, index) {
                final book = _books[index];
                return BookCard(
                  title: book['title'],
                  author: book['author'] ?? 'Unknown author',
                );
              },
            ),
    );
  }
}
