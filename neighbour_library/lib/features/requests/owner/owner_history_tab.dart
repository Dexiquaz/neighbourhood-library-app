import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../ui/book_card.dart';
import '../../../ui/empty_state.dart';

class OwnerHistoryTab extends StatefulWidget {
  const OwnerHistoryTab({super.key});

  @override
  State<OwnerHistoryTab> createState() => _OwnerHistoryTabState();
}

class _OwnerHistoryTabState extends State<OwnerHistoryTab> {
  final _client = Supabase.instance.client;
  bool _loading = true;
  List<dynamic> _history = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final userId = _client.auth.currentUser!.id;

    final data = await _client
        .from('borrow_requests')
        .select('''
          status,
          books (
            title,
            author
          )
        ''')
        .eq('owner_id', userId)
        .inFilter('status', ['completed', 'rejected'])
        .order('created_at', ascending: false);

    if (!mounted) return;
    setState(() {
      _history = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_history.isEmpty) {
      return const EmptyState(message: 'No past requests');
    }

    return ListView.builder(
      itemCount: _history.length,
      itemBuilder: (_, i) {
        final r = _history[i];
        final book = r['books'];

        return BookCard(
          title: book['title'],
          author: book['author'] ?? '',
          subtitle: Text(
            r['status'].toString().toUpperCase(),
            style: const TextStyle(color: Colors.white54),
          ),
        );
      },
    );
  }
}
