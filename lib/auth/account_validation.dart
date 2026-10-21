String? validateUsername(String value) =>
    RegExp(r'^[a-zA-Z0-9_.-]{3,40}$').hasMatch(value.trim())
    ? null
    : 'Tên đăng nhập cần 3–40 ký tự: chữ không dấu, số, _, ., -.';
String? validatePassword(String value) =>
    value.length >= 8 ? null : 'Mật khẩu phải có ít nhất 8 ký tự.';
