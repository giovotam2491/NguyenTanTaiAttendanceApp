import 'package:flutter/material.dart';

import '../api/team_api.dart';
import '../auth/account_validation.dart';

class FieldSpec {
  const FieldSpec(
    this.key,
    this.label, {
    this.kind = 'text',
    this.required = false,
  });
  final String key, label, kind;
  final bool required;
}

List<FieldSpec> fieldsFor(String resource, bool editing) => switch (resource) {
  'employees' => [
    const FieldSpec('name', 'Họ tên', required: true),
    const FieldSpec('email', 'Email', required: true),
    const FieldSpec('username', 'Tên đăng nhập', required: true),
    FieldSpec(
      'password',
      editing ? 'Mật khẩu mới (để trống nếu giữ nguyên)' : 'Mật khẩu',
      kind: 'password',
      required: !editing,
    ),
    const FieldSpec('department', 'Phòng ban'),
    const FieldSpec('role', 'Vai trò', kind: 'role', required: true),
    if (!editing)
      const FieldSpec('shiftId', 'ID ca làm (không bắt buộc)', kind: 'uuid'),
  ],
  'shifts' => [
    const FieldSpec('name', 'Tên ca', required: true),
    const FieldSpec(
      'startMinute',
      'Giờ bắt đầu (HH:mm)',
      kind: 'time',
      required: true,
    ),
    const FieldSpec(
      'endMinute',
      'Giờ kết thúc (HH:mm)',
      kind: 'time',
      required: true,
    ),
    const FieldSpec(
      'grace',
      'Thời gian cho phép trễ (phút)',
      kind: 'int',
      required: true,
    ),
  ],
  'requests' => [
    const FieldSpec(
      'type',
      'Loại yêu cầu',
      kind: 'requestType',
      required: true,
    ),
    const FieldSpec('reason', 'Lý do', required: true),
    const FieldSpec(
      'from',
      'Từ ngày (YYYY-MM-DD)',
      kind: 'date',
      required: true,
    ),
    const FieldSpec(
      'to',
      'Đến ngày (YYYY-MM-DD)',
      kind: 'date',
      required: true,
    ),
  ],
  'office' => [
    const FieldSpec('name', 'Tên địa điểm', required: true),
    const FieldSpec('latitude', 'Vĩ độ', kind: 'double', required: true),
    const FieldSpec('longitude', 'Kinh độ', kind: 'double', required: true),
    const FieldSpec('radius', 'Bán kính (m)', kind: 'double', required: true),
  ],
  _ => throw ArgumentError('Tài nguyên không được hỗ trợ.'),
};

class RecordEditor extends StatefulWidget {
  const RecordEditor({
    super.key,
    required this.resource,
    required this.onSave,
    this.initial,
  });
  final String resource;
  final Map<String, dynamic>? initial;
  final Future<void> Function(Map<String, Object?> payload) onSave;
  @override
  State<RecordEditor> createState() => _RecordEditorState();
}

class _RecordEditorState extends State<RecordEditor> {
  final _form = GlobalKey<FormState>();
  late final List<FieldSpec> _fields;
  final _values = <String, TextEditingController>{};
  bool _busy = false, _active = true, _uncertain = false;
  String? _error;
  bool _closed = false;
  bool get _current =>
      mounted && !_closed && ModalRoute.of(context)?.isCurrent == true;
  @override
  void initState() {
    super.initState();
    _fields = fieldsFor(widget.resource, widget.initial != null);
    _active = widget.initial?['active'] != false;
    for (final f in _fields) {
      final initial = widget.initial?[f.key];
      String value = initial?.toString() ?? '';
      if (f.key == 'password') value = '';
      if (f.kind == 'time' && initial is int) {
        value =
            '${(initial ~/ 60).toString().padLeft(2, '0')}:${(initial % 60).toString().padLeft(2, '0')}';
      }
      if (f.key == 'role' && value.isEmpty) value = 'employee';
      if (f.key == 'type' && value.isEmpty) value = 'Nghỉ phép';
      if (f.key == 'grace' && value.isEmpty) value = '0';
      _values[f.key] = TextEditingController(text: value);
    }
  }

