import '../api/team_api.dart';
import '../resources/resource_page.dart' show parseRecords;

class AttendanceSlice {
  AttendanceSlice(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['total'] is! int ||
        value['page'] is! int ||
        value['pageSize'] is! int ||
        value['total'] < 0 ||
        value['page'] < 1 ||
        value['pageSize'] < 1) {
      throw const ApiFailure('Chưa đọc được phân trang lịch sử.');
    }
    items = parseRecords(value['items']);
    total = value['total'];
    page = value['page'];
    pageSize = value['pageSize'];
    final expectedItems = (total - (page - 1) * pageSize).clamp(0, pageSize);
    if (items.length != expectedItems) {
      throw const ApiFailure('Phân trang lịch sử không nhất quán.');
    }
  }
  late final List<Map<String, dynamic>> items;
  late final int total, page, pageSize;
}

String attendanceTime(Object? value, {bool date = true}) {
  final parsed = value is String ? DateTime.tryParse(value) : null;
  if (parsed == null) return value == null ? '—' : 'Thời gian không hợp lệ';
  final vn = parsed.toUtc().add(const Duration(hours: 7));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date ? '${two(vn.day)}/${two(vn.month)}/${vn.year} ' : ''}${two(vn.hour)}:${two(vn.minute)}';
}
