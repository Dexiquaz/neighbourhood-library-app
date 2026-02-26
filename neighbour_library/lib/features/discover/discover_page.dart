import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/recommendation_engine.dart';
import '../../services/trending_service.dart';
import '../../ui/app_scaffold.dart';
import '../explore/explore_page.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final _recommendations = RecommendationEngine();
  final _trending = TrendingService();
  final _client = Supabase.instance.client;

  bool _loading = true;
  List<Map<String, dynamic>> _recommendedBooks = [];
  List<Map<String, dynamic>> _trendingBooks = [];
  List<Map<String, dynamic>> _collaborativeBooks = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      final userId = _client.auth.currentUser!.id;

      // Fetch all three recommendation types in parallel
      await Future.wait([
        _loadRecommendations(userId),
        _loadTrending(),
        _loadCollaborative(userId),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading recommendations: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadRecommendations(String userId) async {
    try {
      final books = await _recommendations.getPersonalizedRecommendations(
        userId,
        limit: 8,
      );
      if (mounted) {
        setState(() => _recommendedBooks = books);
      }
    } catch (e) {
      debugPrint('Error loading recommendations: $e');
    }
  }

  Future<void> _loadTrending() async {
    try {
      final books = await _trending.getTrendingBooks(limit: 8);
      if (mounted) {
        setState(() => _trendingBooks = books);
      }
    } catch (e) {
      debugPrint('Error loading trending: $e');
    }
  }

  Future<void> _loadCollaborative(String userId) async {
    try {
      final books = await _recommendations.getCollaborativeRecommendations(
        userId,
        limit: 6,
      );
      if (mounted) {
        setState(() => _collaborativeBooks = books);
      }
    } catch (e) {
      debugPrint('Error loading collaborative recommendations: $e');
    }
  }

  Widget _buildBookCard(Map<String, dynamic> book) {
    final title = book['title'] as String? ?? 'Unknown';
    final author = book['author'] as String? ?? 'Unknown Author';
    final genre = book['genre'] as String? ?? 'General';
    final rating = (book['rating'] as num?)?.toDouble() ?? 0.0;
    final borrowCount = book['borrow_count'] as int? ?? 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ExplorePage()),
        );
      },
      child: Card(
        color: Colors.white10,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book cover placeholder
            Container(
              width: double.infinity,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Center(
                child: Icon(Icons.book, size: 48, color: Colors.white24),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      genre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.blue.shade400,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.share, size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          '$borrowCount lent',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Map<String, dynamic>> books) {
    if (books.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: books.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 160,
                  child: _buildBookCard(books[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppScaffold(
        title: 'Discover',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return AppScaffold(
      title: 'Discover Books',
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Personalized Recommendations
            if (_recommendedBooks.isNotEmpty)
              _buildSection('For You', _recommendedBooks),

            // Trending Books
            if (_trendingBooks.isNotEmpty)
              _buildSection('Trending Now', _trendingBooks),

            // Collaborative Recommendations
            if (_collaborativeBooks.isNotEmpty)
              _buildSection('Users Like You Loved', _collaborativeBooks),

            // Empty state
            if (_recommendedBooks.isEmpty &&
                _trendingBooks.isEmpty &&
                _collaborativeBooks.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.info_outline, size: 48, color: Colors.white24),
                      const SizedBox(height: 16),
                      const Text(
                        'Start borrowing books to get personalized recommendations!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
