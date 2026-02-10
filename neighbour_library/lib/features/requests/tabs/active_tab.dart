import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../ui/book_card.dart';
import '../../../ui/empty_state.dart';
import 'package:neighbour_library/ui/status_chip.dart';

class ActiveTab extends StatefulWidget {
  const ActiveTab({super.key});

  @override
  State<ActiveTab> createState() => _ActiveTabState();
}

class _ActiveTabState extends State<ActiveTab> {
  final _client = Supabase.instance.client;
  List<dynamic> _items = [];
  bool _loading = true;

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
          id, owner_id, borrower_id,
          books ( title, author )
        ''')
        .or('owner_id.eq.$userId,borrower_id.eq.$userId')
        .eq('status', 'approved');

    if (!mounted) return;
    setState(() {
      _items = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) return const EmptyState(message: 'No active borrows');

    final userId = _client.auth.currentUser!.id;

    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final r = _items[i];
        final book = r['books'];

        final isBorrower = r['borrower_id'] == userId;

        return BookCard(
          title: book['title'],
          author: book['author'] ?? '',
          subtitle: isBorrower
              ? ElevatedButton(
                  onPressed: () => _markReturned(r['id']),
                  child: const Text('Mark Returned'),
                )
              : const StatusChip(label: 'Borrowed', color: Colors.white70),
        );
      },
    );
  }

  Future<void> _markReturned(String requestId) async {
    await _client
        .from('borrow_requests')
        .update({'status': 'returned'})
        .eq('id', requestId);

    _fetch();
  }
}
