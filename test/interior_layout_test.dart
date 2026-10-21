import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nguyen_tan_tai_attendance_app/api/team_api.dart';
import 'package:nguyen_tan_tai_attendance_app/auth/auth_session.dart';
import 'package:nguyen_tan_tai_attendance_app/home/account_home.dart';
import 'fixtures.dart';
void main(){
 for(final size in [const Size(360,800),const Size(800,360),const Size(1024,900)]){
 for(final role in ['admin','employee']){
 testWidgets('$role layout $size text200 dark reduced motion',(t)async{
  t.view.physicalSize=size;t.view.devicePixelRatio=1;
  addTearDown(t.view.resetPhysicalSize);addTearDown(t.view.resetDevicePixelRatio);
  final response=verifiedResponse(role:role);
  await t.pumpWidget(MaterialApp(theme:ThemeData.dark(),builder:(c,child)=>MediaQuery(data:MediaQuery.of(c).copyWith(textScaler:const TextScaler.linear(2),disableAnimations:true),child:child!),home:AccountHome(session:AuthSession.fromJson(response),api:TeamApi(client:MockClient((r)async=>http.Response(jsonEncode(switch(r.url.path){'/api/me'=>response['user'],'/api/office'=>{'configured':false},'/api/attendance'=>{'total':0,'page':1,'pageSize':1,'items':[]},_=>[]}),200))),onSignOut:()async{},onUnauthorized:(){})));
  await t.pumpAndSettle();expect(t.takeException(),isNull);
  if(size.width>=840) {
    expect(find.byType(NavigationRail),findsOneWidget);
  } else {
    expect(find.byType(NavigationBar),findsOneWidget);
  }
  for(final label in role=='admin'?['Nhân sự','Duyệt đơn','Thiết lập']:['Lịch sử','Đơn','Tài khoản']){
   await t.tap(find.text(label).last);await t.pumpAndSettle();expect(t.takeException(),isNull);
  }
 });
 }}
}
