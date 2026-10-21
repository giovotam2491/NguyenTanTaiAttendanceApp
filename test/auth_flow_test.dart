import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nguyen_tan_tai_attendance_app/api/team_api.dart';
import 'package:nguyen_tan_tai_attendance_app/auth/auth_form.dart';
import 'package:nguyen_tan_tai_attendance_app/ui/app_theme.dart';

import 'fixtures.dart';

Future<void> openForm(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) handler,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: AuthForm(api: TeamApi(client: MockClient(handler))),
    ),
  );
}

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text).last;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> login(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), ' worker ');
  await tester.enterText(find.byType(TextFormField).at(1), ' secret ');
  await tapText(tester, 'Đăng nhập');
}

void main() {
  testWidgets('registration validates username and password before HTTP', (
    tester,
  ) async {
    for (final values in [('bad name', '12345678'), ('valid', 'short')]) {
      var requests = 0;
      await tester.pumpWidget(const SizedBox());
      await openForm(tester, (r) async {
        requests++;
        return http.Response('{"challengeId":"id"}', 200);
      });
      await tapText(tester, 'Tạo tài khoản');
      for (final e in [
        (0, 'Demo'),
        (1, 'demo@example.test'),
        (2, values.$1),
        (3, values.$2),
      ]) {
        await tester.enterText(find.byType(TextFormField).at(e.$1), e.$2);
      }
      await tapText(tester, 'Đăng ký');
      expect(requests, 0);
    }
  });

  testWidgets(
    'login preserves user payload and opens OTP with returned challenge',
    (tester) async {
      await openForm(tester, (request) async {
        expect(request.url.path, '/api/auth/login');
        expect(jsonDecode(request.body), {
          'username': 'worker',
          'password': ' secret ',
        });
        return http.Response('{"challengeId":"login-challenge"}', 200);
      });
      await login(tester);
      expect(find.text('Mã xác minh'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
    },
  );
  testWidgets('OTP posts current challenge and pasted code once', (
    tester,
  ) async {
    var verifyCalls = 0;
    await openForm(tester, (request) async {
      if (request.url.path.endsWith('/login')) {
        return http.Response('{"challengeId":"current"}', 200);
      }
      verifyCalls++;
      expect(request.url.path, '/api/auth/verify-otp');
      expect(jsonDecode(request.body), {
        'challengeId': 'current',
        'code': '012345',
      });
      return http.Response(jsonEncode(verifiedResponse()), 200);
    });
    await login(tester);
    await tester.enterText(find.byType(TextFormField), '012345');
    await tapText(tester, 'Xác minh');
    expect(verifyCalls, 1);
    expect(find.text('Đã xác minh mã đăng nhập.'), findsOneWidget);
  });
  testWidgets('wrong OTP retains challenge and allows correction', (
    tester,
  ) async {
    var attempts = 0;
    await openForm(tester, (request) async {
      if (request.url.path.endsWith('/login')) {
        return http.Response('{"challengeId":"current"}', 200);
      }
      attempts++;
      return attempts == 1
          ? http.Response('{}', 400)
          : http.Response(jsonEncode(verifiedResponse()), 200);
    });
    await login(tester);
    await tester.enterText(find.byType(TextFormField), 'bad-code');
    await tapText(tester, 'Xác minh');
    expect(find.text('Mã xác minh'), findsOneWidget);
    expect(find.textContaining('Dữ liệu chưa được'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'corrected');
    await tapText(tester, 'Xác minh');
    expect(attempts, 2);
  });
  testWidgets(
    'registration sends real request then verifies email before returning to login',
    (tester) async {
      final paths = <String>[];
      await openForm(tester, (request) async {
        paths.add(request.url.path);
        if (paths.length == 1) {
          expect(jsonDecode(request.body), {
            'name': 'Demo',
            'email': 'demo@example.test',
            'username': 'worker',
            'password': ' secret ',
          });
          return http.Response('{"challengeId":"email-challenge"}', 200);
        }
        expect(jsonDecode(request.body), {
          'challengeId': 'email-challenge',
          'code': 'email-code',
        });
        return http.Response('', 204);
      });
      await tapText(tester, 'Tạo tài khoản');
      for (final entry in [
        (0, 'Demo'),
        (1, 'demo@example.test'),
        (2, 'worker'),
        (3, ' secret '),
      ]) {
        await tester.enterText(
          find.byType(TextFormField).at(entry.$1),
          entry.$2,
        );
      }
      await tapText(tester, 'Đăng ký');
      expect(find.text('Xác minh email'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'email-code');
      await tapText(tester, 'Xác minh');
      expect(paths, ['/api/auth/register', '/api/auth/verify-email']);
      expect(find.widgetWithText(FilledButton, 'Đăng nhập'), findsOneWidget);
    },
  );
  testWidgets('malformed challenge cannot open OTP', (tester) async {
    await openForm(
      tester,
      (_) async => http.Response('{"challengeId":" "}', 200),
    );
    await login(tester);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.textContaining('challengeId'), findsOneWidget);
  });
  testWidgets(
    'late OTP response after leaving form does not update disposed widget',
    (tester) async {
      final pending = Completer<http.Response>();
      await openForm(tester, (request) async {
        if (request.url.path.endsWith('/login')) {
          return http.Response('{"challengeId":"current"}', 200);
        }
        return pending.future;
      });
      await login(tester);
      await tester.enterText(find.byType(TextFormField), 'code');
      await tester.ensureVisible(find.text('Xác minh'));
      await tester.tap(find.text('Xác minh'));
      await tester.pump();
      await tester.pumpWidget(
        MaterialApp(key: UniqueKey(), home: const Text('Left form')),
      );
      pending.complete(http.Response('{}', 200));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Left form'), findsOneWidget);
    },
  );
}
