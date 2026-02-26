import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../ui/book_card.dart';
import '../../../ui/empty_state.dart';
import '../../../services/analytics_service.dart';
import '../../chat/chat_page.dart';

class ActiveTab extends StatefulWidget {
  const ActiveTab({super.key});

  @override
  State<ActiveTab> createState() => _ActiveTabState();
}

class _ActiveTabState extends State<ActiveTab> {
  final _client = Supabase.instance.client;
  final _analyticsService = AnalyticsService();

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
          owner_id,
          borrower_id,
          books (
            id,
            title,
            author
          ),
          messages (
            content,
            created_at
          )
        ''')
        .or('owner_id.eq.$userId,borrower_id.eq.$userId')
        .inFilter('status', ['approved', 'returned'])
        .order('created_at', ascending: false);

    if (!mounted) return;

    setState(() {
      _items = data;
      _loading = false;
    });
  }

  Future<void> _markReturned(String requestId) async {
    final userId = _client.auth.currentUser!.id;

    await _client
        .from('borrow_requests')
        .update({'status': 'returned'})
        .eq('id', requestId);

    // Log the return event
    await _analyticsService.logEvent(
      userId: userId,
      bookId: null,
      eventType: 'book_returned',
    );

    if (!mounted) return;

    setState(() {
      _items.removeWhere((r) => r['id'] == requestId);
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Marked as returned')));
  }

  Future<void> _confirmReturn(String requestId, String bookId) async {
    final userId = _client.auth.currentUser!.id;

    await _client
        .from('borrow_requests')
        .update({'status': 'completed'})
        .eq('id', requestId);

    await _client
        .from('books')
        .update({'status': 'available'})
        .eq('id', bookId);

    // Log the completion event
    await _analyticsService.logEvent(
      userId: userId,
      bookId: bookId,
      eventType: 'borrow_completed',
    );

    // Update user preferences based on completed borrow
    final preferences = await _analyticsService.getUserGenrePreferences(userId);
    await _analyticsService.updateUserPreferences(
      userId,
      preferences,
      null, // Let the service use its default 'good' condition
    );

    if (!mounted) return;

    setState(() {
      _items.removeWhere((r) => r['id'] == requestId);
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Return confirmed')));
  }

  @override
  Widget build(BuildContext context) {
    final userId = _client.auth.currentUser!.id;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return const EmptyState(message: 'No active books');
    }

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

        final isOwner = r['owner_id'] == userId;
        final isBorrower = r['borrower_id'] == userId;

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
              // BORROWER side - only for approved
              if (isBorrower && r['status'] == 'approved')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatPage(
                            requestId: r['id'],
                            otherUserId: r['owner_id'],
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.message, size: 16),
                    label: const Text('Chat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              if (isBorrower && r['status'] == 'approved')
                const SizedBox(height: 8),
              if (isBorrower && r['status'] == 'approved')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _markReturned(r['id']),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Return'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              // OWNER side - active (approved) or return confirmation (returned)
              if (isOwner && r['status'] == 'approved')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
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
                    icon: const Icon(Icons.message, size: 16),
                    label: const Text('Chat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              if (isOwner && r['status'] == 'returned') ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
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
                    icon: const Icon(Icons.message, size: 16),
                    label: const Text('Chat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmReturn(r['id'], r['books']['id']),
                    icon: const Icon(Icons.task_alt, size: 16),
                    label: const Text('Received'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
