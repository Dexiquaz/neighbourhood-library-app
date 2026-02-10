import 'package:flutter/material.dart';
import 'package:neighbour_library/ui/status_chip.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../ui/book_card.dart';
import '../../../ui/empty_state.dart';

class IncomingTab extends StatefulWidget {
  const IncomingTab({super.key});

  @override
  State<IncomingTab> createState() => _IncomingTabState();
}

class _IncomingTabState extends State<IncomingTab> {
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
          id, status, owner_id, borrower_id,
          books ( id, title, author )
        ''')
        .or('owner_id.eq.$userId,borrower_id.eq.$userId')
        .inFilter('status', ['pending', 'returned'])
        .order('created_at', ascending: false);

    if (!mounted) return;
    setState(() {
      _items = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return const EmptyState(message: 'No incoming requests');
    }

    final userId = _client.auth.currentUser!.id;

    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final r = _items[i];
        final book = r['books'];
        final status = r['status'];

        final isOwner = r['owner_id'] == userId;
        final isBorrower = r['borrower_id'] == userId;

        return BookCard(
          title: book['title'],
          author: book['author'] ?? '',
          subtitle: Wrap(
            spacing: 8,
            children: [
              // OWNER — pending
              if (status == 'pending' && isOwner) ...[
                ElevatedButton(
                  onPressed: () => _approve(r['id'], book['id']),
                  child: const Text('Approve'),
                ),
                OutlinedButton(
                  onPressed: () => _deny(r['id']),
                  child: const Text('Deny'),
                ),
              ],

              // BORROWER — pending
              if (status == 'pending' && isBorrower)
                const StatusChip(label: 'Request sent', color: Colors.white70),

              // OWNER — returned
              if (status == 'returned' && isOwner)
                ElevatedButton(
                  onPressed: () => _confirmReturn(r['id'], book['id']),
                  child: const Text('Confirm Return'),
                ),
            ],
          ),
        );
      },
    );
  }

  // ---- Actions ----

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
}
