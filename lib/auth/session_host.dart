import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api/team_api.dart';
import '../home/account_home.dart';
import 'auth_form.dart';
import 'auth_session.dart';

class SessionHost extends StatefulWidget {
  const SessionHost({super.key, this.api});
  final TeamApi? api;
  @override
  State<SessionHost> createState() => _SessionHostState();
}

class _SessionHostState extends State<SessionHost> with WidgetsBindingObserver {
  late final TeamApi _api = widget.api ?? TeamApi(client: http.Client());
  AuthSession? _session;
  Timer? _expiry;
  String? _message;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _expiry?.cancel();
    if (widget.api == null) _api.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _session?.isExpired == true) {
      _invalidate();
    }
  }

  void _accept(AuthSession session) {
    if (!mounted) return;
    if (session.isExpired) {
      _invalidate();
      return;
    }
    _expiry?.cancel();
    _generation++;
    setState(() {
      _session = session;
      _message = null;
    });
    _expiry = Timer(
      session.expiresAt.difference(DateTime.now().toUtc()),
      _invalidate,
    );
  }

  void _invalidate([
    String message = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
  ]) {
    if (!mounted) return;
    _expiry?.cancel();
    _generation++;
    _session?.revoke();
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _session = null;
      _message = message;
    });
  }

  Future<void> _logout() async {
    final previous = _session;
    if (previous == null) return;
    _invalidate('Đã đăng xuất trên thiết bị.');
    final generation = _generation;
    try {
      await _api.logout(previous.refreshToken);
    } catch (_) {
      if (mounted && generation == _generation && _session == null) {
        setState(
          () => _message = 'Đã đăng xuất trên thiết bị. Chưa xác nhận được thu hồi phiên trên máy chủ.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) {
      return AuthForm(
        key: ValueKey(_generation),
        api: _api,
        initialMessage: _message,
        onAuthenticated: _accept,
      );
    }
    return AccountHome(
      api: _api,
      session: session,
      onSignOut: _logout,
      onUnauthorized: _invalidate,
    );
  }
}
