import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyen_tan_tai_attendance_app/main.dart';

void main() {
  testWidgets('opens login without demo credentials', (tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.widgetWithText(FilledButton, 'Đăng nhập'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller
          ?.text,
      isEmpty,
    );
  });
  testWidgets('registration includes name email username and password', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.ensureVisible(find.text('Tạo tài khoản'));
    await tester.tap(find.text('Tạo tài khoản'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(4));
    expect(find.text('Email'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Đăng ký'), findsOneWidget);
  });
  testWidgets('blank login shows field errors instead of proceeding', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập tên đăng nhập.'), findsOneWidget);
    expect(find.text('Nhập mật khẩu.'), findsOneWidget);
  });
  for (final size in [
    const Size(360, 800),
    const Size(412, 915),
    const Size(800, 360),
  ]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets(
        'form remains reachable at $size $brightness and 200 percent text',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(
            tester.platformDispatcher.clearPlatformBrightnessTestValue,
          );
          await tester.pumpWidget(const MyApp());
          await tester.ensureVisible(
            find.widgetWithText(FilledButton, 'Đăng nhập'),
          );
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.text('Tạo tài khoản'));
          await tester.tap(find.text('Tạo tài khoản'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.widgetWithText(FilledButton, 'Đăng ký'),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
