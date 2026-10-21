import 'package:flutter/material.dart';

import '../api/team_api.dart';
import '../auth/auth_session.dart';
import 'record_editor.dart';
import '../ui/interior.dart';

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
    this.header,
    this.reviewOnly = false,
  });
  final Widget? header;
  final bool reviewOnly;
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
  String _query = '', _status = 'all';
  bool get _canWrite =>
      (widget.session.user.isAdmin && !widget.reviewOnly) ||
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
    List<Map<String, dynamic>>? shifts;
    if (widget.resource == 'employees' && initial == null) {
      setState(() => _mutating = true);
      try {
        shifts = parseRecords(
          await widget.api.list('shifts', widget.session.accessToken),
        );
      } on ApiFailure catch (e) {
        if (!mounted) return;
        if (e.status == 401) {
          widget.onUnauthorized();
          return;
        }
        setState(() => _error = e.message);
        return;
      } catch (_) {
        if (mounted) setState(() => _error = 'Chưa tải được ca làm.');
        return;
      } finally {
        if (mounted) setState(() => _mutating = false);
      }
      if (!mounted || widget.session.isExpired) return;
    }
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => InteriorScope(
          builder: (_) => RecordEditor(
            resource: widget.resource,
            initial: initial,
            shiftChoices: shifts,
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
  Widget build(BuildContext context) => InteriorScope(
    builder: (context) {
      final filtered = _items.where((item) {
        if (widget.reviewOnly && !_reviewable(item)) return false;
        if (_status != 'all' && item['status'] != _status) return false;
        return _query.isEmpty ||
            item.values.any((v) => v.toString().toLowerCase().contains(_query));
      }).toList();
      return Scaffold(
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
        body: Column(
          children: [
            if (widget.header != null) widget.header!,
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    InteriorHeading(
                      widget.resource == 'employees'
                          ? 'Đội ngũ của bạn'
                          : widget.resource == 'shifts'
                          ? 'Nhịp làm việc'
                          : widget.reviewOnly
                          ? 'Chờ bạn quyết định'
                          : 'Yêu cầu của bạn',
                      subtitle: widget.resource == 'requests'
                          ? 'Theo dõi nội dung, trạng thái và phản hồi.'
                          : 'Quản lý thông tin trong cùng một nơi.',
                    ),
                    TextField(
                      onChanged: (v) =>
                          setState(() => _query = v.trim().toLowerCase()),
                      decoration: const InputDecoration(
                        labelText: 'Tìm kiếm',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (widget.resource == 'requests' && !widget.reviewOnly)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final v in [
                              'all',
                              'pending',
                              'approved',
                              'rejected',
                            ])
                              ChoiceChip(
                                label: Text(
                                  v == 'all' ? 'Tất cả' : requestStatus(v),
                                ),
                                selected: _status == v,
                                onSelected: (_) => setState(() => _status = v),
                              ),
                          ],
                        ),
                      ),
                    if (_busy) const LinearProgressIndicator(),
                    if (_error != null) InteriorError(_error!, retry: _load),
                    if (!_busy && _error == null && filtered.isEmpty)
                      InteriorPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.inbox_outlined, size: 32),
                            const SizedBox(height: 16),
                            Text(
                              _query.isNotEmpty
                                  ? 'Không tìm thấy kết quả.'
                                  : widget.reviewOnly
                                  ? 'Không có yêu cầu cần duyệt.'
                                  : 'Chưa có dữ liệu.',
                            ),
                            if (_canWrite)
                              TextButton(
                                onPressed: () => _edit(),
                                child: const Text('Tạo bản ghi đầu tiên'),
                              ),
                          ],
                        ),
                      ),
                    if (!_busy)
                      for (final item in filtered)
                        InteriorPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.resource == 'requests') ...[
                                StatusLabel(requestStatus(item['status'])),
                                const SizedBox(height: 16),
                              ],
                              Text(
                                (item['name'] ??
                                        item['reason'] ??
                                        item['username'] ??
                                        item['id'] ??
                                        'Thông tin')
                                    .toString(),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 12),
                              if (widget.resource == 'employees') ...[
                                Text(
                                  '${item['department'] ?? 'Chưa cập nhật phòng ban'} · ${item['username'] ?? 'Chưa có tên đăng nhập'}',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ExpansionTile(
                                  tilePadding: EdgeInsets.zero,
                                  childrenPadding: EdgeInsets.zero,
                                  shape: const Border(),
                                  collapsedShape: const Border(),
                                  title: const Text('Thông tin chi tiết'),
                                  children: [
                                    for (final key in ['email', 'role'])
                                      if (item[key] != null)
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            '${_labels[key]}: ${item[key]}',
                                          ),
                                        ),
                                    if (item.containsKey('active'))
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          item['active'] == true
                                              ? 'Đang hoạt động'
                                              : 'Ngừng hoạt động',
                                        ),
                                      ),
                                  ],
                                ),
                              ] else if (widget.resource == 'shifts') ...[
                                Text(
                                  '${minuteTime(item['startMinute'])} — ${minuteTime(item['endMinute'])}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Cho phép trễ: ${item['grace'] ?? 'Chưa rõ'} phút',
                                ),
                              ] else ...[
                                for (final key in [
                                  'employeeName',
                                  'type',
                                  'from',
                                  'to',
                                  'reviewerNote',
                                ])
                                  if (item[key] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Text(
                                        '${_labels[key]}: ${_display(key, item[key])}',
                                      ),
                                    ),
                              ],
                              if (_editable(item) || _reviewable(item)) ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 8,
                                  children: [
                                    if (_editable(item))
                                      IconButton(
                                        tooltip: 'Sửa',
                                        onPressed: _mutating
                                            ? null
                                            : () => _edit(item),
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                    if (_editable(item))
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
                                    if (_reviewable(item)) ...[
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
                            ],
                          ),
                        ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
