import 'package:flutter_test/flutter_test.dart';
import 'package:lifesync/services/update_service.dart';

void main() {
  test('Đọc số build từ tag', () {
    expect(parseBuild('build-12'), 12);
    expect(parseBuild('build-7 '), 7);
    expect(parseBuild('v1.0.3'), 3);
    expect(parseBuild('khong-co-so'), isNull);
  });
}
