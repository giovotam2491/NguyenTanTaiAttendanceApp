import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nguyen_tan_tai_attendance_app/api/team_api.dart';

void main() {
  test(
    'API error text preserves status and uncertain write semantics',
    () async {
      final api = TeamApi(
        client: MockClient(
          (r) async => http.Response(
            jsonEncode({'error': 'Nhập nhận xét khi duyệt hoặc từ chối.'}),
            503,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      await expectLater(
        api.create('requests', {}, 'test-token'),
        throwsA(
          isA<ApiFailure>()
              .having(
                (e) => e.message,
                'message',
                'Nhập nhận xét khi duyệt hoặc từ chối.',
              )
              .having((e) => e.status, 'status', 503)
              .having((e) => e.outcomeUnknown, 'unknown', true),
        ),
      );
    },
  );
  test('ASP.NET validation errors are readable', () async {
    final api = TeamApi(
      client: MockClient(
        (r) async =>
            http.Response('{"errors":{"Note":["Note is required."]}}', 400),
      ),
    );
    await expectLater(
      api.login('demo', 'secret'),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.message,
          'message',
          'Note is required.',
        ),
      ),
    );
  });
  for (final body in [
    'not-json',
    '<html>gateway</html>',
    '{"error":123}',
    jsonEncode({'error': 'x' * 1001}),
    '{"error":"<script>bad</script>"}',
  ]) {
    test(
      'malformed or unsafe error uses status fallback ${body.length}',
      () async {
        final api = TeamApi(
          client: MockClient((r) async => http.Response(body, 403)),
        );
        await expectLater(
          api.list('employees', 'token'),
          throwsA(
            isA<ApiFailure>()
                .having(
                  (e) => e.message,
                  'message',
                  'Bạn không có quyền thực hiện thao tác này.',
                )
                .having((e) => e.status, 'status', 403),
          ),
        );
      },
    );
  }

  test(
    'login sends username and unmodified password without bearer token',
    () async {
      final api = TeamApi(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/auth/login');
          expect(jsonDecode(request.body), {
            'username': 'employee',
            'password': ' secret ',
          });
          expect(request.headers.containsKey('Authorization'), false);
          return http.Response('{"challenge":"fixture-only"}', 200);
        }),
      );
      expect(await api.login('employee', ' secret '), {
        'challenge': 'fixture-only',
      });
    },
  );
  test('verify uses team verify-otp endpoint and exact body', () async {
    final api = TeamApi(
      client: MockClient((request) async {
        expect(request.url.path, '/api/auth/verify-otp');
        expect(jsonDecode(request.body), {
          'challengeId': 'test-id',
          'code': '123456',
        });
        return http.Response('{}', 200);
      }),
    );
    await api.verifyOtp('test-id', '123456');
  });
  test(
    'protected employee list includes authorization and encoded query',
    () async {
      final api = TeamApi(
        client: MockClient((request) async {
          expect(request.url.path, '/api/employees');
          expect(request.headers['Authorization'], 'Bearer test-token');
          return http.Response('[]', 200);
        }),
      );
      expect(await api.list('employees', 'test-token'), isEmpty);
    },
  );
  test('delete accepts 204 and escapes id as one segment', () async {
    final api = TeamApi(
      client: MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.pathSegments, ['api', 'employees', 'id/with/slash']);
        return http.Response('', 204);
      }),
    );
    await api.delete('employees', 'id/with/slash', 'test-token');
  });
  test('malformed success becomes safe format failure', () async {
    final api = TeamApi(
      client: MockClient(
        (_) async => http.Response('<html>gateway</html>', 200),
      ),
    );
    expect(() => api.login('u', 'p'), throwsA(isA<ApiFailure>()));
  });
  test(
    'unauthorized is distinguished without exposing response secrets',
    () async {
      final api = TeamApi(
        client: MockClient(
          (_) async => http.Response('private-server-content', 401),
        ),
      );
      try {
        await api.me('token');
        fail('must reject');
      } on ApiFailure catch (error) {
        expect(error.status, 401);
        expect(error.toString(), isNot(contains('private-server-content')));
      }
    },
  );
  test('write timeout performs no automatic retry', () async {
    var calls = 0;
    final api = TeamApi(
      timeout: const Duration(milliseconds: 5),
      client: MockClient((_) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return http.Response('{}', 200);
      }),
    );
    await expectLater(api.login('u', 'p'), throwsA(isA<ApiFailure>()));
    expect(calls, 1);
  });
  test(
    'unexpected resource is rejected before transmitting credentials',
    () async {
      var calls = 0;
      final api = TeamApi(
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      await expectLater(
        api.list('https://other.test', 'token'),
        throwsArgumentError,
      );
      expect(calls, 0);
    },
  );
  final contracts =
      <
        (
          String,
          String,
          String,
          Map<String, Object?>?,
          Future<Object?> Function(TeamApi),
        )
      >[
        (
          'register',
          'POST',
          '/api/auth/register',
          {
            'name': 'Demo',
            'email': 'demo@example.test',
            'username': 'demo',
            'password': ' secret ',
          },
          (api) => api.register(
            name: 'Demo',
            email: 'demo@example.test',
            username: 'demo',
            password: ' secret ',
          ),
        ),
        (
          'verify email',
          'POST',
          '/api/auth/verify-email',
          {'challengeId': 'challenge', 'code': '123456'},
          (api) => api.verifyEmail('challenge', '123456'),
        ),
        (
          'logout',
          'POST',
          '/api/auth/logout',
          {'refreshToken': 'refresh-test'},
          (api) => api.logout('refresh-test'),
        ),
        (
          'create employee',
          'POST',
          '/api/employees',
          {'name': 'New person'},
          (api) =>
              api.create('employees', {'name': 'New person'}, 'access-test'),
        ),
        (
          'edit shift',
          'PATCH',
          '/api/shifts/shift-id',
          {'startMinute': 480},
          (api) => api.update('shifts', 'shift-id', {
            'startMinute': 480,
          }, 'access-test'),
        ),
        (
          'assign shift',
          'PUT',
          '/api/employees/person-id/shift',
          {'shiftId': null},
          (api) => api.assignShift('person-id', null, 'access-test'),
        ),
        (
          'review request',
          'POST',
          '/api/requests/request-id/review',
          {'approve': false, 'note': 'Review', 'version': 2},
          (api) => api.reviewRequest(
            'request-id',
            approve: false,
            note: 'Review',
            version: 2,
            token: 'access-test',
          ),
        ),
        (
          'read office',
          'GET',
          '/api/office',
          null,
          (api) => api.office('access-test'),
        ),
        (
          'update office',
          'PUT',
          '/api/office',
          {'radius': 100},
          (api) => api.updateOffice({'radius': 100}, 'access-test'),
        ),
        (
          'office QR',
          'POST',
          '/api/office/qr',
          null,
          (api) => api.officeQr('access-test'),
        ),
        (
          'check in',
          'POST',
          '/api/attendance/check-in',
          {'qr': 'qr-fixture', 'idempotencyKey': 'one-event'},
          (api) => api.punch(
            checkOut: false,
            payload: {'qr': 'qr-fixture', 'idempotencyKey': 'one-event'},
            token: 'access-test',
          ),
        ),
        (
          'check out',
          'POST',
          '/api/attendance/check-out',
          {'idempotencyKey': 'out-event'},
          (api) => api.punch(
            checkOut: true,
            payload: {'idempotencyKey': 'out-event'},
            token: 'access-test',
          ),
        ),
      ];
  for (final entry in contracts) {
    test('request contract: ${entry.$1}', () async {
      final api = TeamApi(
        client: MockClient((request) async {
          expect(request.method, entry.$2);
          expect(request.url.path, entry.$3);
          if (entry.$4 == null) {
            expect(request.body, isEmpty);
          } else {
            expect(jsonDecode(request.body), entry.$4);
          }
          if (!entry.$3.startsWith('/api/auth/')) {
            expect(request.headers['Authorization'], 'Bearer access-test');
          }
          return http.Response('{}', 200);
        }),
      );
      await entry.$5(api);
    });
  }
  test('attendance filters are encoded and sent to team route', () async {
    final api = TeamApi(
      client: MockClient((request) async {
        expect(request.url.path, '/api/attendance');
        expect(request.url.queryParameters, {
          'from': '2026-10-22',
          'to': '2026-10-23',
          'employeeId': 'employee-id',
          'page': '2',
          'pageSize': '25',
        });
        return http.Response('[]', 200);
      }),
    );
    await api.attendance(
      'access-test',
      from: '2026-10-22',
      to: '2026-10-23',
      employeeId: 'employee-id',
      page: 2,
      pageSize: 25,
    );
  });
  test('rejects insecure base URL before any request', () {
    expect(
      () => TeamApi(
        client: MockClient((_) async => http.Response('{}', 200)),
        baseUrl: Uri.parse('http://insecure.test'),
      ),
      throwsArgumentError,
    );
  });
  for (final status in [500, 502]) {
    test(
      'write HTTP $status remains uncertain for safe idempotency retry',
      () async {
        final api = TeamApi(
          client: MockClient((_) async => http.Response('{}', status)),
        );
        try {
          await api.punch(
            checkOut: false,
            payload: {'idempotencyKey': 'same'},
            token: 'token',
          );
          fail('must fail');
        } on ApiFailure catch (e) {
          expect(e.outcomeUnknown, true);
        }
      },
    );
  }
  test(
    'malformed successful write cannot safely become a new operation',
    () async {
      final api = TeamApi(
        client: MockClient((_) async => http.Response('not-json', 200)),
      );
      try {
        await api.punch(
          checkOut: false,
          payload: {'idempotencyKey': 'same'},
          token: 'token',
        );
        fail('must fail');
      } on ApiFailure catch (e) {
        expect(e.outcomeUnknown, true);
      }
    },
  );
}
