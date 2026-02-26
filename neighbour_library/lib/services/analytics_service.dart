import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnalyticsService {
  final _client = Supabase.instance.client;

  /// Log user activity for analytics
  Future<void> logEvent({
    required String userId,
    required String? bookId,
    required String eventType,
  }) async {
    try {
      await _client.from('analytics_logs').insert({
        'user_id': userId,
        'book_id': bookId,
        'event_type': eventType,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error logging analytics event: $e');
    }
  }

  /// Get user's genre preferences based on borrow history
  Future<Map<String, double>> getUserGenrePreferences(String userId) async {
    try {
      // Fetch user's borrowed books
      final borrowHistory = await _client
          .from('borrow_requests')
          .select('books!inner(genre, rating)')
          .eq('borrower_id', userId)
          .eq('status', 'completed');

      if (borrowHistory.isEmpty) {
        return {};
      }

      // Count genre frequencies and average ratings
      final genreScores = <String, List<double>>{};

      for (var request in borrowHistory) {
        final book = request['books'] as Map<String, dynamic>;
        final genre = book['genre'] as String?;
        final rating = (book['rating'] as num?)?.toDouble() ?? 0.0;

        if (genre != null && genre.isNotEmpty) {
          if (!genreScores.containsKey(genre)) {
            genreScores[genre] = [];
          }
          genreScores[genre]!.add(rating);
        }
      }

      // Calculate average scores for each genre
      final preferences = <String, double>{};
      genreScores.forEach((genre, ratings) {
        final avgRating = ratings.isEmpty
            ? 0.0
            : ratings.reduce((a, b) => a + b) / ratings.length;
        // Normalize to 0-1 scale and boost by frequency
        final frequency = ratings.length / borrowHistory.length;
        preferences[genre] = (avgRating / 5.0) * 0.6 + frequency * 0.4;
      });

      return preferences;
    } catch (e) {
      debugPrint('Error fetching genre preferences: $e');
      return {};
    }
  }

  /// Update user preferences table
  Future<void> updateUserPreferences(
    String userId,
    Map<String, double> genreScores,
    String? preferredCondition,
  ) async {
    try {
      final existing = await _client
          .from('user_preferences')
          .select()
          .eq('user_id', userId);

      if (existing.isEmpty) {
        await _client.from('user_preferences').insert({
          'user_id': userId,
          'genre_scores': genreScores,
          'preferred_condition': preferredCondition ?? 'good',
          'updated_at': DateTime.now().toIso8601String(),
        });
      } else {
        await _client
            .from('user_preferences')
            .update({
              'genre_scores': genreScores,
              'preferred_condition': preferredCondition ?? 'good',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', userId);
      }
    } catch (e) {
      debugPrint('Error updating user preferences: $e');
    }
  }

  /// Calculate book completion rate (user reliability)
  Future<double> getUserCompletionRate(String userId) async {
    try {
      final requests = await _client
          .from('borrow_requests')
          .select('status')
          .eq('borrower_id', userId);

      if (requests.isEmpty) return 0.0;

      final completed = (requests as List)
          .where((r) => r['status'] == 'completed')
          .length;
      return completed / requests.length;
    } catch (e) {
      debugPrint('Error calculating completion rate: $e');
      return 0.0;
    }
  }

  /// Get books borrowed by user (for similarity analysis)
  Future<List<String>> getUserBorrowedGenres(String userId) async {
    try {
      final borrowHistory = await _client
          .from('borrow_requests')
          .select('books!inner(genre)')
          .eq('borrower_id', userId)
          .eq('status', 'completed');

      final genres = <String>{};
      for (var request in borrowHistory) {
        final book = request['books'] as Map<String, dynamic>;
        final genre = book['genre'] as String?;
        if (genre != null && genre.isNotEmpty) {
          genres.add(genre);
        }
      }
      return genres.toList();
    } catch (e) {
      debugPrint('Error fetching borrowed genres: $e');
      return [];
    }
  }
}
