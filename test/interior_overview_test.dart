import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nguyen_tan_tai_attendance_app/api/team_api.dart';
import 'package:nguyen_tan_tai_attendance_app/auth/auth_session.dart';
import 'package:nguyen_tan_tai_attendance_app/home/account_home.dart';

import 'fixtures.dart';

void main() {
  for (final state in ['open', 'closed', 'empty', 'failed']) {
    testWidgets('employee home handles latest overnight attendance: $state', (
      t,
    ) async {
      final response = verifiedResponse(role: 'employee');
      (response['user'] as Map)['shiftId'] = 'night';
      final calls = <Uri>[];
      await t.pumpWidget(
        MaterialApp(
          home: AccountHome(
            session: AuthSession.fromJson(response),
            onSignOut: () async {},
            onUnauthorized: () {},
            api: TeamApi(
              client: MockClient((r) async {
                calls.add(r.url);
                if (r.url.path == '/api/me') {
                  return http.Response(jsonEncode(response['user']), 200);
                }
                if (r.url.path == '/api/shifts') {
                  return http.Response(
                    '[{"id":"night","name":"Ca đêm","startMinute":1320,"endMinute":360}]',
                    200,
                    headers: {
                      'content-type': 'application/json; charset=utf-8',
                    },
                  );
                }
                if (r.url.path.endsWith('/attendance')) {
                  if (state == 'failed') return http.Response('{}', 503);
                  return http.Response(
                    jsonEncode({
                      'total': state == 'empty' ? 0 : 1,
                      'page': 1,
                      'pageSize': 1,
                      'items': state == 'empty'
                          ? []
                          : [
                              {
                                'id': 'a',
                                'employeeId': 'test-user',
                                'shiftName': 'Ca đêm',
                                'workDate': '2026-10-21',
                                'checkIn': '2026-10-21T15:00:00Z',
                                'checkOut': state == 'closed'
                                    ? '2026-10-21T23:00:00Z'
                                    : null,
                              },
                            ],
                    }),
                    200,
                    headers: {
                      'content-type': 'application/json; charset=utf-8',
                    },
                  );
                }
                return http.Response('[]', 200);
              }),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Ca đêm'), findsWidgets);
      expect(
        find.text(
          state == 'open'
              ? 'Chấm công ra ca'
              : state == 'failed'
              ? 'Chưa tải được ca gần nhất'
              : 'Chấm công vào ca',
        ),
        findsOneWidget,
      );
      final attendance = calls
          .where((u) => u.path.endsWith('/attendance'))
          .single;
      expect(attendance.queryParameters['pageSize'], '1');
      expect(attendance.queryParameters.containsKey('from'), isFalse);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('tabs use bottom navigation and back returns to today', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: AccountHome(
          session: AuthSession.fromJson(verifiedResponse(role: 'employee')),
          api: TeamApi(
            client: MockClient((_) async => http.Response('[]', 200)),
          ),
          onSignOut: () async {},
          onUnauthorized: () {},
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    await t.tap(find.text('Đơn').last);
    await t.pumpAndSettle();
    expect(find.text('Yêu cầu của tôi'), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.textContaining('Chào'), findsOneWidget);
  });
  testWidgets('inconsistent latest page cannot enable a new checkin', (
    t,
  ) async {
    final response = verifiedResponse(role: 'employee');
    (response['user'] as Map)['shiftId'] = 's';
    final client = MockClient((request) async {
      final data = switch (request.url.path) {
        '/api/me' => response['user'],
        '/api/shifts' => [
          {'id': 's', 'name': 'Day'},
        ],
        '/api/attendance' => {
          'total': 1,
          'page': 1,
          'pageSize': 1,
          'items': [],
        },
        _ => [],
      };
      return http.Response(jsonEncode(data), 200);
    });
    await t.pumpWidget(
      MaterialApp(
        home: AccountHome(
          session: AuthSession.fromJson(response),
          onSignOut: () async {},
          onUnauthorized: () {},
          api: TeamApi(client: client),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Chưa tải được ca gần nhất'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Chấm công vào ca'), findsNothing);
  });
  testWidgets('changed role invalidates the employee session', (t) async {
    var invalid = 0;
    final response = verifiedResponse(role: 'employee');
    final client = MockClient((request) async {
      final data = switch (request.url.path) {
        '/api/me' => verifiedResponse()['user'],
        '/api/attendance' => {
          'total': 0,
          'page': 1,
          'pageSize': 1,
          'items': [],
        },
        _ => [],
      };
      return http.Response(jsonEncode(data), 200);
    });
    await t.pumpWidget(
      MaterialApp(
        home: AccountHome(
          session: AuthSession.fromJson(response),
          onSignOut: () async {},
          onUnauthorized: () => invalid++,
          api: TeamApi(client: client),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(invalid, 1);
    final button = t.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Chấm công vào ca'),
    );
    expect(button.onPressed, isNull);
  });
  testWidgets('late overview responses after disposal do not update UI', (
    t,
  ) async {
    final response = Completer<http.Response>();
    await t.pumpWidget(
      MaterialApp(
        home: AccountHome(
          session: AuthSession.fromJson(verifiedResponse()),
          onSignOut: () async {},
          onUnauthorized: () {},
          api: TeamApi(client: MockClient((_) => response.future)),
        ),
      ),
    );
    await t.pump();
    await t.pumpWidget(const MaterialApp(home: Text('Left')));
    response.complete(http.Response('[]', 200));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
