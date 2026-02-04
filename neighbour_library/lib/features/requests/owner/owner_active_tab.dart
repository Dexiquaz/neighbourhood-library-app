import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../ui/book_card.dart';
import '../../../ui/empty_state.dart';
import '../../chat/chat_page.dart';

class OwnerActiveTab extends StatefulWidget {
  const OwnerActiveTab({super.key});

  @override
  State<OwnerActiveTab> createState() => _OwnerActiveTabState();
}

class _OwnerActiveTabState extends State<OwnerActiveTab> {
  final _client = Supabase.instance.client;
  bool _loading = true;
  List<dynamic> _active = [];

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
          id,
          borrower_id,
          books (
            title,
            author
          )
        ''')
        .eq('owner_id', userId)
        .eq('status', 'approved')
        .order('created_at', ascending: false);

    if (!mounted) return;
    setState(() {
      _active = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_active.isEmpty) {
      return const EmptyState(message: 'No active borrows');
    }

    return ListView.builder(
      itemCount: _active.length,
      itemBuilder: (_, i) {
        final r = _active[i];
        final book = r['books'];

        return BookCard(
          title: book['title'],
          author: book['author'] ?? '',
          subtitle: OutlinedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatPage(
                    requestId: r['id'],
                    otherUserId: r['borrower_id'],
                  ),
                ),
              );
            },
            child: const Text('Chat'),
          ),
        );
      },
    );
  }
}
