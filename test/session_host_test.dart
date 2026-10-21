import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nguyen_tan_tai_attendance_app/api/team_api.dart';
import 'package:nguyen_tan_tai_attendance_app/auth/session_host.dart';

import 'fixtures.dart';

Future<void> tapLabel(WidgetTester t, String label) async {
  final f = find.text(label).last;
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> signIn(WidgetTester t) async {
  await t.enterText(find.byType(TextFormField).at(0), 'worker');
  await t.enterText(find.byType(TextFormField).at(1), 'password');
  await tapLabel(t, 'Đăng nhập');
  await t.enterText(find.byType(TextFormField), '123456');
  await tapLabel(t, 'Xác minh');
}

void main() {
  testWidgets(
    'verified server role opens dashboard and logout clears UI before server responds',
    (t) async {
      final logout = Completer<http.Response>();
      await t.pumpWidget(
        MaterialApp(
          home: SessionHost(
            api: TeamApi(
              client: MockClient((r) async {
                if (r.url.path.endsWith('/login')) {
                  return http.Response('{"challengeId":"id"}', 200);
                }
                if (r.url.path.endsWith('/logout')) {
                  expect(jsonDecode(r.body), {'refreshToken': 'test-refresh'});
                  return logout.future;
                }
                return http.Response(jsonEncode(verifiedResponse()), 200);
              }),
            ),
          ),
        ),
      );
      await signIn(t);
      expect(find.text('Quản trị'), findsOneWidget);
      await t.tap(find.byTooltip('Đăng xuất'));
      await t.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Đăng nhập'), findsOneWidget);
      logout.complete(http.Response('', 204));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('protected 401 closes opened routes and returns to login', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: SessionHost(
          api: TeamApi(
            client: MockClient((r) async {
              if (r.url.path.endsWith('/login')) {
                return http.Response('{"challengeId":"id"}', 200);
              }
              if (r.url.path.endsWith('/verify-otp')) {
                return http.Response(jsonEncode(verifiedResponse()), 200);
              }
              return http.Response('{}', 401);
            }),
          ),
        ),
      ),
    );
    await signIn(t);
    await tapLabel(t, 'Quản lý nhân viên');
    expect(find.widgetWithText(FilledButton, 'Đăng nhập'), findsOneWidget);
    expect(find.text('Quản lý nhân viên'), findsNothing);
  });
}
