import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../ui/app_scaffold.dart';
import '../../ui/empty_state.dart';
import '../../ui/book_card.dart';

class OwnerRequestsPage extends StatefulWidget {
  const OwnerRequestsPage({super.key});

  @override
  State<OwnerRequestsPage> createState() => _OwnerRequestsPageState();
}

class _OwnerRequestsPageState extends State<OwnerRequestsPage> {
  final _client = Supabase.instance.client;
  List<dynamic> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
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
          .eq('owner_id', userId)
          .inFilter('status', ['pending', 'returned'])
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _requests = data;
      });
    } catch (e) {
      debugPrint('Fetch requests error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false; // 🔑 GUARANTEED RESET
        });
      }
    }
  }

  Future<void> _updateRequest(String requestId, String status) async {
    setState(() {
      _loading = true;
    });

    try {
      final request = _requests.firstWhere((r) => r['id'] == requestId);
      final bookId = request['books']['id'];

      await _client
          .from('borrow_requests')
          .update({'status': status})
          .eq('id', requestId);

      if (status == 'approved') {
        await _client
            .from('books')
            .update({'status': 'borrowed'})
            .eq('id', bookId);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Request $status')));

      await _fetchRequests();
    } catch (e) {
      debugPrint('Update request error: $e');
    }
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

    if (!mounted) return;

    setState(() {
      _requests.removeWhere((r) => r['id'] == requestId);
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Return confirmed')));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Borrow Requests',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
          ? const EmptyState(message: 'No pending requests')
          : ListView.builder(
              itemCount: _requests.length,
              itemBuilder: (context, index) {
                final req = _requests[index];
                final book = req['books'];

                final status = req['status'];

                Widget action;

                if (status == 'pending') {
                  action = Row(
                    children: [
                      ElevatedButton(
                        onPressed: () => _updateRequest(req['id'], 'approved'),
                        child: const Text('Approve'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => _updateRequest(req['id'], 'rejected'),
                        child: const Text('Reject'),
                      ),
                    ],
                  );
                } else if (status == 'returned') {
                  action = ElevatedButton(
                    onPressed: () => _confirmReturn(req['id'], book['id']),
                    child: const Text('Confirm Return'),
                  );
                } else {
                  action = const SizedBox.shrink();
                }

                return BookCard(
                  title: book['title'],
                  author: book['author'] ?? '',
                  subtitle: action,
                );
              },
            ),
    );
  }
}
