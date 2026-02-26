import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../ui/app_scaffold.dart';
import '../../ui/book_card.dart';
import '../../ui/empty_state.dart';
import '../../services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import '../profile/view_profile_page.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final _client = Supabase.instance.client;

  static const double _radiusKm = 3.0;

  Future<void> _requestBorrow(Map<String, dynamic> book) async {
    final userId = _client.auth.currentUser!.id;

    try {
      await _client.from('borrow_requests').insert({
        'book_id': book['id'],
        'borrower_id': userId,
        'owner_id': book['owner_id'],
        'status': 'pending',
      });

      setState(() {
        _requestedBookIds.add(book['id']);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _fetchMyRequests() async {
    final userId = _client.auth.currentUser!.id;

    final data = await _client
        .from('borrow_requests')
        .select('book_id')
        .eq('borrower_id', userId)
        .eq('status', 'pending');

    for (final row in data) {
      _requestedBookIds.add(row['book_id']);
    }
  }

  Future<void> _updateLocation() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final position = await LocationService().getCurrentLocation();

      await _client
          .from('profiles')
          .update({
            'latitude': position.latitude,
            'longitude': position.longitude,
          })
          .eq('id', user.id);
    } catch (e) {
      // Location errors should NOT crash Explore
      debugPrint('Location error: $e');
    }
  }

  double _distanceInKm(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }

  @override
  void initState() {
    super.initState();
    _updateLocation();
    _fetchMyRequests().then((_) => _fetchBooks());
  }

  List<dynamic> _books = [];
  bool _loading = true;
  final Set<String> _requestedBookIds = {};

  Future<void> _fetchBooks() async {
    final userId = _client.auth.currentUser!.id;
    final myProfile = await _client
        .from('profiles')
        .select('latitude, longitude')
        .eq('id', userId)
        .single();

    final myLat = (myProfile['latitude'] as num).toDouble();
    final myLng = (myProfile['longitude'] as num).toDouble();

    final data = await _client
        .from('books')
        .select('''
      id,
      title,
      author,
      owner_id,
      profiles!books_owner_id_fkey (
        latitude,
        longitude
      )
    ''')
        .neq('owner_id', userId)
        .eq('status', 'available')
        .order('created_at', ascending: false);

    if (!mounted) return;

    final booksWithDistance = data
        .map((book) {
          final ownerProfile = book['profiles'];
          if (ownerProfile == null) return null;

          final ownerLat = (ownerProfile['latitude'] as num).toDouble();
          final ownerLng = (ownerProfile['longitude'] as num).toDouble();

          final distance = _distanceInKm(myLat, myLng, ownerLat, ownerLng);

          book['distance'] = distance;
          return book;
        })
        .whereType<Map<String, dynamic>>()
        .where((book) => book['distance'] <= _radiusKm) // 🔑 FILTER
        .toList();

    // Optional but recommended: nearest first
    booksWithDistance.sort((a, b) => a['distance'].compareTo(b['distance']));

    setState(() {
      _books = booksWithDistance;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Explore Books',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _books.isEmpty
          ? const EmptyState(message: 'No books available nearby')
          : ListView.builder(
              itemCount: _books.length,
              itemBuilder: (context, index) {
                final book = _books[index];

                final alreadyRequested = _requestedBookIds.contains(book['id']);
                return BookCard(
                  title: book['title'],
                  author: book['author'] ?? 'Unknown author',
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${book['distance'].toStringAsFixed(1)} km away',
                        style: const TextStyle(color: Colors.white54),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ViewProfilePage(
                                      userId: book['owner_id'],
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.person, size: 16),
                              label: const Text('View Profile'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple.shade700,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: alreadyRequested
                            ? ElevatedButton(
                                onPressed: null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange.shade700,
                                  disabledBackgroundColor:
                                      Colors.orange.shade700,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Pending'),
                              )
                            : ElevatedButton.icon(
                                onPressed: () => _requestBorrow(book),
                                icon: const Icon(Icons.send, size: 16),
                                label: const Text('Request Borrow'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade700,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
