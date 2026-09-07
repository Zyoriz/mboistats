import 'package:flutter/material.dart';

/// Pure-Dart search service: BM25 re-ranking + fuzzy match + ML boost.
/// Tidak ada dependensi native — aman untuk semua platform.
class SearchService {
  static const _k1 = 1.5;
  static const _b = 0.75;
  static const _mlBoost = 0.3;
  static const _exactBoost = 2.0;
  static const _fuzzyWeight = 0.5;
  static const _maxFuzzyDist = 2;

  static const _stopwords = {
    'dan', 'di', 'ke', 'yang', 'tahun', 'atau', 'untuk', 'dari', 'dengan',
    'pada', 'dalam', 'oleh', 'adalah', 'ini', 'itu', 'kota', 'malang',
    'menurut', 'berdasarkan', 'angka', 'hasil', 'tingkat', 'jumlah',
  };

  // ── Tokenisasi ──────────────────────────────────────────────────────────
  static List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 1 && !_stopwords.contains(t))
        .toList();
  }

  // ── Levenshtein distance ─────────────────────────────────────────────────
  static int _levenshtein(String a, String b) {
    final m = a.length, n = b.length;
    final dp = List<int>.generate(n + 1, (i) => i);
    for (int i = 1; i <= m; i++) {
      int prev = dp[0];
      dp[0] = i;
      for (int j = 1; j <= n; j++) {
        final temp = dp[j];
        dp[j] = a[i - 1] == b[j - 1]
            ? prev
            : 1 + [prev, dp[j], dp[j - 1]].reduce((a, b) => a < b ? a : b);
        prev = temp;
      }
    }
    return dp[n];
  }

  // ── Fuzzy score: 0.0–1.0, toleransi ≤ _maxFuzzyDist ────────────────────
  static double fuzzyScore(String queryToken, String title) {
    final words = _tokenize(title);
    if (words.isEmpty) return 0.0;
    double best = 0.0;
    for (final w in words) {
      final dist = _levenshtein(queryToken, w);
      if (dist <= _maxFuzzyDist) {
        final score = 1.0 - dist / [queryToken.length, w.length, 1].reduce((a, b) => a > b ? a : b);
        if (score > best) best = score;
      }
    }
    return best;
  }

  // ── BM25 score untuk satu dokumen ────────────────────────────────────────
  static double _bm25Score(
    List<String> queryTokens,
    List<String> docTokens,
    double avgDl,
  ) {
    final dl = docTokens.length.toDouble();
    final tf = <String, int>{};
    for (final t in docTokens) tf[t] = (tf[t] ?? 0) + 1;

    double score = 0.0;
    for (final qt in queryTokens) {
      final freq = (tf[qt] ?? 0).toDouble();
      if (freq == 0) continue;
      score += (freq * (_k1 + 1)) / (freq + _k1 * (1 - _b + _b * dl / avgDl));
    }
    return score;
  }

  // ── Re-rank utama ────────────────────────────────────────────────────────
  /// Re-rank [rawResults] berdasarkan BM25 + fuzzy + ML boost.
  /// [userRecommendedItemIds]: content IDs dari ml_recommendations.json user.
  static List<Map<String, dynamic>> rankResults({
    required String query,
    required List<Map<String, dynamic>> rawResults,
    List<String>? userRecommendedItemIds,
  }) {
    if (query.trim().isEmpty || rawResults.isEmpty) return rawResults;

    final queryTokens = _tokenize(query);
    if (queryTokens.isEmpty) return rawResults;

    final mlSet = userRecommendedItemIds?.toSet() ?? {};
    final queryLower = query.toLowerCase();

    // Hitung avg doc length dari corpus saat ini
    final allDocTokens = rawResults
        .map((item) => _tokenize((item['title'] ?? item['item_name'] ?? '') as String))
        .toList();
    final avgDl = allDocTokens.isEmpty
        ? 1.0
        : allDocTokens.map((t) => t.length).reduce((a, b) => a + b) / allDocTokens.length;

    final scored = <MapEntry<Map<String, dynamic>, double>>[];

    for (int i = 0; i < rawResults.length; i++) {
      final item = rawResults[i];
      final title = (item['title'] ?? item['item_name'] ?? '') as String;
      final docTokens = allDocTokens[i];

      double score = _bm25Score(queryTokens, docTokens, avgDl);

      // Fuzzy boost untuk token yang tidak exact match
      for (final qt in queryTokens) {
        if (!docTokens.contains(qt)) {
          score += fuzzyScore(qt, title) * _fuzzyWeight;
        }
      }

      // Exact phrase boost
      if (title.toLowerCase().contains(queryLower)) {
        score *= _exactBoost;
      }

      // ML recommendation boost
      final itemId = (item['id'] ?? item['content_id'] ?? '') as String;
      if (mlSet.contains(itemId)) {
        score += _mlBoost;
      }

      scored.add(MapEntry(item, score));
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).toList();
  }

  // ── Highlight keyword di UI ───────────────────────────────────────────────
  /// Kembalikan List<TextSpan> dengan keyword di-highlight.
  static List<TextSpan> highlightMatch(
    String text,
    String query,
    TextStyle normal,
    TextStyle highlight,
  ) {
    if (query.trim().isEmpty) return [TextSpan(text: text, style: normal)];

    final pattern = RegExp(
      query.trim().split(RegExp(r'\s+')).map(RegExp.escape).join('|'),
      caseSensitive: false,
    );

    final spans = <TextSpan>[];
    int last = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start), style: normal));
      }
      spans.add(TextSpan(text: text.substring(match.start, match.end), style: highlight));
      last = match.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: normal));
    }
    return spans.isEmpty ? [TextSpan(text: text, style: normal)] : spans;
  }
}
