import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../api/team_api.dart';
import '../auth/auth_session.dart';
import 'location_reader.dart';
import 'qr_scanner_page.dart';
import 'history_page.dart';

class PunchPage extends StatefulWidget {
  const PunchPage({
    super.key,
    required this.api,
    required this.session,
    required this.onUnauthorized,
    this.locate,
  });
  final TeamApi api;
  final AuthSession session;
  final VoidCallback onUnauthorized;
  final Future<Position> Function()? locate;
  @override
  State<PunchPage> createState() => _PunchPageState();
}

class _PunchPageState extends State<PunchPage> {
  final _qr = TextEditingController();
  bool _busy = false, _checkout = false;
  String? _error, _message;
  bool _closed = false;
  bool get _current =>
      mounted && !_closed && ModalRoute.of(context)?.isCurrent == true;
  Map<String, Object?>? get _pending => widget.session.pendingPunch;
  set _pending(Map<String, Object?>? value) =>
      widget.session.pendingPunch = value;
  @override
  void initState() {
    super.initState();
    if (_pending != null) {
      _checkout = widget.session.pendingCheckOut;
      _qr.text = _pending!['qr'] as String;
    }
  }

  @override
  void dispose() {
    _qr.clear();
    _qr.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const QrScannerPage()));
    if (mounted && code != null) _qr.text = code;
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (widget.session.isExpired) {
      widget.onUnauthorized();
      return;
    }
    if (_pending == null && _qr.text.trim().isEmpty) {
      setState(() => _error = 'Quét hoặc dán mã QR trước khi chấm công.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      if (_pending == null) {
        final position = await (widget.locate ?? readCurrentPosition)();
        if (!_current || widget.session.isExpired) return;
        final state = WidgetsBinding.instance.lifecycleState;
        if (state != null && state != AppLifecycleState.resumed) {
          throw const ApiFailure('Quay lại ứng dụng rồi thực hiện chấm công.');
        }
        final now = DateTime.now().toUtc();
        final captured = position.timestamp.toUtc();
        if (position.isMocked ||
            position.accuracy > 80 ||
            now.difference(captured) > const Duration(seconds: 60) ||
            captured.isAfter(now.add(const Duration(seconds: 5))) ||
            !position.latitude.isFinite ||
            position.latitude.abs() > 90 ||
            !position.longitude.isFinite ||
            position.longitude.abs() > 180 ||
            !position.accuracy.isFinite ||
            position.accuracy < 0) {
          throw const ApiFailure(
            'Vị trí chưa hợp lệ hoặc độ chính xác kém. Lấy GPS mới, tắt vị trí giả và kiểm tra giờ thiết bị.',
          );
        }
        final random = Random.secure();
        widget.session.pendingCheckOut = _checkout;
        _pending = {
          'qr': _qr.text.trim(),
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'capturedAt': position.timestamp.toUtc().toIso8601String(),
          'isMocked': position.isMocked,
          'idempotencyKey': base64UrlEncode(
            List<int>.generate(18, (_) => random.nextInt(256)),
          ),
        };
      }
      if (!_current || widget.session.isExpired) return;
      final operation = _pending;
      await widget.api.punch(
        checkOut: _checkout,
        payload: _pending!,
        token: widget.session.accessToken,
      );
      if (identical(_pending, operation)) _pending = null;
      if (!_current) return;
      setState(() {
        _message =
            'Máy chủ đã chấp nhận yêu cầu ${_checkout ? 'ra ca' : 'vào ca'}.';
        _pending = null;
        _qr.clear();
      });
    } on ApiFailure catch (e) {
      if (!_current) return;
      if (e.status == 401) {
        widget.onUnauthorized();
        return;
      }
      setState(() {
        _error = e.message;
        if (!e.outcomeUnknown) _pending = null;
      });
    } on TimeoutException {
      if (_current) {
        setState(() {
          _error = 'Chưa lấy được vị trí kịp thời. Kiểm tra GPS rồi thử lại.';
          _pending = null;
        });
      }
    } catch (_) {
      if (_current) {
        setState(
          () => _error =
              'Chưa hoàn tất chấm công. Kiểm tra mạng và quyền vị trí.',
        );
      }
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
    onPopInvokedWithResult: (didPop, result) {
      if (didPop) _closed = true;
    },
    child: Scaffold(
      appBar: AppBar(title: const Text('Chấm công')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Ghi nhận ca làm.',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Khi bạn xác nhận, vị trí hiện tại, độ chính xác và mã QR sẽ được gửi tới hệ thống chấm công.',
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<bool>(
                    initialValue: _checkout,
                    decoration: const InputDecoration(labelText: 'Thao tác'),
                    items: const [
                      DropdownMenuItem(value: false, child: Text('Vào ca')),
                      DropdownMenuItem(value: true, child: Text('Ra ca')),
                    ],
                    onChanged: _busy || _pending != null
                        ? null
                        : (v) => setState(() => _checkout = v ?? false),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _qr,
                    enabled: !_busy && _pending == null,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Mã QR',
                      helperText: 'Quét bằng camera hoặc dán mã được cấp.',
                      helperMaxLines: 3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _busy || _pending != null ? null : _scan,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Quét QR'),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (_message != null)
                    Semantics(liveRegion: true, child: Text(_message!)),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(
                      _busy
                          ? 'Đang xử lý…'
                          : _pending != null
                          ? 'Gửi lại cùng thao tác'
                          : _checkout
                          ? 'Chấm công ra ca'
                          : 'Chấm công vào ca',
                    ),
                  ),
                  if (_pending != null)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'Kết quả có thể đã được ghi. Kiểm tra lịch sử trước khi gửi lại. App giữ nguyên khóa thao tác để máy chủ xử lý trùng.',
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => HistoryPage(
                                api: widget.api,
                                session: widget.session,
                                onUnauthorized: widget.onUnauthorized,
                              ),
                            ),
                          ),
                    child: const Text('Xem lịch sử'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
