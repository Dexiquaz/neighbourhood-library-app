import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../ui/app_scaffold.dart';
import '../../ui/book_card.dart';
import '../../ui/empty_state.dart';

class MyBorrowedBooksPage extends StatefulWidget {
  const MyBorrowedBooksPage({super.key});

  @override
  State<MyBorrowedBooksPage> createState() => _MyBorrowedBooksPageState();
}

class _MyBorrowedBooksPageState extends State<MyBorrowedBooksPage> {
  final _client = Supabase.instance.client;
  List<dynamic> _borrowed = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchBorrowed();
  }

  Future<void> _fetchBorrowed() async {
    setState(() {
      _loading = true;
    });

    try {
      final userId = _client.auth.currentUser!.id;

      final data = await _client
          .from('borrow_requests')
          .select('''
          id,
          status,
          books (
            id,
            title,
            author
          )
        ''')
          .eq('borrower_id', userId)
          .inFilter('status', ['approved']);

      if (!mounted) return;

      setState(() {
        _borrowed = data;
      });
    } catch (e) {
      debugPrint('Fetch borrowed error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _markReturned(String requestId) async {
    await _client
        .from('borrow_requests')
        .update({'status': 'returned'})
        .eq('id', requestId);

    if (!mounted) return;

    setState(() {
      _borrowed.removeWhere((r) => r['id'] == requestId);
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Book marked as returned')));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'My Borrowed Books',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _borrowed.isEmpty
          ? const EmptyState(message: 'No borrowed books')
          : ListView.builder(
              itemCount: _borrowed.length,
              itemBuilder: (context, index) {
                final req = _borrowed[index];
                final book = req['books'];

                return BookCard(
                  title: book['title'],
                  author: book['author'] ?? '',
                  subtitle: ElevatedButton(
                    onPressed: () => _markReturned(req['id']),
                    child: const Text('Mark as Returned'),
                  ),
                );
              },
            ),
    );
  }
}
