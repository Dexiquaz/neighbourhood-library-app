import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../ui/book_card.dart';
import '../../../ui/empty_state.dart';
import '../../chat/chat_page.dart';

class OwnerIncomingTab extends StatefulWidget {
  const OwnerIncomingTab({super.key});

  @override
  State<OwnerIncomingTab> createState() => _OwnerIncomingTabState();
}

class _OwnerIncomingTabState extends State<OwnerIncomingTab> {
  final _client = Supabase.instance.client;
  bool _loading = true;
  List<dynamic> _items = [];

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
          status,
          borrower_id,
          books (
            id,
            title,
            author
          )
        ''')
        .eq('owner_id', userId)
        .inFilter('status', ['pending', 'returned'])
        .order('created_at', ascending: false);

    if (!mounted) return;

    setState(() {
      _items = data;
      _loading = false;
    });
  }

  Future<void> _approve(String requestId, String bookId) async {
    await _client
        .from('borrow_requests')
        .update({'status': 'approved'})
        .eq('id', requestId);

    await _client.from('books').update({'status': 'borrowed'}).eq('id', bookId);

    _fetch();
  }

  Future<void> _deny(String requestId) async {
    await _client
        .from('borrow_requests')
        .update({'status': 'rejected'})
        .eq('id', requestId);

    _fetch();
  }

  Future<void> _confirmReturn(String requestId, String bookId) async {
    await _client
        .from('borrow_requests')
        .update({'status': 'completed'})
        .eq('id', requestId);

    await _client
        .from('books')
        .update({'status': 'available'})
        .eq('id', bookId);

    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return const EmptyState(message: 'No incoming requests');
    }

    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final r = _items[i];
        final book = r['books'];
        final status = r['status'];

        return BookCard(
          title: book['title'],
          author: book['author'] ?? '',
          subtitle: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (status == 'pending') ...[
                ElevatedButton(
                  onPressed: () => _approve(r['id'], book['id']),
                  child: const Text('Approve'),
                ),

                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                  ),
                  onPressed: () => _deny(r['id']),
                  child: const Text('Deny'),
                ),
              ],

              if (status == 'returned') ...[
                ElevatedButton(
                  onPressed: () => _confirmReturn(r['id'], book['id']),
                  child: const Text('Confirm Return'),
                ),
              ],

              OutlinedButton(
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
            ],
          ),
        );
      },
    );
  }
}
