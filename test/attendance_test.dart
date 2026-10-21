import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nguyen_tan_tai_attendance_app/api/team_api.dart';
import 'package:nguyen_tan_tai_attendance_app/auth/auth_session.dart';
import 'package:nguyen_tan_tai_attendance_app/attendance/punch_page.dart';

import 'fixtures.dart';

Position testPosition({
  double accuracy = 7,
  bool mocked = false,
  int offsetSeconds = 0,
}) => Position(
  latitude: 10,
  longitude: 106,
  timestamp: DateTime.now().toUtc().add(Duration(seconds: offsetSeconds)),
  accuracy: accuracy,
  isMocked: mocked,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);
Future<void> submit(WidgetTester t, String text) async {
  final f = find.text(text).last;
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  for (final (accuracy, mocked, offset, allowed) in [
    (80.0, false, 0, true),
    (81.0, false, 0, false),
    (7.0, true, 0, false),
    (7.0, false, -61, false),
    (7.0, false, 6, false),
    (7.0, false, -59, true),
    (7.0, false, 4, true),
  ]) {
    testWidgets(
      'new GPS accuracy=$accuracy mock=$mocked offset=$offset allowed=$allowed',
      (t) async {
        var sent = 0;
        await t.pumpWidget(
          MaterialApp(
            home: PunchPage(
              api: TeamApi(
                client: MockClient((r) async {
                  sent++;
                  return http.Response('{}', 200);
                }),
              ),
              session: AuthSession.fromJson(verifiedResponse(role: 'employee')),
              onUnauthorized: () {},
              locate: () async => testPosition(
                accuracy: accuracy,
                mocked: mocked,
                offsetSeconds: offset,
              ),
            ),
          ),
        );
        await t.enterText(find.byType(TextFormField), 'qr');
        await submit(t, 'Chấm công vào ca');
        expect(sent, allowed ? 1 : 0);
      },
    );
  }
  testWidgets('pending retry reuses old GPS payload without reacquiring', (
    t,
  ) async {
    final session = AuthSession.fromJson(verifiedResponse(role: 'employee'));
    final pending = <String, Object?>{
      'qr': 'old-qr',
      'latitude': 10,
      'longitude': 106,
      'accuracy': 7,
      'capturedAt': '2000-01-01T00:00:00Z',
      'idempotencyKey': 'original-key',
      'isMocked': false,
    };
    session.pendingPunch = pending;
    session.pendingCheckOut = true;
    var locations = 0;
    Map? sent;
    await t.pumpWidget(
      MaterialApp(
        home: PunchPage(
          session: session,
          onUnauthorized: () {},
          api: TeamApi(
            client: MockClient((r) async {
              sent = jsonDecode(r.body) as Map;
              expect(r.url.path.endsWith('check-out'), true);
              return http.Response('{}', 200);
            }),
          ),
          locate: () async {
            locations++;
            return testPosition();
          },
        ),
      ),
    );
    await submit(t, 'Gửi lại cùng thao tác');
    expect(sent, pending);
    expect(locations, 0);
  });

  testWidgets('check in posts scanned QR GPS metadata and unique key', (
    t,
  ) async {
    Map? payload;
    await t.pumpWidget(
      MaterialApp(
        home: PunchPage(
          api: TeamApi(
            client: MockClient((r) async {
              expect(r.url.path, '/api/attendance/check-in');
              payload = jsonDecode(r.body) as Map;
              return http.Response('{}', 200);
            }),
          ),
          session: AuthSession.fromJson(verifiedResponse(role: 'employee')),
          onUnauthorized: () {},
          locate: () async => testPosition(),
        ),
      ),
    );
    await t.enterText(find.byType(TextFormField), 'qr-fixture');
    await submit(t, 'Chấm công vào ca');
    expect(payload!['qr'], 'qr-fixture');
    expect(payload!['latitude'], 10);
    expect(payload!['accuracy'], 7);
    expect(payload!['isMocked'], false);
    expect(payload!['idempotencyKey'], isNotEmpty);
    expect(find.textContaining('đã chấp nhận'), findsOneWidget);
  });
  testWidgets('GPS denial never sends punch', (t) async {
    var sent = 0;
    await t.pumpWidget(
      MaterialApp(
        home: PunchPage(
          api: TeamApi(
            client: MockClient((r) async {
              sent++;
              return http.Response('{}', 200);
            }),
          ),
          session: AuthSession.fromJson(verifiedResponse(role: 'employee')),
          onUnauthorized: () {},
          locate: () async =>
              throw const ApiFailure('Chưa được cấp quyền vị trí.'),
        ),
      ),
    );
    await t.enterText(find.byType(TextFormField), 'qr-fixture');
    await submit(t, 'Chấm công vào ca');
    expect(sent, 0);
    expect(find.text('Chưa được cấp quyền vị trí.'), findsOneWidget);
  });
  testWidgets('uncertain write retry keeps same payload and idempotency key', (
    t,
  ) async {
    final bodies = <String>[];
    final api = TeamApi(
      timeout: const Duration(milliseconds: 5),
      client: MockClient((r) async {
        bodies.add(r.body);
        if (bodies.length == 1) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        return http.Response('{}', 200);
      }),
    );
    await t.pumpWidget(
      MaterialApp(
        home: PunchPage(
          api: api,
          session: AuthSession.fromJson(verifiedResponse(role: 'employee')),
          onUnauthorized: () {},
          locate: () async => testPosition(),
        ),
      ),
    );
    await t.enterText(find.byType(TextFormField), 'qr-fixture');
    await submit(t, 'Chấm công vào ca');
    await submit(t, 'Gửi lại cùng thao tác');
    expect(bodies.length, 2);
    expect(bodies[0], bodies[1]);
  });
}
