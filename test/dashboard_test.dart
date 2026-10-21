import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nguyen_tan_tai_attendance_app/api/team_api.dart';
import 'package:nguyen_tan_tai_attendance_app/auth/auth_session.dart';
import 'package:nguyen_tan_tai_attendance_app/home/account_home.dart';

import 'fixtures.dart';

void main() {
  for (final role in ['admin', 'employee', 'guest']) {
    testWidgets('dashboard exposes only allowed destinations for $role', (
      tester,
    ) async {
      final session = AuthSession.fromJson(verifiedResponse(role: role));
      final api = TeamApi(
        client: MockClient((_) async => http.Response('[]', 200)),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AccountHome(
            api: api,
            session: session,
            onSignOut: () async {},
            onUnauthorized: () {},
          ),
        ),
      );
      expect(
        find.text('Quản lý nhân viên'),
        role == 'admin' ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Quản lý ca làm'),
        role == 'admin' ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Yêu cầu của tôi'),
        role == 'employee' ? findsOneWidget : findsNothing,
      );
      if (role == 'guest') {
        expect(find.textContaining('chưa có trang'), findsOneWidget);
      }
    });
  }
  testWidgets('admin opens employee list and sends current bearer token', (
    tester,
  ) async {
    final session = AuthSession.fromJson(verifiedResponse());
    await tester.pumpWidget(
      MaterialApp(
        home: AccountHome(
          session: session,
          api: TeamApi(
            client: MockClient((request) async {
              expect(request.url.path, '/api/employees');
              expect(request.headers['Authorization'], 'Bearer test-access');
              return http.Response(
                '[{"id":"person-id","name":"Person A"}]',
                200,
              );
            }),
          ),
          onSignOut: () async {},
          onUnauthorized: () {},
        ),
      ),
    );
    await tester.tap(find.text('Quản lý nhân viên'));
    await tester.pumpAndSettle();
    expect(find.text('Person A'), findsOneWidget);
    expect(find.byTooltip('Thêm mới'), findsOneWidget);
  });
}
