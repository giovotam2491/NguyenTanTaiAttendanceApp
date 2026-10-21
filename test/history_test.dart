import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nguyen_tan_tai_attendance_app/api/team_api.dart';
import 'package:nguyen_tan_tai_attendance_app/auth/auth_session.dart';
import 'package:nguyen_tan_tai_attendance_app/attendance/history_page.dart';

import 'fixtures.dart';

void main() {
  testWidgets('history renders DTO times in Vietnam and uses paging metadata', (
    t,
  ) async {
    final pages = <String?>[];
    await t.pumpWidget(
      MaterialApp(
        home: HistoryPage(
          session: AuthSession.fromJson(verifiedResponse()),
          onUnauthorized: () {},
          api: TeamApi(
            client: MockClient((r) async {
              final page = int.parse(r.url.queryParameters['page']!);
              pages.add('$page');
              return http.Response(
                jsonEncode({
                  'total': 2,
                  'page': page,
                  'pageSize': 1,
                  'items': [
                    {
                      'id': 'record',
                      'employeeName': 'Demo',
                      'shiftName': 'Night',
                      'workDate': '2026-10-22',
                      'checkIn': '2026-10-21T23:30:00Z',
                      'checkOut': null,
                      'scheduledEnd': '2026-10-22T06:00:00Z',
                      'lateMinutes': 3,
                    },
                  ],
                }),
                200,
              );
            }),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Vào ca: 22/10/2026 06:30'), findsOneWidget);
    expect(find.text('Kết thúc dự kiến: 22/10/2026 13:00'), findsOneWidget);
    expect(find.text('Trễ: 3 phút'), findsOneWidget);
    await t.ensureVisible(find.text('Trang sau'));
    expect(
      t
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Trang sau'),
          )
          .onPressed,
      isNotNull,
    );
    await t.tap(find.text('Trang sau'));
    await t.pumpAndSettle();
    expect(pages, ['1', '2']);
    await t.ensureVisible(find.text('Trang sau'));
    expect(
      t
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Trang sau'),
          )
          .onPressed,
      isNull,
    );
  });
  testWidgets('malformed attendance envelope produces retry error', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: HistoryPage(
          session: AuthSession.fromJson(verifiedResponse()),
          onUnauthorized: () {},
          api: TeamApi(
            client: MockClient((r) async => http.Response('{"items":[]}', 200)),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Thử lại'), findsOneWidget);
  });
}
