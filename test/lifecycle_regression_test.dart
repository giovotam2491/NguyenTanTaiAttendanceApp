import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nguyen_tan_tai_attendance_app/api/team_api.dart';
import 'package:nguyen_tan_tai_attendance_app/auth/auth_session.dart';
import 'package:nguyen_tan_tai_attendance_app/attendance/punch_page.dart';
import 'package:nguyen_tan_tai_attendance_app/resources/resource_page.dart';
import 'package:nguyen_tan_tai_attendance_app/resources/record_editor.dart';

import 'fixtures.dart';

import 'package:nguyen_tan_tai_attendance_app/auth/otp_screen.dart';

Position position() => Position(
  latitude: 10,
  longitude: 106,
  timestamp: DateTime.now().toUtc(),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);
Future<void> tap(WidgetTester t, String label) async {
  final f = find.text(label).last;
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('revoked session during GPS cannot submit attendance', (t) async {
    final gps = Completer<Position>();
    var posts = 0;
    final session = AuthSession.fromJson(verifiedResponse(role: 'employee'));
    final api = TeamApi(
      client: MockClient((r) async {
        posts++;
        return http.Response('{}', 200);
      }),
    );
    await t.pumpWidget(
      MaterialApp(
        home: PunchPage(
          api: api,
          session: session,
          onUnauthorized: () {},
          locate: () => gps.future,
        ),
      ),
    );
    await t.enterText(find.byType(TextFormField), 'qr');
    await t.ensureVisible(find.text('Chấm công vào ca'));
    await t.tap(find.text('Chấm công vào ca'));
    await t.pump();
    session.revoke();
    gps.complete(position());
    await t.pumpAndSettle();
    expect(posts, 0);
    expect(session.pendingPunch, isNull);
  });
  testWidgets('OTP result during Back cannot pop underlying page', (t) async {
    final pending = Completer<http.Response>();
    final api = TeamApi(client: MockClient((r) => pending.future));
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () => Navigator.of(c).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Account form')),
                  body: Builder(
                    builder: (form) => TextButton(
                      onPressed: () => Navigator.of(form).push(
                        MaterialPageRoute<Object?>(
                          builder: (_) => OtpScreen(
                            api: api,
                            challengeId: 'challenge',
                            emailVerification: false,
                          ),
                        ),
                      ),
                      child: const Text('Open OTP'),
                    ),
                  ),
                ),
              ),
            ),
            child: const Text('Root'),
          ),
        ),
      ),
    );
    await tap(t, 'Root');
    await tap(t, 'Open OTP');
    await t.enterText(find.byType(TextFormField), 'code');
    await t.ensureVisible(find.text('Xác minh'));
    await t.tap(find.text('Xác minh'));
    await t.pump();
    await t.binding.handlePopRoute();
    await t.pump(const Duration(milliseconds: 10));
    pending.complete(http.Response(jsonEncode(verifiedResponse()), 200));
    await t.pumpAndSettle();
    expect(find.text('Account form'), findsOneWidget);
    expect(find.text('Root'), findsNothing);
  });

  testWidgets('late save during reverse transition cannot pop resource page', (
    t,
  ) async {
    final pending = Completer<http.Response>();
    final api = TeamApi(
      client: MockClient(
        (r) async => r.method == 'PATCH'
            ? pending.future
            : http.Response(
                '[{"id":"shift","name":"Day","startMinute":480,"endMinute":1020,"grace":0}]',
                200,
              ),
      ),
    );
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () => Navigator.of(c).push(
              MaterialPageRoute<void>(
                builder: (_) => ResourcePage(
                  api: api,
                  session: AuthSession.fromJson(verifiedResponse()),
                  resource: 'shifts',
                  title: 'Shift records',
                  onUnauthorized: () {},
                ),
              ),
            ),
            child: const Text('Open records'),
          ),
        ),
      ),
    );
    await tap(t, 'Open records');
    await t.tap(find.byTooltip('Sửa'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Lưu'));
    await t.tap(find.text('Lưu'));
    await t.pump();
    await t.binding.handlePopRoute();
    await t.pump(const Duration(milliseconds: 10));
    pending.complete(http.Response('{}', 200));
    await t.pumpAndSettle();
    expect(find.text('Shift records'), findsOneWidget);
    expect(find.text('Open records'), findsNothing);
  });
  testWidgets('GPS finishing after Back never posts a punch', (t) async {
    final gps = Completer<Position>();
    var posts = 0;
    final session = AuthSession.fromJson(verifiedResponse(role: 'employee'));
    final api = TeamApi(
      client: MockClient((r) async {
        posts++;
        return http.Response('{}', 200);
      }),
    );
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () => Navigator.of(c).push(
              MaterialPageRoute<void>(
                builder: (_) => PunchPage(
                  api: api,
                  session: session,
                  onUnauthorized: () {},
                  locate: () => gps.future,
                ),
              ),
            ),
            child: const Text('Open punch'),
          ),
        ),
      ),
    );
    await tap(t, 'Open punch');
    await t.enterText(find.byType(TextFormField), 'qr');
    await t.ensureVisible(find.text('Chấm công vào ca'));
    await t.tap(find.text('Chấm công vào ca'));
    await t.pump();
    await t.binding.handlePopRoute();
    await t.pump(const Duration(milliseconds: 10));
    gps.complete(position());
    await t.pumpAndSettle();
    expect(posts, 0);
  });
  testWidgets(
    'unknown punch survives leaving and reopening within same session',
    (t) async {
      final session = AuthSession.fromJson(verifiedResponse(role: 'employee'));
      final bodies = <String>[];
      final api = TeamApi(
        timeout: const Duration(milliseconds: 5),
        client: MockClient((r) async {
          bodies.add(r.body);
          if (bodies.length == 1) {
            await Future<void>.delayed(const Duration(milliseconds: 30));
          }
          return http.Response('{}', 200);
        }),
      );
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) => TextButton(
              onPressed: () => Navigator.of(c).push(
                MaterialPageRoute<void>(
                  builder: (_) => PunchPage(
                    api: api,
                    session: session,
                    onUnauthorized: () {},
                    locate: () async => position(),
                  ),
                ),
              ),
              child: const Text('Open punch'),
            ),
          ),
        ),
      );
      await tap(t, 'Open punch');
      await t.enterText(find.byType(TextFormField), 'qr');
      await tap(t, 'Chấm công vào ca');
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      await tap(t, 'Open punch');
      expect(find.text('Gửi lại cùng thao tác'), findsOneWidget);
      await tap(t, 'Gửi lại cùng thao tác');
      expect(bodies.length, 2);
      expect(bodies[0], bodies[1]);
    },
  );
  testWidgets('uncertain create cannot be immediately submitted again', (
    t,
  ) async {
    var saves = 0;
    await t.pumpWidget(
      MaterialApp(
        home: RecordEditor(
          resource: 'shifts',
          onSave: (payload) async {
            saves++;
            throw const ApiFailure('Unknown result', outcomeUnknown: true);
          },
        ),
      ),
    );
    for (final e in [(0, 'Day'), (1, '08:00'), (2, '17:00'), (3, '0')]) {
      await t.enterText(find.byType(TextFormField).at(e.$1), e.$2);
    }
    await tap(t, 'Lưu');
    final button = t.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Lưu'),
    );
    expect(button.onPressed, isNull);
    expect(saves, 1);
    expect(find.text('Quay lại kiểm tra danh sách'), findsOneWidget);
  });
}
