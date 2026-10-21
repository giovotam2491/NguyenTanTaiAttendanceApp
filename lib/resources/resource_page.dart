import 'package:flutter/material.dart';

import '../api/team_api.dart';
import '../auth/auth_session.dart';
import 'record_editor.dart';

List<Map<String, dynamic>> parseRecords(Object? value) {
  final items = value;
  if (items is! List || items.any((e) => e is! Map<String, dynamic>)) {
    throw const ApiFailure(
      'Chưa đọc được danh sách từ máy chủ. Vui lòng thử lại hoặc liên hệ quản trị viên.',
    );
  }
  return items.cast<Map<String, dynamic>>();
}

const _labels = {
  'username': 'Tên đăng nhập',
  'email': 'Email',
  'department': 'Phòng ban',
  'role': 'Vai trò',
  'type': 'Loại yêu cầu',
  'from': 'Từ ngày',
  'to': 'Đến ngày',
  'status': 'Trạng thái',
  'startMinute': 'Giờ bắt đầu',
  'endMinute': 'Giờ kết thúc',
  'grace': 'Cho phép trễ (phút)',
  'employeeName': 'Nhân viên',
  'reviewerNote': 'Nhận xét',
};
String _display(String key, Object? value) {
  if ((key == 'startMinute' || key == 'endMinute') &&
      value is int &&
      value >= 0 &&
      value < 1440) {
    return '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
  }
  return value.toString();
}

class ResourcePage extends StatefulWidget {
  const ResourcePage({
    super.key,
    required this.api,
    required this.session,
    required this.resource,
    required this.title,
    required this.onUnauthorized,
  });
  final TeamApi api;
  final AuthSession session;
  final String resource, title;
  final VoidCallback onUnauthorized;
  @override
  State<ResourcePage> createState() => _ResourcePageState();
}

