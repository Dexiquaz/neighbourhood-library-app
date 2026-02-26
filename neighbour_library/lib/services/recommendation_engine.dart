import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RecommendationEngine {
  final _client = Supabase.instance.client;

  /// Recommend books based on user preferences and history
  /// Returns sorted list of book recommendations with scores
  Future<List<Map<String, dynamic>>> getPersonalizedRecommendations(
    String userId, {
    int limit = 10,
  }) async {
    try {
      // Get user preferences
      final userPrefs = await _client
          .from('user_preferences')
          .select()
          .eq('user_id', userId);

      Map<String, double>? genreScores;
      String? preferredCondition;

      if (userPrefs.isNotEmpty) {
        genreScores = Map<String, double>.from(
          (userPrefs[0]['genre_scores'] ?? {}) as Map,
        );
        preferredCondition = userPrefs[0]['preferred_condition'] as String?;
      }

      // Get all available books
      final allBooks = await _client.from('books').select('*');

      // Filter out books user is already borrowing
      final userBorrows = await _client
          .from('borrow_requests')
          .select('book_id')
          .eq('borrower_id', userId)
          .inFilter('status', ['pending', 'approved']);

      final borrowingBookIds = (userBorrows as List)
          .map((r) => r['book_id'])
          .toSet();

      // Score each book (filter owned by user in memory)
      final scoredBooks = (allBooks as List)
          .where((book) => book['owner_id'] != userId)
          .map((book) {
            double score = 0.0;

            if (genreScores != null && genreScores.isNotEmpty) {
              final genre = book['genre'] as String?;
              if (genre != null && genreScores.containsKey(genre)) {
                score += genreScores[genre]! * 40; // Max 40 points
              } else {
                score += 5; // Base points if no preference match
              }
            } else {
              score += 10; // Default if no preferences
            }

            // Popularity scoring
            final borrowCount = (book['borrow_count'] ?? 0) as int;
            score += (borrowCount / 10).clamp(0, 20); // Max 20 points

            // Rating scoring
            final rating = (book['rating'] as num?)?.toDouble() ?? 0.0;
            score += (rating / 5.0) * 30; // Max 30 points

            // Condition preference
            final condition = book['condition'] as String?;
            if (preferredCondition != null && condition == preferredCondition) {
              score += 10; // Max 10 points
            }

            // Recency bonus (books lent recently)
            final lastBorrowedAt = book['last_borrowed_at'] as String?;
            if (lastBorrowedAt != null) {
              final daysAgo = DateTime.now()
                  .difference(DateTime.parse(lastBorrowedAt))
                  .inDays;
              if (daysAgo < 30) {
                score += 5;
              }
            }

            return {...book, 'recommendation_score': score};
          })
          .toList();

      // Filter out books user is already borrowing
      final filtered = scoredBooks
          .where((book) => !borrowingBookIds.contains(book['id']))
          .toList();

      // Sort by recommendation score (descending)
      filtered.sort(
        (a, b) => (b['recommendation_score'] as num).compareTo(
          a['recommendation_score'] as num,
        ),
      );

      return filtered
          .take(limit)
          .map((book) => Map<String, dynamic>.from(book))
          .toList();
    } catch (e) {
      debugPrint('Error generating recommendations: $e');
      return [];
    }
  }

  /// Collaborative filtering: similar users' preferences
  Future<List<Map<String, dynamic>>> getCollaborativeRecommendations(
    String userId, {
    int limit = 5,
  }) async {
    try {
      // Get this user's genre preferences
      final myPrefs = await _client
          .from('user_preferences')
          .select('genre_scores')
          .eq('user_id', userId);

      if (myPrefs.isEmpty) {
        return [];
      }

      final myGenres = Map<String, double>.from(
        (myPrefs[0]['genre_scores'] ?? {}) as Map,
      );

      if (myGenres.isEmpty) {
        return [];
      }

      // Find users with similar preferences
      final otherUsers = await _client
          .from('user_preferences')
          .select()
          .neq('user_id', userId);

      // Calculate similarity scores
      final userSimilarities = <String, double>{};

      for (var otherUser in otherUsers) {
        final otherId = otherUser['user_id'] as String;
        final otherGenres = Map<String, double>.from(
          (otherUser['genre_scores'] ?? {}) as Map,
        );

        // Calculate cosine similarity
        double similarity = _cosineSimilarity(myGenres, otherGenres);
        if (similarity > 0.3) {
          // Only consider if reasonably similar
          userSimilarities[otherId] = similarity;
        }
      }

      if (userSimilarities.isEmpty) {
        return [];
      }

      // Get books borrowed by similar users
      final similarUserIds = userSimilarities.keys.toList();
      final similarBorrows = await _client
          .from('borrow_requests')
          .select('books(*)')
          .inFilter('borrower_id', similarUserIds)
          .eq('status', 'completed');

      // Score books based on similar user preferences
      final bookScores = <String, double>{};

      for (var borrow in similarBorrows) {
        final book = borrow['books'] as Map<String, dynamic>;
        final bookId = book['id'] as String;
        final borrowerId = borrow['borrower_id'] as String;
        final similarity = userSimilarities[borrowerId] ?? 1.0;

        bookScores[bookId] = (bookScores[bookId] ?? 0) + similarity;
      }

      // Get full book details for top-scored books
      final topBooks = bookScores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final recommendations = <Map<String, dynamic>>[];

      for (var entry in topBooks.take(limit)) {
        try {
          final book = await _client
              .from('books')
              .select()
              .eq('id', entry.key)
              .single();

          if (book['owner_id'] != userId) {
            recommendations.add({...book, 'collab_score': entry.value});
          }
        } catch (e) {
          // Book not found, skip
        }
      }

      return recommendations;
    } catch (e) {
      debugPrint('Error with collaborative recommendations: $e');
      return [];
    }
  }

  /// Calculate cosine similarity between two preference vectors
  double _cosineSimilarity(Map<String, double> a, Map<String, double> b) {
    final allKeys = {...a.keys, ...b.keys};
    final vectorA = allKeys.map((k) => a[k] ?? 0.0).toList();
    final vectorB = allKeys.map((k) => b[k] ?? 0.0).toList();

    double dotProduct = 0.0;
    double magnitudeA = 0.0;
    double magnitudeB = 0.0;

    for (int i = 0; i < vectorA.length; i++) {
      dotProduct += vectorA[i] * vectorB[i];
      magnitudeA += vectorA[i] * vectorA[i];
      magnitudeB += vectorB[i] * vectorB[i];
    }

    magnitudeA = math.sqrt(magnitudeA);
    magnitudeB = math.sqrt(magnitudeB);

    if (magnitudeA == 0.0 || magnitudeB == 0.0) {
      return 0.0;
    }

    return dotProduct / (magnitudeA * magnitudeB);
  }
}
