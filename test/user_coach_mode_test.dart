import 'package:flutter_test/flutter_test.dart';

import 'package:fittrack_ai/models/user.dart';

void main() {
  test('coach mode is persisted in the user map and defaults off', () {
    final user = User(
      id: 'user-1',
      firstName: 'Test',
      lastName: 'User',
      email: 'test@example.com',
      passwordHash: 'hash',
      isOnboarded: true,
      createdAt: DateTime(2026),
    );

    final regularUser = User.fromDatabaseMap(user.toDatabaseMap());
    final coach = regularUser.copyWith(isCoach: true);
    final restoredCoach = User.fromDatabaseMap(coach.toDatabaseMap());

    expect(regularUser.isCoach, isFalse);
    expect(coach.isCoach, isTrue);
    expect(restoredCoach.isCoach, isTrue);
    expect(coach.copyWith(isCoach: false).isCoach, isFalse);
  });
}
