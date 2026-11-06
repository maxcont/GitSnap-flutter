import 'package:flutter_test/flutter_test.dart';
import 'package:gitsnap_flutter/models/azure_models.dart';

void main() {
  test('reads the author date from an Azure commit', () {
    final commit = Commit.fromJson({
      'commitId': '123',
      'author': {'name': 'Ada', 'date': '2026-03-12T10:00:00Z'},
      'committer': {'name': 'Bob', 'date': '2026-03-13T10:00:00Z'},
    });

    expect(commit.date, '2026-03-12T10:00:00Z');
  });

  test('preserves a top-level date when the author date is unavailable', () {
    final commit = Commit.fromJson({
      'commitId': '123',
      'author': {'name': 'Ada'},
      'date': '2026-03-12T10:00:00Z',
    });

    expect(commit.date, '2026-03-12T10:00:00Z');
  });

  test('keeps an absent date unavailable', () {
    final commit = Commit.fromJson({'commitId': '123'});
    expect(commit.date, isNull);
  });
}
