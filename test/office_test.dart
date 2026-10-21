import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:nguyen_tan_tai_attendance_app/api/team_api.dart';
import 'package:nguyen_tan_tai_attendance_app/auth/auth_session.dart';
import 'package:nguyen_tan_tai_attendance_app/home/office_page.dart';

import 'fixtures.dart';

import 'package:nguyen_tan_tai_attendance_app/resources/record_editor.dart';

void main() {
  testWidgets('office renders server settings and QR from server payload', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: OfficePage(
          session: AuthSession.fromJson(verifiedResponse()),
          onUnauthorized: () {},
          api: TeamApi(
            client: MockClient((r) async {
              if (r.method == 'POST') {
                expect(r.url.path, '/api/office/qr');
                return http.Response(
                  '{"code":"server-qr-fixture","expiresAt":"2099-01-01T00:00:00Z"}',
                  200,
                );
              }
              return http.Response(
                '{"name":"Office A","latitude":10,"longitude":106,"radius":100}',
                200,
              );
            }),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Office A'), findsOneWidget);
    await t.ensureVisible(find.text('Lấy QR chấm công'));
    await t.tap(find.text('Lấy QR chấm công'));
    await t.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(
      () => decodeOfficeQr({
        'code': 'server-qr-fixture',
        'expiresAt': '2099-01-01T00:00:00Z',
      }),
      returnsNormally,
    );
  });
  testWidgets('server QR disappears when expiry timer fires', (t) async {
    final expires = DateTime.now().toUtc().add(const Duration(seconds: 2));
    await t.pumpWidget(
      MaterialApp(
        home: OfficePage(
          session: AuthSession.fromJson(verifiedResponse()),
          onUnauthorized: () {},
          api: TeamApi(
            client: MockClient(
              (r) async => http.Response(
                r.method == 'POST'
                    ? '{"code":"fixture","expiresAt":"${expires.toIso8601String()}"}'
                    : '{"name":"Office","configured":true}',
                200,
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Lấy QR chấm công'));
    await t.tap(find.text('Lấy QR chấm công'));
    await t.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
    expect(find.byType(QrImageView), findsNothing);
    expect(find.textContaining('QR đã hết hạn'), findsOneWidget);
  });
  testWidgets('expired QR and missing expiry cannot be rendered', (t) async {
    for (final response in [
      '{"code":"fixture","expiresAt":"2000-01-01T00:00:00Z"}',
      '{"code":"fixture"}',
    ]) {
      await t.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          home: OfficePage(
            session: AuthSession.fromJson(verifiedResponse()),
            onUnauthorized: () {},
            api: TeamApi(
              client: MockClient(
                (r) async => http.Response(
                  r.method == 'POST'
                      ? response
                      : '{"name":"Office","configured":false}',
                  200,
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Chưa cấu hình địa điểm làm việc.'), findsOneWidget);
      await t.ensureVisible(find.text('Lấy QR chấm công'));
      await t.tap(find.text('Lấy QR chấm công'));
      await t.pumpAndSettle();
      expect(find.byType(QrImageView), findsNothing);
    }
  });
  testWidgets('unrecognized QR response is not encoded into a fabricated QR', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: OfficePage(
          session: AuthSession.fromJson(verifiedResponse()),
          onUnauthorized: () {},
          api: TeamApi(
            client: MockClient(
              (r) async => http.Response(
                r.method == 'POST' ? '{"unknown":"value"}' : '{"name":"Office","latitude":10,"longitude":106,"radius":100}',
                200,
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Lấy QR chấm công'));
    await t.tap(find.text('Lấy QR chấm công'));
    await t.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
    expect(find.textContaining('mã QR'), findsOneWidget);
  });
  testWidgets('office rejects non-finite coordinates before sending', (
    t,
  ) async {
    var saves = 0;
    await t.pumpWidget(
      MaterialApp(
        home: RecordEditor(
          resource: 'office',
          onSave: (payload) async {
            saves++;
          },
        ),
      ),
    );
    for (final e in [(0, 'Office'), (1, 'NaN'), (2, '106'), (3, '100')]) {
      await t.enterText(find.byType(TextFormField).at(e.$1), e.$2);
    }
    await t.ensureVisible(find.text('Lưu'));
    await t.tap(find.text('Lưu'));
    await t.pumpAndSettle();
    expect(saves, 0);
    expect(find.text('Nhập số hợp lệ.'), findsOneWidget);
  });
}
