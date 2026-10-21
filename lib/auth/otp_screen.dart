import 'package:flutter/material.dart';

import '../api/team_api.dart';
import 'auth_session.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.api,
    required this.challengeId,
    required this.emailVerification,
  });
  final TeamApi api;
  final String challengeId;
  final bool emailVerification;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _closed = false;
  bool get _current =>
      mounted && !_closed && ModalRoute.of(context)?.isCurrent == true;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_loading || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final code = _code.text.trim();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      Object result;
      if (widget.emailVerification) {
        await widget.api.verifyEmail(widget.challengeId, code);
        result = true;
      } else {
        final response = await widget.api.verifyOtp(widget.challengeId, code);
        result = AuthSession.fromJson(response);
      }
      if (!mounted || !_current) return;
      _code.clear();
      Navigator.of(context).pop(result);
    } on ApiFailure catch (error) {
      if (_current) setState(() => _error = error.message);
    } catch (_) {
      if (_current) {
        setState(() => _error = 'Chưa xác minh được mã. Vui lòng thử lại.');
      }
    } finally {
      if (_current) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope<Object?>(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _closed = true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.emailVerification ? 'Xác minh email' : 'Xác minh đăng nhập',
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 24),
                      ExcludeSemantics(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: colors.primaryContainer,
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Icon(
                              Icons.mark_email_read_outlined,
                              color: colors.onPrimaryContainer,
                              size: 42,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Semantics(
                        header: true,
                        child: Text(
                          'Chỉ còn một bước nữa.',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Nhập mã trong email để ${widget.emailVerification ? 'xác minh địa chỉ email' : 'tiếp tục đăng nhập'}.',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _code,
                        enabled: !_loading,
                        autofocus: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _verify(),
                        decoration: const InputDecoration(
                          labelText: 'Mã xác minh',
                          helperText: 'Có thể dán toàn bộ mã từ email.',
                          helperMaxLines: 3,
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Nhập mã xác minh.'
                            : null,
                      ),
                      const SizedBox(height: 22),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              _error!,
                              style: TextStyle(color: colors.error),
                            ),
                          ),
                        ),
                      FilledButton(
                        onPressed: _loading ? null : _verify,
                        child: Text(_loading ? 'Đang xác minh…' : 'Xác minh'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Quay lại đăng nhập'),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Nếu chưa thấy email, kiểm tra thư rác. '
                        'Bạn có thể quay lại để nhập lại thông tin đăng nhập.',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ],
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
