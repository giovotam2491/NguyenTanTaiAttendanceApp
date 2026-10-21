import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiFailure implements Exception {
  const ApiFailure(this.message, {this.status, this.outcomeUnknown = false});
  final bool outcomeUnknown;
  final String message;
  final int? status;
  @override
  String toString() => message;
}

/// Transport only: successful JSON remains untyped until the team confirms it.
class TeamApi {
  TeamApi({
    required this._client,
    Uri? baseUrl,
    this._timeout = const Duration(seconds: 20),
  }) : _baseUrl =
           baseUrl ??
           Uri.parse(
             const String.fromEnvironment(
               'API_BASE_URL',
               defaultValue:
                   'https://webapi-chamcong-nhom9-tongnhatbaoan.onrender.com',
             ),
           ) {
    if (_baseUrl.scheme != 'https' ||
        _baseUrl.host.isEmpty ||
        _baseUrl.userInfo.isNotEmpty ||
        _baseUrl.hasQuery ||
        _baseUrl.hasFragment ||
        (_baseUrl.path.isNotEmpty && _baseUrl.path != '/')) {
      throw ArgumentError('API_BASE_URL phải là HTTPS origin hợp lệ.');
    }
  }
  final http.Client _client;
  final Uri _baseUrl;
  final Duration _timeout;
  static const _resources = {'employees', 'shifts', 'requests'};

  Future<Object?> login(String username, String password) => _send(
    'POST',
    ['auth', 'login'],
    body: {'username': username, 'password': password},
  );
  Future<Object?> verifyOtp(String challengeId, String code) => _send(
    'POST',
    ['auth', 'verify-otp'],
    body: {'challengeId': challengeId, 'code': code},
  );
  Future<Object?> me(String token) => _send('GET', ['me'], token: token);
  Future<Object?> list(String resource, String token) async {
    _checkResource(resource);
    return _send('GET', [resource], token: token);
  }

  Future<void> delete(String resource, String id, String token) async {
    _checkResource(resource);
    await _send('DELETE', [resource, id], token: token);
  }

  Future<Object?> register({
    required String name,
    required String email,
    required String username,
    required String password,
  }) => _send(
    'POST',
    ['auth', 'register'],
    body: {
      'name': name,
      'email': email,
      'username': username,
      'password': password,
    },
  );
  Future<Object?> verifyEmail(String id, String code) => _send(
    'POST',
    ['auth', 'verify-email'],
    body: {'challengeId': id, 'code': code},
  );
  Future<Object?> logout(String refreshToken) =>
      _send('POST', ['auth', 'logout'], body: {'refreshToken': refreshToken});
  Future<Object?> create(
    String resource,
    Map<String, Object?> payload,
    String token,
  ) async {
    _checkResource(resource);
    return _send('POST', [resource], body: payload, token: token);
  }

  Future<Object?> update(
    String resource,
    String id,
    Map<String, Object?> payload,
    String token,
  ) async {
    _checkResource(resource);
    return _send('PATCH', [resource, id], body: payload, token: token);
  }

  Future<Object?> assignShift(
    String employeeId,
    String? shiftId,
    String token,
  ) => _send(
    'PUT',
    ['employees', employeeId, 'shift'],
    body: {'shiftId': shiftId},
    token: token,
  );
  Future<Object?> reviewRequest(
    String id, {
    required bool approve,
    required String note,
    int? version,
    required String token,
  }) => _send(
    'POST',
    ['requests', id, 'review'],
    body: {'approve': approve, 'note': note, 'version': version},
    token: token,
  );
  Future<Object?> office(String token) =>
      _send('GET', ['office'], token: token);
  Future<Object?> updateOffice(Map<String, Object?> payload, String token) =>
      _send('PUT', ['office'], body: payload, token: token);
  Future<Object?> officeQr(String token) =>
      _send('POST', ['office', 'qr'], token: token);
  Future<Object?> punch({
    required bool checkOut,
    required Map<String, Object?> payload,
    required String token,
  }) => _send(
    'POST',
    ['attendance', checkOut ? 'check-out' : 'check-in'],
    body: payload,
    token: token,
  );
  Future<Object?> attendance(
    String token, {
    String? from,
    String? to,
    String? employeeId,
    int page = 1,
    int pageSize = 50,
  }) => _send(
    'GET',
    ['attendance'],
    token: token,
    query: {
      'from': ?from,
      'to': ?to,
      'employeeId': ?employeeId,
      'page': '$page',
      'pageSize': '$pageSize',
    },
  );
  void _checkResource(String resource) {
    if (!_resources.contains(resource)) {
      throw ArgumentError('Tài nguyên không được hỗ trợ.');
    }
  }

