import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../ui/app_scaffold.dart';

class ViewProfilePage extends StatefulWidget {
  final String userId;
  final String? userName;

  const ViewProfilePage({super.key, required this.userId, this.userName});

  @override
  State<ViewProfilePage> createState() => _ViewProfilePageState();
}

class _ViewProfilePageState extends State<ViewProfilePage> {
  final _client = Supabase.instance.client;

  bool _loading = true;
  Map<String, dynamic>? _profile;
  int _booksOwned = 0;
  int _booksLent = 0;
  int _completedTransactions = 0;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _fetchStats();
  }

  Future<void> _fetchProfile() async {
    setState(() => _loading = true);

    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', widget.userId)
          .single();

      setState(() {
        _profile = data;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchStats() async {
    try {
      // Books owned
      final ownedBooks = await _client
          .from('books')
          .select('id')
          .eq('owner_id', widget.userId);
      _booksOwned = (ownedBooks as List).length;

      // Books lent (approved or returned status)
      final lentBooks = await _client
          .from('borrow_requests')
          .select('id')
          .eq('owner_id', widget.userId)
          .inFilter('status', ['approved', 'returned']);
      _booksLent = (lentBooks as List).length;

      // Completed transactions
      final completedTxn = await _client
          .from('borrow_requests')
          .select('id')
          .or('owner_id.eq.${widget.userId},borrower_id.eq.${widget.userId}')
          .eq('status', 'completed');
      _completedTransactions = (completedTxn as List).length;

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error fetching stats: $e');
    }
  }

  Widget _buildProfilePicture() {
    final name = _profile?['name'] ?? widget.userName ?? 'U';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Center(
      child: CircleAvatar(
        radius: 60,
        backgroundColor: Colors.blue.shade700,
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue.shade400, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value.toString(),
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return AppScaffold(
        title: widget.userName ?? 'Profile',
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final name = _profile?['name'] ?? 'Unknown';
    final age = _profile?['age']?.toString() ?? 'Not specified';
    final gender = _profile?['gender'] ?? 'Not specified';
    final locality = _profile?['locality'] ?? 'Unknown';

    return AppScaffold(
      title: name,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfilePicture(),
            const SizedBox(height: 24),

            // Statistics
            Row(
              children: [
                _buildStatCard(
                  'Books\nOwned',
                  _booksOwned,
                  Icons.library_books,
                  Colors.blue,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  'Books\nLent',
                  _booksLent,
                  Icons.share,
                  Colors.green,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  'Completed',
                  _completedTransactions,
                  Icons.check_circle,
                  Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // User Details
            const Text(
              'Profile Information',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            _buildInfoCard('Name', name, Icons.person),
            const SizedBox(height: 12),

            _buildInfoCard('Age', age, Icons.cake),
            const SizedBox(height: 12),

            _buildInfoCard('Gender', gender, Icons.wc),
            const SizedBox(height: 12),

            _buildInfoCard('Location', locality, Icons.location_on),
          ],
        ),
      ),
    );
  }
}
