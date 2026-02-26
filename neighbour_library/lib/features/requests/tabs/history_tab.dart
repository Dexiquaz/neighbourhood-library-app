import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../ui/book_card.dart';
import '../../../ui/empty_state.dart';
import 'package:neighbour_library/ui/status_chip.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
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
          status,
          books ( title, author )
          messages (
            content,
            created_at
          )
        ''')
        .or('owner_id.eq.$userId,borrower_id.eq.$userId')
        .inFilter('status', ['completed', 'rejected'])
        .order('created_at', ascending: false);

    if (!mounted) return;
    setState(() {
      _items = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) return const EmptyState(message: 'No history');

    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final r = _items[i];
        final book = r['books'];

        List messages = r['messages'] ?? [];

        Map<String, dynamic>? lastMessage;

        if (messages.isNotEmpty) {
          messages.sort(
            (a, b) => DateTime.parse(
              b['created_at'],
            ).compareTo(DateTime.parse(a['created_at'])),
          );
          lastMessage = messages.first;
        }

        return BookCard(
          title: book['title'],
          author: book['author'] ?? '',
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (lastMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Last: ${lastMessage['content']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              StatusChip(
                label: r['status'] == 'completed' ? 'Completed' : 'Rejected',
                color: r['status'] == 'completed'
                    ? Colors.green.shade400
                    : Colors.red.shade400,
              ),
            ],
          ),
        );
      },
    );
  }
}
