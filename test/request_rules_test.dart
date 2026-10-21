import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nguyen_tan_tai_attendance_app/api/team_api.dart';
import 'package:nguyen_tan_tai_attendance_app/auth/auth_session.dart';
import 'package:nguyen_tan_tai_attendance_app/resources/resource_page.dart';
import 'package:nguyen_tan_tai_attendance_app/resources/record_editor.dart';

import 'fixtures.dart';

Future<void> tap(WidgetTester t, String label) async {
  final f = find.text(label).last;
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  for (final role in ['employee', 'admin']) {
    for (final own in [true, false]) {
      for (final status in ['pending', 'approved', 'rejected']) {
        testWidgets('$role own=$own status=$status controls request actions', (
          t,
        ) async {
          await t.pumpWidget(
            MaterialApp(
              home: ResourcePage(
                resource: 'requests',
                title: 'Requests',
                session: AuthSession.fromJson(verifiedResponse(role: role)),
                onUnauthorized: () {},
                api: TeamApi(
                  client: MockClient(
                    (r) async => http.Response(
                      jsonEncode([
                        {
                          'id': 'request',
                          'employeeId': own ? 'test-user' : 'other',
                          'employeeName': 'Demo',
                          'type': 'Nghỉ phép',
                          'reason': 'Leave request',
                          'status': status,
                          'version': 7,
                          'reviewerNote': 'Reviewed note',
                        },
                      ]),
                      200,
                      headers: {
                        'content-type': 'application/json; charset=utf-8',
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          final editable = own && status == 'pending';
          final review = role == 'admin' && !own && status == 'pending';
          expect(
            find.byTooltip('Sửa'),
            editable ? findsOneWidget : findsNothing,
          );
          expect(
            find.byTooltip('Xóa'),
            editable ? findsOneWidget : findsNothing,
          );
          expect(
            find.byTooltip('Duyệt'),
            review ? findsOneWidget : findsNothing,
          );
          expect(
            find.byTooltip('Từ chối'),
            review ? findsOneWidget : findsNothing,
          );
          expect(find.textContaining('Reviewed note'), findsOneWidget);
        });
      }
    }
  }
  testWidgets('request picker offers exactly the two server types', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: RecordEditor(resource: 'requests', onSave: (p) async {}),
      ),
    );
    await t.tap(find.byType(DropdownButtonFormField<String>));
    await t.pumpAndSettle();
    expect(find.text('Giải trình chấm công'), findsOneWidget);
    expect(find.text('Nhân viên'), findsNothing);
    expect(find.text('Quản trị'), findsNothing);
  });

  testWidgets('review requires a note and preserves concurrency version', (
    t,
  ) async {
    Map? body;
    await t.pumpWidget(
      MaterialApp(
        home: ResourcePage(
          resource: 'requests',
          title: 'Requests',
          session: AuthSession.fromJson(verifiedResponse()),
          onUnauthorized: () {},
          api: TeamApi(
            client: MockClient((r) async {
              if (r.method == 'POST') {
                body = jsonDecode(r.body) as Map;
                return http.Response('{}', 200);
              }
              return http.Response(
                '[{"id":"request","employeeId":"other","status":"pending","version":7}]',
                200,
              );
            }),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Duyệt'));
    await t.pumpAndSettle();
    await tap(t, 'Xác nhận');
    expect(body, isNull);
    expect(find.byType(AlertDialog), findsOneWidget);
    await t.enterText(find.byType(TextFormField), '  Đồng ý nghỉ phép  ');
    await tap(t, 'Xác nhận');
    expect(body, {'approve': true, 'note': 'Đồng ý nghỉ phép', 'version': 7});
  });
  testWidgets('request type dropdown and minimum reason guard server call', (
    t,
  ) async {
    var saves = 0;
    await t.pumpWidget(
      MaterialApp(
        home: RecordEditor(
          resource: 'requests',
          onSave: (p) async {
            saves++;
          },
        ),
      ),
    );
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    await t.enterText(find.widgetWithText(TextFormField, 'Lý do'), 'short');
    await t.enterText(
      find.widgetWithText(TextFormField, 'Từ ngày (YYYY-MM-DD)'),
      '2026-10-22',
    );
    await t.enterText(
      find.widgetWithText(TextFormField, 'Đến ngày (YYYY-MM-DD)'),
      '2026-10-22',
    );
    await tap(t, 'Lưu');
    expect(saves, 0);
    expect(find.textContaining('10 ký tự'), findsOneWidget);
    await t.enterText(
      find.widgetWithText(TextFormField, 'Lý do'),
      'Lý do nghỉ phép hợp lệ',
    );
    await tap(t, 'Lưu');
    expect(saves, 1);
  });
  for (final (resource, key, values) in [
    ('shifts', 'grace', [0, 60, 61]),
    ('office', 'radius', [20, 5000, 19, 5001]),
  ]) {
    for (final value in values) {
      testWidgets('$resource $key=$value follows server range', (t) async {
        var saves = 0;
        final initial = resource == 'shifts'
            ? <String, dynamic>{
                'name': 'Night',
                'startMinute': 1320,
                'endMinute': 360,
                'grace': value,
              }
            : <String, dynamic>{
                'name': 'Office',
                'latitude': 10,
                'longitude': 106,
                'radius': value,
              };
        await t.pumpWidget(
          MaterialApp(
            home: RecordEditor(
              resource: resource,
              initial: initial,
              onSave: (p) async {
                saves++;
              },
            ),
          ),
        );
        await tap(t, 'Lưu');
        expect(
          saves,
          (key == 'grace' ? value <= 60 : value >= 20 && value <= 5000) ? 1 : 0,
        );
      });
    }
  }
  for (final (username, password) in [
    ('ab', '12345678'),
    ('bad name', '12345678'),
    ('x' * 41, '12345678'),
    ('valid', 'short'),
  ]) {
    testWidgets(
      'employee invalid credentials rejected: $username/${password.length}',
      (t) async {
        var saves = 0;
        await t.pumpWidget(
          MaterialApp(
            home: RecordEditor(
              resource: 'employees',
              initial: {
                'name': 'Demo',
                'email': 'demo@example.test',
                'username': username,
                'role': 'employee',
              },
              onSave: (p) async {
                saves++;
              },
            ),
          ),
        );
        await t.enterText(find.byType(TextFormField).at(3), password);
        await tap(t, 'Lưu');
        expect(saves, 0);
      },
    );
  }
}
