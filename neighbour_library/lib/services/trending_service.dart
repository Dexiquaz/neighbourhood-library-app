import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TrendingService {
  final _client = Supabase.instance.client;

  /// Get trending books in the community
  /// Uses time-decay algorithm: recent activity weighted higher
  Future<List<Map<String, dynamic>>> getTrendingBooks({
    int limit = 10,
    int daysWindow = 30,
  }) async {
    try {
      final cutoffDate = DateTime.now()
          .subtract(Duration(days: daysWindow))
          .toIso8601String();

      // Get recent borrow activity
      final recentBorows = await _client
          .from('borrow_requests')
          .select('book_id, created_at, status')
          .gte('created_at', cutoffDate);

      if (recentBorows.isEmpty) {
        return [];
      }

      // Score books by activity with time decay
      final bookScores = <String, double>{};
      final now = DateTime.now();

      for (var borrow in recentBorows) {
        final bookId = borrow['book_id'] as String;
        final createdAt = DateTime.parse(borrow['created_at'] as String);
        final daysOld = now.difference(createdAt).inDays;

        // Time decay: newer activity weighted more
        // Formula: weight = e^(-0.1 * daysOld)
        final timeWeight = math.exp(-0.1 * daysOld);

        // Status weight: completed borrows weighted higher
        final status = borrow['status'] as String;
        final statusWeight = status == 'completed' ? 1.0 : 0.7;

        final weight = timeWeight * statusWeight;
        bookScores[bookId] = (bookScores[bookId] ?? 0) + weight;
      }

      // Get full book details for top books
      final sortedBooks = bookScores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final trendingBooks = <Map<String, dynamic>>[];

      for (var entry in sortedBooks.take(limit)) {
        try {
          final book = await _client
              .from('books')
              .select('*')
              .eq('id', entry.key)
              .single();

          trendingBooks.add({...book, 'trending_score': entry.value});
        } catch (e) {
          // Book not found, skip
        }
      }

      return trendingBooks;
    } catch (e) {
      debugPrint('Error fetching trending books: $e');
      return [];
    }
  }

  /// Get trending books by genre
  Future<Map<String, List<Map<String, dynamic>>>> getTrendingByGenre({
    int limit = 5,
    int daysWindow = 30,
  }) async {
    try {
      final cutoffDate = DateTime.now()
          .subtract(Duration(days: daysWindow))
          .toIso8601String();

      // Get recent borrows with book details
      final recentBorows = await _client
          .from('borrow_requests')
          .select('book_id, books!inner(genre, *), created_at, status')
          .gte('created_at', cutoffDate);

      // Group by genre and score
      final genreTrending = <String, Map<String, double>>{};
      final now = DateTime.now();

      for (var borrow in recentBorows) {
        final book = borrow['books'] as Map<String, dynamic>;
        final genre = book['genre'] as String?;

        if (genre == null || genre.isEmpty) continue;

        if (!genreTrending.containsKey(genre)) {
          genreTrending[genre] = {};
        }

        final bookId = book['id'] as String;
        final createdAt = DateTime.parse(borrow['created_at'] as String);
        final daysOld = now.difference(createdAt).inDays;
        final decayFactor = 0.1;
        final timeWeight = math.exp(-decayFactor * daysOld);
        final status = borrow['status'] as String;
        final statusWeight = status == 'completed' ? 1.0 : 0.7;
        final weight = timeWeight * statusWeight;

        genreTrending[genre]![bookId] =
            (genreTrending[genre]![bookId] ?? 0) + weight;
      }

      // Get full details for each trending book
      final result = <String, List<Map<String, dynamic>>>{};

      for (var genre in genreTrending.keys) {
        final bookScores = genreTrending[genre]!.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        result[genre] = [];

        for (var entry in bookScores.take(limit)) {
          try {
            final book = await _client
                .from('books')
                .select()
                .eq('id', entry.key)
                .single();

            result[genre]!.add({...book, 'trending_score': entry.value});
          } catch (e) {
            // Skip
          }
        }
      }

      return result;
    } catch (e) {
      debugPrint('Error fetching trending by genre: $e');
      return {};
    }
  }

  /// Calculate trending score for a specific book (used for batch updates)
  Future<double> calculateTrendingScore(String bookId) async {
    try {
      final thirtyDaysAgo = DateTime.now()
          .subtract(const Duration(days: 30))
          .toIso8601String();

      final borrows = await _client
          .from('borrow_requests')
          .select('created_at, status')
          .eq('book_id', bookId)
          .gte('created_at', thirtyDaysAgo);

      double score = 0.0;
      final now = DateTime.now();

      for (var borrow in borrows) {
        final createdAt = DateTime.parse(borrow['created_at'] as String);
        final daysOld = now.difference(createdAt).inDays;
        const decayConstant = 0.1;
        final timeWeight = math.exp(-decayConstant * daysOld);
        final statusWeight = borrow['status'] == 'completed' ? 1.0 : 0.7;
        score += timeWeight * statusWeight;
      }

      return score;
    } catch (e) {
      debugPrint('Error calculating trending score: $e');
      return 0.0;
    }
  }

  /// Update trending scores for all books (run periodically, e.g., daily)
  Future<void> updateAllTrendingScores() async {
    try {
      final allBooks = await _client.from('books').select('id');

      for (var book in allBooks) {
        final bookId = book['id'] as String;
        final score = await calculateTrendingScore(bookId);

        await _client
            .from('books')
            .update({'trending_score': score})
            .eq('id', bookId);
      }

      debugPrint('Updated trending scores for ${allBooks.length} books');
    } catch (e) {
      debugPrint('Error updating all trending scores: $e');
    }
  }
}
