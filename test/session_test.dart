import 'package:flutter_test/flutter_test.dart';
import 'package:nguyen_tan_tai_attendance_app/api/team_api.dart';
import 'package:nguyen_tan_tai_attendance_app/auth/auth_session.dart';

import 'fixtures.dart';

void main() {
  test('reads confirmed user response and admin role without decoding JWT', () {
    final session = AuthSession.fromJson(verifiedResponse());
    expect(session.accessToken, 'test-access');
    expect(session.refreshToken, 'test-refresh');
    expect(session.user.name, 'Demo');
    expect(session.user.isAdmin, true);
  });
  test('employee and unknown role never gain admin privileges', () {
    expect(
      AuthSession.fromJson(verifiedResponse(role: 'employee')).user.isAdmin,
      false,
    );
    expect(
      AuthSession.fromJson(verifiedResponse(role: 'guest')).user.isAdmin,
      false,
    );
  });
  test('missing token rejects malformed success', () {
    final data = verifiedResponse()..remove('accessToken');
    expect(() => AuthSession.fromJson(data), throwsA(isA<ApiFailure>()));
  });
  test(
    'expired token and inactive account cannot open protected dashboard',
    () {
      final expired = verifiedResponse()
        ..['accessExpiresAt'] = '2000-01-01T00:00:00Z';
      expect(() => AuthSession.fromJson(expired), throwsA(isA<ApiFailure>()));
      final inactive = verifiedResponse();
      (inactive['user'] as Map)['active'] = false;
      expect(() => AuthSession.fromJson(inactive), throwsA(isA<ApiFailure>()));
    },
  );
  test('malformed expiry and missing role are rejected', () {
    final invalid = verifiedResponse()..['accessExpiresAt'] = 'not-a-date';
    expect(() => AuthSession.fromJson(invalid), throwsA(isA<ApiFailure>()));
    final noRole = verifiedResponse();
    (noRole['user'] as Map).remove('role');
    expect(() => AuthSession.fromJson(noRole), throwsA(isA<ApiFailure>()));
  });
}
