import 'package:flutter/material.dart';
import 'package:neighbour_library/ui/status_chip.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../ui/book_card.dart';
import '../../../ui/empty_state.dart';
import '../../../services/analytics_service.dart';
import '../../chat/chat_page.dart';
import '../../profile/view_profile_page.dart';

class IncomingTab extends StatefulWidget {
  const IncomingTab({super.key});

  @override
  State<IncomingTab> createState() => _IncomingTabState();
}

class _IncomingTabState extends State<IncomingTab> {
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
              // BORROWER — pending
              if (status == 'pending' && isBorrower) ...[
                Row(
                  children: [
                    Expanded(
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ViewProfilePage(userId: r['owner_id']),
                            ),
                          );
                        },
                        icon: const Icon(Icons.person, size: 16),
                        label: const Text('Profile'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const StatusChip(label: 'Requested', color: Colors.orange),
              ],
              // OWNER — pending
              if (status == 'pending' && isOwner) ...[
                Row(
                  children: [
                    Expanded(
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ViewProfilePage(userId: r['borrower_id']),
                            ),
                          );
                        },
                        icon: const Icon(Icons.person, size: 16),
                        label: const Text('Profile'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _approve(r['id'], book['id']),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _deny(r['id']),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Deny'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ---- Actions ----

  Future<void> _approve(String requestId, String bookId) async {
    final userId = _client.auth.currentUser!.id;

    await _client
        .from('borrow_requests')
        .update({'status': 'approved'})
        .eq('id', requestId);

    await _client.from('books').update({'status': 'borrowed'}).eq('id', bookId);

    // Log the borrow request approval
    await _analyticsService.logEvent(
      userId: userId,
      bookId: bookId,
      eventType: 'borrow_request_approved',
    );

    _fetch();
  }

  Future<void> _deny(String requestId) async {
    await _client
        .from('borrow_requests')
        .update({'status': 'rejected'})
        .eq('id', requestId);

    // Log the borrow request denial
    await _analyticsService.logEvent(
      userId: _client.auth.currentUser!.id,
      bookId: null,
      eventType: 'borrow_request_denied',
    );

    _fetch();
  }
}
