import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

abstract class SearchHistoryRepository {
  Future<List<String>> getSearchHistory();
  Future<void> addSearchQuery(String query);
  Future<void> removeSearchQuery(String query);
  Future<void> clearSearchHistory();
}

class SearchHistoryRepositoryImpl implements SearchHistoryRepository {
  File? _cachedFile;

  Future<File> _getFile() async {
    if (_cachedFile != null) return _cachedFile!;
    final dir = await getApplicationDocumentsDirectory();
    _cachedFile = File(p.join(dir.path, 'search_history.json'));
    return _cachedFile!;
  }

  @override
  Future<List<String>> getSearchHistory() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      final decoded = jsonDecode(content);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> addSearchQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    try {
      final history = await getSearchHistory();
      // Remove any existing duplicate (case-insensitive)
      history.removeWhere((item) => item.toLowerCase() == trimmed.toLowerCase());
      // Insert at the beginning (most recent first)
      history.insert(0, trimmed);
      // Keep only up to 25 recent items
      if (history.length > 25) {
        history.removeRange(25, history.length);
      }
      final file = await _getFile();
      await file.writeAsString(jsonEncode(history));
    } catch (_) {}
  }

  @override
  Future<void> removeSearchQuery(String query) async {
    try {
      final history = await getSearchHistory();
      history.removeWhere((item) => item.toLowerCase() == query.trim().toLowerCase());
      final file = await _getFile();
      await file.writeAsString(jsonEncode(history));
    } catch (_) {}
  }

  @override
  Future<void> clearSearchHistory() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        await file.writeAsString(jsonEncode([]));
      }
    } catch (_) {}
  }
}
