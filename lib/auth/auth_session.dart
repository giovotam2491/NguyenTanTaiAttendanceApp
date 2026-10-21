import '../api/team_api.dart';

class AccountUser {
  const AccountUser({
    required this.id,
    required this.name,
    required this.email,
    required this.username,
    required this.role,
    required this.active,
    this.department = '',
    this.shiftId,
  });
  final String id, name, email, username, role, department;
  final bool active;
  final String? shiftId;
  bool get isAdmin => role.toLowerCase() == 'admin';
  bool get isEmployee => role.toLowerCase() == 'employee';
  factory AccountUser.fromJson(Object? data) {
    if (data is! Map<String, dynamic> ||
        data['id'] is! String ||
        (data['id'] as String).trim().isEmpty ||
        data['role'] is! String ||
        (data['role'] as String).trim().isEmpty ||
        data['active'] is! bool) {
      throw const ApiFailure('Dữ liệu tài khoản không hợp lệ.');
    }
    String text(String key) => data[key] is String ? data[key] as String : '';
    return AccountUser(
      id: text('id'),
      name: text('name'),
      email: text('email'),
      username: text('username'),
      role: text('role'),
      active: data['active'] as bool,
      department: text('department'),
      shiftId: data['shiftId'] is String ? data['shiftId'] as String : null,
    );
  }
}

class AuthSession {
  AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.user,
  });
  final String accessToken, refreshToken;
  final DateTime expiresAt;
  final AccountUser user;
  bool _revoked = false;
  // Retain an uncertain operation while navigating within this session.
  Map<String, Object?>? pendingPunch;
  bool pendingCheckOut = false;
  void revoke() {
    _revoked = true;
    pendingPunch = null;
  }

  bool get isExpired => _revoked || !expiresAt.isAfter(DateTime.now().toUtc());
  factory AuthSession.fromJson(Object? data) {
    if (data is! Map<String, dynamic> ||
        data['accessToken'] is! String ||
        (data['accessToken'] as String).trim().isEmpty ||
        data['refreshToken'] is! String ||
        (data['refreshToken'] as String).trim().isEmpty ||
        data['accessExpiresAt'] is! String) {
      throw const ApiFailure('Phản hồi xác minh thiếu thông tin phiên hợp lệ.');
    }
    final expires = DateTime.tryParse(data['accessExpiresAt'] as String);
    if (expires == null) throw const ApiFailure('Thời hạn phiên không hợp lệ.');
    final user = AccountUser.fromJson(data['user']);
    if (!expires.isAfter(DateTime.now().toUtc()) || !user.active) {
      throw const ApiFailure(
        'Phiên đã hết hạn hoặc tài khoản chưa hoạt động.',
        status: 401,
      );
    }
    return AuthSession(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      expiresAt: expires.toUtc(),
      user: user,
    );
  }
}
