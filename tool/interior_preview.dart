// Isolated visual fixture entry point. Never imported by lib/main.dart.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nguyen_tan_tai_attendance_app/api/team_api.dart';
import 'package:nguyen_tan_tai_attendance_app/auth/auth_session.dart';
import 'package:nguyen_tan_tai_attendance_app/home/account_home.dart';
import 'package:nguyen_tan_tai_attendance_app/ui/app_theme.dart';

void main() {
  if (!kDebugMode) throw StateError('Preview is debug only.');
  final admin = Uri.base.queryParameters['role'] == 'admin';
  final user = {
    'id': 'preview-user',
    'name': 'Minh Anh',
    'username': 'minhanh',
    'email': 'preview@example.test',
    'role': admin ? 'admin' : 'employee',
    'active': true,
    'department': 'Thiết kế sản phẩm',
    'shiftId': 'shift-demo',
  };
  final shifts = [
    {
      'id': 'shift-demo',
      'name': 'Ca hành chính',
      'startMinute': 480,
      'endMinute': 1020,
      'grace': 10,
    },
  ];
  final people = [
    user,
    {
      'id': 'other',
      'name': 'Hoàng Nam',
      'username': 'hoangnam',
      'department': 'Kỹ thuật',
      'email': 'other@example.test',
      'role': 'employee',
      'active': true,
    },
  ];
  final requests = [
    {
      'id': 'req-demo',
      'employeeId': admin ? 'other' : 'preview-user',
      'employeeName': admin ? 'Hoàng Nam' : 'Minh Anh',
      'type': 'Nghỉ phép',
      'reason': 'Xin nghỉ một ngày để giải quyết việc gia đình.',
      'from': '2026-10-23',
      'to': '2026-10-23',
      'status': 'pending',
      'version': 1,
    },
  ];
  final attendance = {
    'total': 1,
    'page': 1,
    'pageSize': 50,
    'items': [
      {
        'id': 'record-demo',
        'employeeId': 'preview-user',
        'employeeName': 'Minh Anh',
        'shiftName': 'Ca hành chính',
        'workDate': '2026-10-22',
        'checkIn': '2026-10-22T00:58:00Z',
        'checkOut': null,
        'scheduledEnd': '2026-10-22T10:00:00Z',
        'lateMinutes': 0,
      },
    ],
  };
  final api = TeamApi(
    client: MockClient((r) async {
      if (r.method != 'GET') {
        return http.Response(
          '{"error":"Bản xem thử không ghi dữ liệu."}',
          403,
          headers: {'content-type': 'application/json'},
        );
      }
      final Object response = switch (r.url.path) {
        '/api/me' => user,
        '/api/shifts' => shifts,
        '/api/employees' => people,
        '/api/requests' => requests,
        '/api/attendance' => {
          ...attendance,
          'pageSize':
              int.tryParse(r.url.queryParameters['pageSize'] ?? '50') ?? 50,
        },
        '/api/office' => {
          'configured': true,
          'name': 'Văn phòng Nhóm 9',
          'latitude': 10.77,
          'longitude': 106.69,
          'radius': 150,
        },
        _ => [],
      };
      return http.Response(
        jsonEncode(response),
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
  );
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: Uri.base.queryParameters['theme'] == 'dark'
          ? ThemeMode.dark
          : ThemeMode.light,
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: AccountHome(
        api: api,
        session: AuthSession(
          accessToken: 'fixture-only',
          refreshToken: 'fixture-only',
          expiresAt: DateTime.utc(2099),
          user: AccountUser.fromJson(user),
        ),
        onSignOut: () async {},
        onUnauthorized: () {},
      ),
    ),
  );
}
