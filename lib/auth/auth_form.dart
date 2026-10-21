import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api/team_api.dart';
import 'otp_screen.dart';
import 'auth_session.dart';
import 'account_validation.dart';

class AuthForm extends StatefulWidget {
  const AuthForm({
    super.key,
    this.api,
    this.onAuthenticated,
    this.initialMessage,
  });
  final TeamApi? api;
  final String? initialMessage;
  final ValueChanged<AuthSession>? onAuthenticated;
  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  late final http.Client _httpClient = http.Client();
  late final TeamApi _api = widget.api ?? TeamApi(client: _httpClient);
  bool _loading = false;
  bool _success = false;
  bool _register = false;
  bool _obscure = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _message = widget.initialMessage;
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _username, _password]) {
      c.dispose();
    }
    if (widget.api == null) _api.close();
    super.dispose();
  }

  void _changeMode() {
    if (_loading) return;
    setState(() {
      _register = !_register;
      _message = null;
      _success = false;
      _form.currentState?.reset();
      _password.clear();
      _obscure = true;
    });
  }

  Future<void> _submit() async {
    if (_loading || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final registering = _register;
    setState(() {
      _loading = true;
      _success = false;
      _message = null;
    });
    try {
      final response = registering
          ? await _api.register(
              name: _name.text.trim(),
              email: _email.text.trim(),
              username: _username.text.trim(),
              password: _password.text,
            )
          : await _api.login(_username.text.trim(), _password.text);
      if (!mounted) return;
      if (response is! Map<String, dynamic> ||
          response['challengeId'] is! String ||
          (response['challengeId'] as String).trim().isEmpty) {
        throw const ApiFailure('Phản hồi máy chủ thiếu challengeId hợp lệ.');
      }
      final challengeId = response['challengeId'] as String;
      _password.clear();
      final reduceMotion = MediaQuery.disableAnimationsOf(context);
      final verified = await Navigator.of(context).push<Object?>(
        PageRouteBuilder(
          transitionDuration: Duration(milliseconds: reduceMotion ? 0 : 420),
          reverseTransitionDuration: Duration(
            milliseconds: reduceMotion ? 0 : 240,
          ),
          pageBuilder: (context, animation, secondaryAnimation) => OtpScreen(
            api: _api,
            challengeId: challengeId,
            emailVerification: registering,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(.04, 0),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                  child: child,
                ),
              ),
        ),
      );
      if (!mounted) return;
      if (verified is AuthSession) {
        if (widget.onAuthenticated != null) {
          widget.onAuthenticated!(verified);
          return;
        }
        setState(() {
          _success = true;
          _message = 'Đã xác minh mã đăng nhập.';
        });
      }
      if (verified == true) {
        setState(() {
          _success = true;
          _message = registering
              ? 'Yêu cầu xác minh email đã được máy chủ chấp nhận. Bạn có thể thử đăng nhập.'
              : 'Đã xác minh mã đăng nhập.';
          if (registering) _register = false;
        });
      }
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Không thực hiện được yêu cầu. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _field(
    String label,
    TextEditingController controller,
    IconData icon,
    String error, {
    bool password = false,
    bool email = false,
    Iterable<String>? autofill,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: TextFormField(
      controller: controller,
      enabled: !_loading,
      style: const TextStyle(fontSize: 16),
      obscureText: password && _obscure,
      enableSuggestions: !password,
      autocorrect: false,
      autofillHints: autofill,
      keyboardType: email ? TextInputType.emailAddress : TextInputType.text,
      textInputAction: password ? TextInputAction.done : TextInputAction.next,
      onFieldSubmitted: password ? (_) => _submit() : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: ExcludeSemantics(child: Icon(icon, size: 21)),
        suffixIcon: password
            ? IconButton(
                tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              )
            : null,
      ),
      validator: (value) {
        if (value == null ||
            (password ? value.isEmpty : value.trim().isEmpty)) {
          return error;
        }
        if (_register && controller == _username) {
          return validateUsername(value);
        }
        if (_register && password) return validatePassword(value);
        if (email &&
            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())) {
          return 'Nhập địa chỉ email hợp lệ.';
        }
        return null;
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.3,
            colors: [
              dark ? const Color(0xff253854) : const Color(0xffe0eaff),
              colors.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: AutofillGroup(
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'NguyenTanTai Attendance',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                        if (!_register) ...[
                          ExcludeSemantics(
                            child: Center(
                              child: Container(
                                width: 104,
                                height: 104,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(34),
                                  border: Border.all(
                                    color: colors.primary.withValues(
                                      alpha: .18,
                                    ),
                                  ),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      colors.surface,
                                      colors.primaryContainer,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors.primary.withValues(
                                        alpha: .1,
                                      ),
                                      blurRadius: 25,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.done_rounded,
                                  size: 48,
                                  color: colors.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                        ],
                        Semantics(
                          header: true,
                          child: Text(
                            _register
                                ? 'Tạo tài khoản.\nCùng bắt đầu.'
                                : 'Chào bạn.\nNgày mới đã sẵn sàng.',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _register
                              ? 'Đăng ký bằng email để nhận mã xác minh.'
                              : 'Đăng nhập để bắt đầu cùng đội ngũ của bạn.',
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 28),
                        if (_register) ...[
                          _field(
                            'Họ tên',
                            _name,
                            Icons.badge_outlined,
                            'Nhập họ tên.',
                            autofill: const [AutofillHints.name],
                          ),
                          _field(
                            'Email',
                            _email,
                            Icons.mail_outline_rounded,
                            'Nhập email.',
                            email: true,
                            autofill: const [AutofillHints.email],
                          ),
                        ],
                        _field(
                          'Tên đăng nhập',
                          _username,
                          Icons.person_outline_rounded,
                          'Nhập tên đăng nhập.',
                          autofill: const [AutofillHints.username],
                        ),
                        _field(
                          'Mật khẩu',
                          _password,
                          Icons.lock_outline_rounded,
                          'Nhập mật khẩu.',
                          password: true,
                          autofill: [
                            _register
                                ? AutofillHints.newPassword
                                : AutofillHints.password,
                          ],
                        ),
                        if (_message != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Semantics(
                              liveRegion: true,
                              child: Text(
                                _message!,
                                style: TextStyle(
                                  color: _success
                                      ? colors.primary
                                      : colors.error,
                                ),
                              ),
                            ),
                          ),
                        FilledButton(
                          onPressed: _loading ? null : _submit,
                          child: Text(
                            _loading
                                ? 'Đang kết nối...'
                                : (_register ? 'Đăng ký' : 'Đăng nhập'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _loading ? null : _changeMode,
                          child: Text(
                            _register ? 'Quay lại đăng nhập' : 'Tạo tài khoản',
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Xác minh bằng mã OTP gửi qua email.\nCần trợ giúp? Liên hệ người quản lý.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
