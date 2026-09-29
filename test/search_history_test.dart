import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:musify/data/repositories/search_history_repository.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final Directory tempDir;
  MockPathProviderPlatform(this.tempDir);

  @override
  Future<String?> getApplicationDocumentsPath() async => tempDir.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late SearchHistoryRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('search_history_test_');
    PathProviderPlatform.instance = MockPathProviderPlatform(tempDir);
    repository = SearchHistoryRepositoryImpl();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SearchHistoryRepository Tests', () {
    test('Initial search history is empty', () async {
      final history = await repository.getSearchHistory();
      expect(history, isEmpty);
    });

    test('Adding queries adds to top and deduplicates', () async {
      await repository.addSearchQuery('Arijit Singh');
      await repository.addSearchQuery('Atif Aslam');
      await repository.addSearchQuery('arijit singh'); // Case-insensitive duplicate

      final history = await repository.getSearchHistory();
      expect(history.length, 2);
      expect(history[0], 'arijit singh'); // Moved to top
      expect(history[1], 'Atif Aslam');
    });

    test('Empty or whitespace queries are ignored', () async {
      await repository.addSearchQuery('');
      await repository.addSearchQuery('   ');
      final history = await repository.getSearchHistory();
      expect(history, isEmpty);
    });

    test('Removing a query removes it correctly', () async {
      await repository.addSearchQuery('Song 1');
      await repository.addSearchQuery('Song 2');
      await repository.removeSearchQuery('Song 1');

      final history = await repository.getSearchHistory();
      expect(history, ['Song 2']);
    });

    test('Clearing history empties the list', () async {
      await repository.addSearchQuery('Song 1');
      await repository.addSearchQuery('Song 2');
      await repository.clearSearchHistory();

      final history = await repository.getSearchHistory();
      expect(history, isEmpty);
    });

    test('Limits history to 25 items', () async {
      for (int i = 1; i <= 30; i++) {
        await repository.addSearchQuery('Query $i');
      }
      final history = await repository.getSearchHistory();
      expect(history.length, 25);
      expect(history.first, 'Query 30');
    });
  });
}
