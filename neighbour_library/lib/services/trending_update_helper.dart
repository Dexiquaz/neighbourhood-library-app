import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Helper service for managing trending score updates
/// Can be called periodically (e.g., via background jobs) or on-demand
class TrendingUpdateHelper {
  final _client = Supabase.instance.client;

  /// Update trending scores for all books based on recent activity
  /// Call this periodically (e.g., daily or after significant activity)
  /// or when you want to refresh the trending data
  Future<void> updateAllTrendingScores() async {
    try {
      debugPrint('[TrendingUpdateHelper] Starting trending score update...');

      final allBooks = await _client
          .from('books')
          .select('id')
          .order('created_at', ascending: true);

      int updated = 0;

      for (final book in allBooks) {
        final bookId = book['id'] as String;

        // Calculate trending score for this book
        final score = await _calculateTrendingScore(bookId);

        // Update the trending_score in the books table
        await _client
            .from('books')
            .update({'trending_score': score})
            .eq('id', bookId);

        updated++;
      }

      debugPrint(
        '[TrendingUpdateHelper] Updated trending scores for $updated books',
      );
    } catch (e) {
      debugPrint('[TrendingUpdateHelper] Error updating trending scores: $e');
    }
  }

  /// Calculate trending score for a single book
  /// Uses exponential time decay: e^(-0.1 * daysOld)
  /// Weighted by transaction status (completed: 1.0, pending: 0.7)
  Future<double> _calculateTrendingScore(String bookId) async {
    try {
      // Get all borrow requests for this book in the last 30 days
      final thirtyDaysAgo = DateTime.now()
          .subtract(const Duration(days: 30))
          .toIso8601String();

      final requests = await _client
          .from('borrow_requests')
          .select('status, created_at')
          .eq('book_id', bookId)
          .gt('created_at', thirtyDaysAgo);

      if (requests.isEmpty) {
        return 0.0;
      }

      double totalScore = 0.0;

      for (final request in requests) {
        final createdAt = DateTime.parse(request['created_at'] as String);
        final daysOld = DateTime.now().difference(createdAt).inDays.toDouble();

        // Status weight: completed transactions worth more
        final statusWeight = request['status'] == 'completed' ? 1.0 : 0.7;

        // Time decay: older activity counts less
        final timeDecay = math.exp(-0.1 * daysOld);

        totalScore += timeDecay * statusWeight;
      }

      // Normalize to 0-100 range
      // Max possible: 30 completed requests with immediate timestamps ≈ 30
      final normalizedScore = (totalScore / 30 * 100).clamp(0, 100).toDouble();

      return normalizedScore;
    } catch (e) {
      debugPrint(
        '[TrendingUpdateHelper] Error calculating trending score for $bookId: $e',
      );
      return 0.0;
    }
  }

  /// Manual update for a single book (call after significant activity)
  Future<void> updateSingleBookTrendingScore(String bookId) async {
    try {
      final score = await _calculateTrendingScore(bookId);
      await _client
          .from('books')
          .update({'trending_score': score})
          .eq('id', bookId);

      debugPrint(
        '[TrendingUpdateHelper] Updated trending score for $bookId: $score',
      );
    } catch (e) {
      debugPrint(
        '[TrendingUpdateHelper] Error updating single book trending score: $e',
      );
    }
  }
}