  Future<Object?> _send(
    String method,
    List<String> segments, {
    Map<String, Object?>? body,
    String? token,
    Map<String, String>? query,
  }) async {
    final url = _baseUrl.replace(
      pathSegments: ['api', ...segments],
      queryParameters: query,
    );
    final request = http.Request(method, url);
    request.headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }
    try {
      // One deadline includes body download. No automatic retry for writes.
      final response = await (() async {
        final stream = await _client.send(request);
        return http.Response.fromStream(stream);
      })().timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiFailure(
          _errorMessage(response),
          status: response.statusCode,
          outcomeUnknown: method != 'GET' && response.statusCode >= 500,
        );
      }
      if (response.bodyBytes.isEmpty) return null;
      try {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        throw ApiFailure(
          'Máy chủ trả dữ liệu không hợp lệ. Vui lòng thử lại sau.',
          outcomeUnknown: method != 'GET',
        );
      }
    } on TimeoutException {
      throw const ApiFailure(
        'Máy chủ chưa phản hồi kịp. Kết quả thao tác có thể chưa rõ; hãy kiểm tra trước khi gửi lại.',
        outcomeUnknown: true,
      );
    } on http.ClientException {
      throw ApiFailure(
        'Không kết nối được máy chủ. Kiểm tra mạng và thử lại.',
        outcomeUnknown: method != 'GET',
      );
    }
  }

  String _errorMessage(http.Response response) {
    String? safe(Object? value) {
      if (value is! String) return null;
      final text = value.trim();
      if (text.isEmpty ||
          text.length > 1000 ||
          RegExp(r'[<>\x00-\x08\x0B\x0C\x0E-\x1F]').hasMatch(text)) {
        return null;
      }
      return text;
    }

    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic>) {
        final message = safe(body['error']);
        if (message != null) return message;
        final errors = body['errors'];
        if (errors is Map<String, dynamic>) {
          final messages = <String>[];
          for (final values in errors.values) {
            if (values is! List) continue;
            for (final value in values) {
              final text = safe(value);
              if (text != null) messages.add(text);
            }
          }
          final combined = safe(messages.join(' '));
          if (combined != null) return combined;
        }
      }
    } on FormatException {
      // Proxies can return HTML or incomplete bodies; use the status fallback.
    }
    return _httpMessage(response.statusCode);
  }

  String _httpMessage(int status) => switch (status) {
    400 => 'Dữ liệu chưa được máy chủ chấp nhận. Kiểm tra và thử lại.',
    401 => 'Thông tin xác thực không hợp lệ hoặc phiên đã hết hạn.',
    403 => 'Bạn không có quyền thực hiện thao tác này.',
    404 => 'Không tìm thấy dữ liệu yêu cầu.',
    409 => 'Dữ liệu đang xung đột. Tải lại trước khi thao tác.',
    429 => 'Đã vượt giới hạn thao tác. Vui lòng thử lại sau.',
    _ => 'Máy chủ chưa xử lý được yêu cầu. Vui lòng thử lại sau.',
  };
  void close() => _client.close();
}
