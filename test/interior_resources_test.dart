import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nguyen_tan_tai_attendance_app/api/team_api.dart';
import 'package:nguyen_tan_tai_attendance_app/auth/auth_session.dart';
import 'package:nguyen_tan_tai_attendance_app/resources/resource_page.dart';
import 'package:nguyen_tan_tai_attendance_app/attendance/punch_page.dart';

import 'fixtures.dart';

void main() {
  testWidgets('search filters the full loaded employee list', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: ResourcePage(
          api: TeamApi(
            client: MockClient(
              (_) async => http.Response(
                '[{"id":"a","name":"An"},{"id":"b","name":"Bao"}]',
                200,
              ),
            ),
          ),
          session: AuthSession.fromJson(verifiedResponse()),
          resource: 'employees',
          title: 'People',
          onUnauthorized: () {},
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'bao');
    await t.pumpAndSettle();
    expect(find.text('Bao'), findsOneWidget);
    expect(find.text('An'), findsNothing);
  });
  testWidgets('review queue excludes own and completed requests', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: ResourcePage(
          api: TeamApi(
            client: MockClient(
              (_) async => http.Response(
                jsonEncode([
                  {
                    'id': 'a',
                    'employeeId': 'other',
                    'reason': 'Pending other',
                    'status': 'pending',
                  },
                  {
                    'id': 'b',
                    'employeeId': 'test-user',
                    'reason': 'Own request',
                    'status': 'pending',
                  },
                  {
                    'id': 'c',
                    'employeeId': 'other',
                    'reason': 'Done request',
                    'status': 'approved',
                  },
                ]),
                200,
              ),
            ),
          ),
          session: AuthSession.fromJson(verifiedResponse()),
          resource: 'requests',
          title: 'Review',
          reviewOnly: true,
          onUnauthorized: () {},
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Pending other'), findsOneWidget);
    expect(find.text('Own request'), findsNothing);
    expect(find.text('Done request'), findsNothing);
  });
  testWidgets('employee create selects a shift by server name', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: ResourcePage(
          api: TeamApi(
            client: MockClient(
              (r) async => http.Response(
                r.url.path.endsWith('/shifts')
                    ? '[{"id":"00000000-0000-0000-0000-000000000001","name":"Night shift"}]'
                    : '[]',
                200,
              ),
            ),
          ),
          session: AuthSession.fromJson(verifiedResponse()),
          resource: 'employees',
          title: 'People',
          onUnauthorized: () {},
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Thêm mới'));
    await t.pumpAndSettle();
    expect(find.text('ID ca làm (không bắt buộc)'), findsNothing);
    await t.ensureVisible(find.text('Chưa phân ca'));
    await t.tap(find.text('Chưa phân ca'));
    await t.pumpAndSettle();
    expect(find.text('Night shift'), findsOneWidget);
  });
  testWidgets(
    'initial checkout intent and retained operation take precedence',
    (t) async {
      final session = AuthSession.fromJson(verifiedResponse(role: 'employee'));
      Future<void> render() => t.pumpWidget(
        MaterialApp(
          home: PunchPage(
            key: UniqueKey(),
            api: TeamApi(
              client: MockClient((_) async => http.Response('{}', 200)),
            ),
            session: session,
            onUnauthorized: () {},
            initialCheckOut: true,
          ),
        ),
      );
      await render();
      await t.pumpAndSettle();
      expect(find.text('Chấm công ra ca'), findsOneWidget);
      session.pendingPunch = {'qr': 'pending'};
      session.pendingCheckOut = false;
      await render();
      await t.pumpAndSettle();
      expect(find.text('Gửi lại cùng thao tác'), findsOneWidget);
      final field = t.widget<DropdownButtonFormField<bool>>(
        find.byType(DropdownButtonFormField<bool>),
      );
      expect(field.initialValue, false);
    },
  );
}
