import 'package:flutter_test/flutter_test.dart';
import 'package:musify/core/constants/app_constants.dart';

void main() {
  test('AppConstants smoke test', () {
    expect(AppConstants.appName, 'Musify');
  });
}