class _ResourcePageState extends State<ResourcePage> {
  List<Map<String, dynamic>> _items = [];
  bool _busy = true, _mutating = false;
  String? _error;
  int _generation = 0;
  bool get _canWrite =>
      widget.session.user.isAdmin ||
      (widget.resource == 'requests' && widget.session.user.isEmployee);
  bool _editable(Map<String, dynamic> item) =>
      _canWrite &&
      item['id'] is String &&
      (widget.resource != 'requests' ||
          (item['employeeId'] == widget.session.user.id &&
              item['status'] == 'pending'));
  bool _reviewable(Map<String, dynamic> item) =>
      widget.resource == 'requests' &&
      widget.session.user.isAdmin &&
      item['id'] is String &&
      item['employeeId'] is String &&
      item['employeeId'] != widget.session.user.id &&
      item['status'] == 'pending';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final items = parseRecords(
        await widget.api.list(widget.resource, widget.session.accessToken),
      );
      if (!mounted || generation != _generation) return;
      setState(() => _items = items);
    } on ApiFailure catch (e) {
      if (!mounted || generation != _generation) return;
      if (e.status == 401) {
        widget.onUnauthorized();
        return;
      }
      setState(() => _error = e.message);
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = 'Chưa tải được danh sách.');
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _write(Future<Object?> Function() action) async {
    if (widget.session.isExpired) {
      widget.onUnauthorized();
      throw const ApiFailure('Phiên đã hết hạn.', status: 401);
    }
    try {
      await action();
    } on ApiFailure catch (e) {
      if (mounted && e.status == 401) widget.onUnauthorized();
      rethrow;
    }
  }

  Future<void> _edit([Map<String, dynamic>? initial]) async {
    if (!_canWrite || _mutating || (initial != null && !_editable(initial))) {
      return;
    }
    final id = initial?['id'];
    if (initial != null && (id is! String || id.isEmpty)) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RecordEditor(
          resource: widget.resource,
          initial: initial,
          onSave: (payload) => _write(
            () => initial == null
                ? widget.api.create(
                    widget.resource,
                    payload,
                    widget.session.accessToken,
                  )
                : widget.api.update(
                    widget.resource,
                    id as String,
                    payload,
                    widget.session.accessToken,
                  ),
          ),
        ),
      ),
    );
    if (mounted && saved != null) await _load();
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    if (_mutating || !_editable(item)) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Xóa ${item['name'] ?? item['reason'] ?? 'dữ liệu này'}? Thao tác sẽ gửi lên máy chủ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Xóa dữ liệu'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _mutating = true);
    try {
      await _write(() async {
        await widget.api.delete(
          widget.resource,
          item['id'] as String,
          widget.session.accessToken,
        );
        return null;
      });
      if (mounted) await _load();
    } on ApiFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Chưa xóa được dữ liệu.');
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _review(Map<String, dynamic> item, bool approve) async {
    if (_mutating || !_reviewable(item)) {
      return;
    }
    final form = GlobalKey<FormState>();
    var note = '';
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(approve ? 'Duyệt yêu cầu' : 'Từ chối yêu cầu'),
        content: Form(
          key: form,
          child: TextFormField(
            onChanged: (value) => note = value,
            validator: (value) => (value ?? '').trim().isEmpty
                ? 'Nhập nhận xét khi duyệt hoặc từ chối.'
                : null,
            decoration: const InputDecoration(labelText: 'Nhận xét (bắt buộc)'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(c, true);
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    final text = note;
    if (yes != true || !mounted) return;
    setState(() => _mutating = true);
    try {
      await _write(
        () => widget.api.reviewRequest(
          item['id'] as String,
          approve: approve,
          note: text.trim(),
          version: item['version'] is int ? item['version'] as int : null,
          token: widget.session.accessToken,
        ),
      );
      if (mounted) await _load();
    } on ApiFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Chưa gửi được kết quả duyệt.');
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _assign(Map<String, dynamic> item) async {
    if (_mutating || !widget.session.user.isAdmin || item['id'] is! String) {
      return;
    }
    setState(() => _mutating = true);
    try {
      final shifts = parseRecords(
        await widget.api.list('shifts', widget.session.accessToken),
      );
      if (!mounted) return;
      final choices = <String, String>{'': 'Chưa phân ca'};
      for (final shift in shifts) {
        if (shift['id'] is String) {
          choices[shift['id'] as String] = (shift['name'] ?? shift['id'])
              .toString();
        }
      }
      var selected = item['shiftId'] is String ? item['shiftId'] as String : '';
      if (!choices.containsKey(selected)) {
        choices[selected] = 'Ca đang phân ($selected)';
      }
      final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Phân ca làm'),
          content: DropdownButtonFormField<String>(
            initialValue: selected,
            isExpanded: true,
            items: choices.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (v) => selected = v ?? '',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Gán ca'),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
      await _write(
        () => widget.api.assignShift(
          item['id'] as String,
          selected.isEmpty ? null : selected,
          widget.session.accessToken,
        ),
      );
      if (mounted) await _load();
    } on ApiFailure catch (e) {
      if (!mounted) return;
      if (e.status == 401) {
        widget.onUnauthorized();
        return;
      }
      setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Chưa phân được ca làm.');
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      actions: [
        IconButton(
          tooltip: 'Tải lại',
          onPressed: _busy || _mutating ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
        if (_canWrite)
          IconButton(
            tooltip: 'Thêm mới',
            onPressed: _mutating ? null : () => _edit(),
            icon: const Icon(Icons.add),
          ),
      ],
    ),
    body: _busy
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _load, child: const Text('Thử lại')),
                ],
              ),
            ),
          )
        : _items.isEmpty
        ? const Center(child: Text('Chưa có dữ liệu.'))
        : ListView.separated(
            itemCount: _items.length,
            padding: const EdgeInsets.all(16),
            separatorBuilder: (_, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = _items[index];
              final editable = _editable(item);
              final reviewable = _reviewable(item);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (item['name'] ??
                                item['reason'] ??
                                item['username'] ??
                                item['id'] ??
                                'Thông tin')
                            .toString(),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      for (final key in [
                        'employeeName',
                        'reviewerNote',
                        'username',
                        'email',
                        'department',
                        'role',
                        'type',
                        'from',
                        'to',
                        'status',
                        'startMinute',
                        'endMinute',
                        'grace',
                      ])
                        if (item[key] != null)
                          Text(
                            '${_labels[key] ?? key}: ${_display(key, item[key])}',
                          ),
                      if (editable || reviewable)
                        Wrap(
                          children: [
                            if (editable)
                              IconButton(
                                tooltip: 'Sửa',
                                onPressed: _mutating ? null : () => _edit(item),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                            if (editable)
                              IconButton(
                                tooltip: 'Xóa',
                                onPressed: _mutating
                                    ? null
                                    : () => _delete(item),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            if (widget.resource == 'employees' &&
                                widget.session.user.isAdmin)
                              IconButton(
                                tooltip: 'Phân ca',
                                onPressed: _mutating
                                    ? null
                                    : () => _assign(item),
                                icon: const Icon(Icons.event_available),
                              ),
                            if (reviewable) ...[
                              IconButton(
                                tooltip: 'Duyệt',
                                onPressed: _mutating
                                    ? null
                                    : () => _review(item, true),
                                icon: const Icon(Icons.check),
                              ),
                              IconButton(
                                tooltip: 'Từ chối',
                                onPressed: _mutating
                                    ? null
                                    : () => _review(item, false),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
  );
}
