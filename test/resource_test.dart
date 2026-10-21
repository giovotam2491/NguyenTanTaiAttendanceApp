import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nguyen_tan_tai_attendance_app/api/team_api.dart';
import 'package:nguyen_tan_tai_attendance_app/auth/auth_session.dart';
import 'package:nguyen_tan_tai_attendance_app/resources/resource_page.dart';

import 'fixtures.dart';

Future<void> openResources(
  WidgetTester t,
  String resource,
  Future<http.Response> Function(http.Request) handler,
) async {
  await t.pumpWidget(
    MaterialApp(
      home: ResourcePage(
        api: TeamApi(client: MockClient(handler)),
        session: AuthSession.fromJson(verifiedResponse()),
        resource: resource,
        title: 'Records',
        onUnauthorized: () {},
      ),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> tap(WidgetTester t, String label) async {
  final f = find.text(label).last;
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('shift create converts time to minutes and sends API request', (
    t,
  ) async {
    var created = false;
    await openResources(t, 'shifts', (r) async {
      if (r.method == 'GET') return http.Response('[]', 200);
      expect(r.method, 'POST');
      expect(r.url.path, '/api/shifts');
      expect(jsonDecode(r.body), {
        'name': 'Day',
        'startMinute': 480,
        'endMinute': 1020,
        'grace': 5,
      });
      created = true;
      return http.Response('{}', 200);
    });
    await t.tap(find.byTooltip('Thêm mới'));
    await t.pumpAndSettle();
    for (final e in [(0, 'Day'), (1, '08:00'), (2, '17:00'), (3, '5')]) {
      await t.enterText(find.byType(TextFormField).at(e.$1), e.$2);
    }
    await tap(t, 'Lưu');
    expect(created, true);
  });
  testWidgets(
    'cancel delete does not write; confirmation deletes selected id',
    (t) async {
      var deletes = 0;
      await openResources(t, 'employees', (r) async {
        if (r.method == 'DELETE') {
          deletes++;
          expect(r.url.path, '/api/employees/person-id');
          return http.Response('', 204);
        }
        return http.Response('[{"id":"person-id","name":"Demo"}]', 200);
      });
      await t.tap(find.byTooltip('Xóa'));
      await t.pumpAndSettle();
      await tap(t, 'Hủy');
      expect(deletes, 0);
      await t.tap(find.byTooltip('Xóa'));
      await t.pumpAndSettle();
      await tap(t, 'Xóa dữ liệu');
      expect(deletes, 1);
    },
  );
  testWidgets('employee edit never prefills or sends blank password', (
    t,
  ) async {
    Map? payload;
    await openResources(t, 'employees', (r) async {
      if (r.method == 'PATCH') {
        payload = jsonDecode(r.body) as Map;
        return http.Response('{}', 200);
      }
      return http.Response(
        '[{"id":"person-id","name":"Demo","email":"demo@example.test","username":"demo","role":"employee","active":true}]',
        200,
      );
    });
    await t.tap(find.byTooltip('Sửa'));
    await t.pumpAndSettle();
    await tap(t, 'Lưu');
    expect(payload, isNotNull);
    expect(payload!.containsKey('password'), false);
  });
  testWidgets('server forbids mutation without hiding the error', (t) async {
    await openResources(
      t,
      'shifts',
      (r) async => r.method == 'GET'
          ? http.Response('[]', 200)
          : http.Response('{}', 403),
    );
    await t.tap(find.byTooltip('Thêm mới'));
    await t.pumpAndSettle();
    for (final e in [(0, 'Day'), (1, '08:00'), (2, '17:00'), (3, '0')]) {
      await t.enterText(find.byType(TextFormField).at(e.$1), e.$2);
    }
    await tap(t, 'Lưu');
    expect(find.textContaining('không có quyền'), findsOneWidget);
    expect(find.text('Lưu'), findsOneWidget);
  });
}
