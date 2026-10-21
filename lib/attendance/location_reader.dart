import 'package:geolocator/geolocator.dart';

import '../api/team_api.dart';

Future<Position> readCurrentPosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const ApiFailure('GPS đang tắt. Bật dịch vụ vị trí rồi thử lại.');
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.deniedForever) {
    throw const ApiFailure(
      'Quyền vị trí đã bị chặn. Mở cài đặt ứng dụng để cấp lại quyền.',
    );
  }
  if (permission == LocationPermission.denied) {
    throw const ApiFailure('Chưa được cấp quyền vị trí.');
  }
  return Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 15),
    ),
  );
}
