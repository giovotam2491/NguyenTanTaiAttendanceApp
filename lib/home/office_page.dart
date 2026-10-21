import 'dart:async';

import 'package:flutter/material.dart';

import '../ui/interior.dart';

import 'package:qr_flutter/qr_flutter.dart';

import '../api/team_api.dart';
import '../auth/auth_session.dart';
import '../resources/record_editor.dart';
import '../attendance/attendance_data.dart';

({String code, DateTime expiresAt}) decodeOfficeQr(Object? response) {
  if (response is! Map<String, dynamic> ||
      response['code'] is! String ||
      (response['code'] as String).trim().isEmpty ||
      response['expiresAt'] is! String) {
    throw const ApiFailure('Chưa đọc được mã QR từ phản hồi máy chủ.');
  }
  final expires = DateTime.tryParse(response['expiresAt'] as String);
  if (expires == null || !expires.isAfter(DateTime.now().toUtc())) {
    throw const ApiFailure('QR đã hết hạn. Hãy lấy mã mới.');
  }
  return (code: response['code'] as String, expiresAt: expires.toUtc());
}

class OfficePage extends StatefulWidget {
  const OfficePage({
    super.key,
    required this.api,
    required this.session,
    required this.onUnauthorized,
  });
  final TeamApi api;
  final AuthSession session;
  final VoidCallback onUnauthorized;
  @override
  State<OfficePage> createState() => _OfficePageState();
}

class _OfficePageState extends State<OfficePage> {
  Map<String, dynamic>? _office;
  String? _error, _qr;
  DateTime? _expiresAt;
  bool _busy = true;
  int _generation = 0;
  Timer? _qrExpiry;
  @override
  void dispose() {
    _qrExpiry?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    _qrExpiry?.cancel();
    setState(() {
      _busy = true;
      _error = null;
      _qr = null;
    });
    try {
      final response = await widget.api.office(widget.session.accessToken);
      if (!mounted || generation != _generation) return;
      if (response is! Map<String, dynamic>) {
        throw const ApiFailure('Chưa đọc được thông tin văn phòng.');
      }
      setState(() => _office = response);
    } on ApiFailure catch (e) {
      if (!mounted || generation != _generation) return;
      if (e.status == 401) {
        widget.onUnauthorized();
        return;
      }
      setState(() => _error = e.message);
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = 'Chưa tải được địa điểm.');
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RecordEditor(
          resource: 'office',
          initial: _office,
          onSave: (payload) async {
            try {
              await widget.api.updateOffice(
                payload,
                widget.session.accessToken,
              );
            } on ApiFailure catch (e) {
              if (mounted && e.status == 401) widget.onUnauthorized();
              rethrow;
            }
          },
        ),
      ),
    );
    if (mounted && saved != null) await _load();
  }

  Future<void> _getQr() async {
    if (_busy) return;
    _qrExpiry?.cancel();
    setState(() {
      _busy = true;
      _error = null;
      _qr = null;
    });
    try {
      final response = await widget.api.officeQr(widget.session.accessToken);
      if (!mounted) return;
      final qr = decodeOfficeQr(response);
      setState(() {
        _qr = qr.code;
        _expiresAt = qr.expiresAt;
      });
      _qrExpiry = Timer(qr.expiresAt.difference(DateTime.now().toUtc()), () {
        if (!mounted) return;
        setState(() {
          _qr = null;
          _error = 'QR đã hết hạn. Hãy lấy mã mới.';
        });
      });
    } on ApiFailure catch (e) {
      if (!mounted) return;
      if (e.status == 401) {
        widget.onUnauthorized();
        return;
      }
      setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Chưa lấy được mã QR.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => InteriorScope(
    builder: (context) => Scaffold(
      appBar: AppBar(
        title: const Text('Địa điểm và QR'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const InteriorHeading(
              'Thiết lập nơi làm việc',
              eyebrow: 'ĐỊA ĐIỂM & MÃ QR',
              subtitle: 'Một điểm chấm công rõ ràng cho cả đội.',
            ),
            if (_busy) const Center(child: CircularProgressIndicator()),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            if (_office?['configured'] == false)
              const Text('Chưa cấu hình địa điểm làm việc.'),
            if (_office != null) ...[
              Text(
                (_office!['name'] ?? 'Địa điểm làm việc').toString(),
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 16),
              for (final entry in {
                'latitude': 'Vĩ độ',
                'longitude': 'Kinh độ',
                'radius': 'Bán kính (m)',
              }.entries)
                if (_office![entry.key] != null)
                  Text('${entry.value}: ${_office![entry.key]}'),
            ],
            const SizedBox(height: 24),
            if (widget.session.user.isAdmin) ...[
              OutlinedButton.icon(
                onPressed: _busy ? null : _edit,
                icon: const Icon(Icons.edit_location_alt_outlined),
                label: const Text('Cập nhật địa điểm'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _getQr,
                icon: const Icon(Icons.qr_code),
                label: const Text('Lấy QR chấm công'),
              ),
            ],
            if (_qr != null) ...[
              Text(
                'Hết hạn lúc ${attendanceTime(_expiresAt?.toIso8601String())} (giờ Việt Nam)',
              ),
              const SizedBox(height: 24),
              Center(
                child: Semantics(
                  label: 'Mã QR chấm công được máy chủ cấp',
                  child: QrImageView(
                    data: _qr!,
                    size: 250,
                    backgroundColor: Colors.white,
                    errorStateBuilder: (_, error) => const Text(
                      'Không hiển thị được mã QR. Hãy lấy lại mã từ máy chủ.',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Mã do máy chủ cấp. Khi mã không còn hợp lệ, lấy lại mã mới.',
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