  @override
  void dispose() {
    for (final c in _values.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validate(FieldSpec f, String? raw) {
    if (f.kind == 'password') {
      if ((raw ?? '').isEmpty && !f.required) return null;
      return validatePassword(raw ?? '');
    }
    final v = (raw ?? '').trim();
    if (v.isEmpty) {
      return f.required ? 'Vui lòng nhập ${f.label.toLowerCase()}.' : null;
    }
    if (f.key == 'username') return validateUsername(v);
    if (f.key == 'reason' && v.length < 10) {
      return 'Lý do cần ít nhất 10 ký tự.';
    }
    if (f.key == 'type' && !['Nghỉ phép', 'Giải trình chấm công'].contains(v)) {
      return 'Chọn loại yêu cầu hợp lệ.';
    }
    if (f.key == 'grace' && (int.tryParse(v) ?? -1) > 60) {
      return 'Cho phép trễ từ 0–60 phút.';
    }
    if (f.key == 'radius' &&
        double.tryParse(v) != null &&
        (double.parse(v) < 20 || double.parse(v) > 5000)) {
      return 'Bán kính cần từ 20–5000 mét.';
    }
    if (f.key == 'email' &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)) {
      return 'Email chưa hợp lệ.';
    }
    if (f.kind == 'int' && (int.tryParse(v) == null || int.parse(v) < 0)) {
      return 'Nhập số nguyên không âm.';
    }
    if (f.kind == 'double' &&
        (double.tryParse(v) == null || !double.parse(v).isFinite)) {
      return 'Nhập số hợp lệ.';
    }
    if (f.kind == 'time' &&
        !RegExp(r'^(?:[01]?[0-9]|2[0-3]):[0-5][0-9]$').hasMatch(v)) {
      return 'Nhập giờ theo dạng HH:mm.';
    }
    if (f.kind == 'date') {
      final d = DateTime.tryParse(v);
      if (d == null || d.toIso8601String().substring(0, 10) != v) {
        return 'Ngày chưa hợp lệ; dùng YYYY-MM-DD.';
      }
    }
    if (f.kind == 'uuid' &&
        !RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(v)) {
      return 'ID cần đúng định dạng UUID.';
    }
    return null;
  }

  Future<void> _save() async {
    if (_busy || _uncertain || !_form.currentState!.validate()) return;
    final payload = <String, Object?>{};
    for (final f in _fields) {
      final raw = _values[f.key]!.text;
      final v = f.kind == 'password' ? raw : raw.trim();
      if (f.key == 'password' && widget.initial != null && v.isEmpty) continue;
      if (f.kind == 'uuid' && v.isEmpty) {
        payload[f.key] = null;
        continue;
      }
      payload[f.key] = switch (f.kind) {
        'int' => int.parse(v),
        'double' => double.parse(v),
        'time' => int.parse(v.split(':')[0]) * 60 + int.parse(v.split(':')[1]),
        _ => v,
      };
    }
    if (widget.resource == 'office' &&
        ((payload['latitude'] as double).abs() > 90 ||
            (payload['longitude'] as double).abs() > 180 ||
            (payload['radius'] as double) <= 0)) {
      setState(() => _error = 'Tọa độ hoặc bán kính chưa hợp lệ.');
      return;
    }
    if (widget.resource == 'shifts' &&
        payload['startMinute'] == payload['endMinute']) {
      setState(() => _error = 'Giờ bắt đầu và kết thúc phải khác nhau.');
      return;
    }
    if (widget.resource == 'requests' &&
        (payload['from'] as String).compareTo(payload['to'] as String) > 0) {
      setState(() => _error = 'Ngày bắt đầu không được sau ngày kết thúc.');
      return;
    }
    if (widget.resource == 'employees' && widget.initial != null) {
      payload['active'] = _active;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSave(payload);
      if (mounted && _current) Navigator.of(context).pop(true);
    } on ApiFailure catch (e) {
      if (_current) {
        setState(() {
          _error = e.message;
          _uncertain = e.outcomeUnknown;
        });
      }
    } catch (_) {
      if (_current) {
        setState(() => _error = 'Chưa lưu được dữ liệu. Vui lòng thử lại.');
      }
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<bool>(
    onPopInvokedWithResult: (didPop, result) {
      if (didPop) _closed = true;
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'Thêm mới' : 'Sửa thông tin'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final f in _fields)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 22),
                        child: f.kind == 'role' || f.kind == 'requestType'
                            ? DropdownButtonFormField<String>(
                                initialValue: _values[f.key]!.text,
                                decoration: InputDecoration(labelText: f.label),
                                isExpanded: true,
                                items:
                                    (f.kind == 'requestType'
                                            ? {
                                                'Nghỉ phép',
                                                'Giải trình chấm công',
                                                _values[f.key]!.text,
                                              }
                                            : {
                                                'employee',
                                                'admin',
                                                _values[f.key]!.text,
                                              })
                                        .map(
                                          (r) => DropdownMenuItem(
                                            value: r,
                                            child: Text(
                                              r == 'admin'
                                                  ? 'Quản trị'
                                                  : r == 'employee'
                                                  ? 'Nhân viên'
                                                  : r,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                validator: (v) => _validate(f, v),
                                onChanged: _busy || _uncertain
                                    ? null
                                    : (v) => _values[f.key]!.text =
                                          v ?? _values[f.key]!.text,
                              )
                            : TextFormField(
                                controller: _values[f.key],
                                enabled: !_busy && !_uncertain,
                                obscureText: f.kind == 'password',
                                keyboardType: f.kind == 'int'
                                    ? TextInputType.number
                                    : f.key == 'email'
                                    ? TextInputType.emailAddress
                                    : TextInputType.text,
                                autocorrect: false,
                                decoration: InputDecoration(labelText: f.label),
                                validator: (v) => _validate(f, v),
                              ),
                      ),
                    if (widget.resource == 'employees' &&
                        widget.initial != null)
                      SwitchListTile(
                        title: const Text('Tài khoản hoạt động'),
                        value: _active,
                        onChanged: _busy || _uncertain
                            ? null
                            : (v) => setState(() => _active = v),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
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
                    FilledButton(
                      onPressed: _busy || _uncertain ? null : _save,
                      child: Text(_busy ? 'Đang lưu…' : 'Lưu'),
                    ),
                    if (_uncertain)
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Quay lại kiểm tra danh sách'),
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
