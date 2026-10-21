import 'package:flutter/material.dart';

import '../api/team_api.dart';
import '../auth/auth_session.dart';
import '../attendance/attendance_data.dart';
import '../attendance/punch_page.dart';
import '../resources/resource_page.dart' show parseRecords;
import '../ui/interior.dart';

class OverviewPage extends StatefulWidget {
  const OverviewPage({
    super.key,
    required this.api,
    required this.session,
    required this.onUnauthorized,
    required this.onSelect,
    required this.onHistory,
  });
  final TeamApi api;
  final AuthSession session;
  final VoidCallback onUnauthorized, onHistory;
  final ValueChanged<int> onSelect;
  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  final _data = <String, Object>{}, _errors = <String, String>{};
  bool _busy = true;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final gen = ++_generation;
    setState(() {
      _busy = true;
      _errors.clear();
    });
    final token = widget.session.accessToken;
    Future<void> block(
      String key,
      Future<Object?> Function() fetch,
      Object Function(Object?) parse,
    ) async {
      try {
        final result = parse(await fetch());
        if (!mounted || gen != _generation || widget.session.isExpired) return;
        setState(() => _data[key] = result);
      } on ApiFailure catch (e) {
        if (!mounted || gen != _generation) return;
        if (e.status == 401) {
          widget.onUnauthorized();
          return;
        }
        setState(() => _errors[key] = e.message);
      } catch (_) {
        if (mounted && gen == _generation) {
          setState(() => _errors[key] = 'Chưa đọc được dữ liệu từ máy chủ.');
        }
      }
    }

    await Future.wait([
      block('shifts', () => widget.api.list('shifts', token), parseRecords),
      block('requests', () => widget.api.list('requests', token), parseRecords),
      if (widget.session.user.isAdmin) ...[
        block(
          'employees',
          () => widget.api.list('employees', token),
          parseRecords,
        ),
        block('office', () => widget.api.office(token), (v) {
          if (v is! Map<String, dynamic> || v['configured'] is! bool) {
            throw const ApiFailure('Chưa đọc được địa điểm.');
          }
          return v;
        }),
      ] else ...[
        block('me', () => widget.api.me(token), (v) {
          final me = AccountUser.fromJson(v);
          if (me.id != widget.session.user.id ||
              me.role.toLowerCase() != widget.session.user.role.toLowerCase() ||
              !me.active) {
            throw const ApiFailure(
              'Tài khoản đã thay đổi. Hãy đăng nhập lại.',
              status: 401,
            );
          }
          return me;
        }),
        block('attendance', () => widget.api.attendance(token, pageSize: 1), (
          v,
        ) {
          final slice = AttendanceSlice(v);
          for (final row in slice.items) {
            if (row['employeeId'] != widget.session.user.id ||
                row['checkIn'] is! String ||
                DateTime.tryParse(row['checkIn']) == null ||
                !row.containsKey('checkOut') ||
                (row['checkOut'] != null &&
                    (row['checkOut'] is! String ||
                        DateTime.tryParse(row['checkOut']) == null))) {
              throw const ApiFailure('Bản ghi ca gần nhất không hợp lệ.');
            }
          }
          return slice;
        }),
      ],
    ]);
    if (mounted && gen == _generation) setState(() => _busy = false);
  }

  List<Map<String, dynamic>>? records(String key) =>
      _data[key] as List<Map<String, dynamic>>?;
  Widget failure(String key) => _errors[key] != null
      ? InteriorError(
          '${_errors[key]}${_data.containsKey(key) ? ' Đang hiển thị dữ liệu lần tải trước.' : ''}',
          retry: _load,
        )
      : const SizedBox.shrink();
  Widget metric(String key, String label, int tab) => InteriorPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 8),
        Text(
          records(key)?.length.toString() ?? '—',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        failure(key),
        TextButton.icon(
          onPressed: () => widget.onSelect(tab),
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Xem danh sách'),
        ),
      ],
    ),
  );
  Future<void> _punch(bool out) async {
    if (widget.session.isExpired) {
      widget.onUnauthorized();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PunchPage(
          api: widget.api,
          session: widget.session,
          onUnauthorized: widget.onUnauthorized,
          initialCheckOut: out,
        ),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final admin = widget.session.user.isAdmin;
    final user = _data['me'] as AccountUser? ?? widget.session.user;
    final shifts = records('shifts');
    Map<String, dynamic>? shift;
    for (final s in shifts ?? <Map<String, dynamic>>[]) {
      if (s['id'] == user.shiftId) shift = s;
    }
    final slice = _data['attendance'] as AttendanceSlice?;
    final latest = slice?.items.firstOrNull;
    final open = latest != null && latest['checkOut'] == null;
    final requests = records('requests');
    final pending = requests
        ?.where(
          (r) =>
              r['status'] == 'pending' &&
              (admin ? r['employeeId'] != user.id : r['employeeId'] == user.id),
        )
        .toList();
    final canPunch =
        !_busy &&
        _errors['me'] == null &&
        _data['me'] != null &&
        _errors['attendance'] == null &&
        slice != null &&
        (open || (shift != null && _errors['shifts'] == null));
    return Scaffold(
      appBar: AppBar(
        title: Text(admin ? 'Tổng quan' : 'Hôm nay'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            InteriorHeading(
              'Chào ${user.name.isEmpty ? user.username : user.name}.',
              eyebrow: admin ? 'KHÔNG GIAN QUẢN TRỊ' : 'SẴN SÀNG CHO NGÀY MỚI',
              subtitle: admin
                  ? 'Các việc cần bạn quyết định hôm nay.'
                  : 'Ca làm, chấm công và yêu cầu của bạn.',
            ),
            if (_busy) const LinearProgressIndicator(),
            if (admin) ...[
              InteriorPanel(
                tonal: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CẦN XỬ LÝ', style: TextStyle(fontSize: 14)),
                    const SizedBox(height: 12),
                    Text(
                      pending == null
                          ? 'Chưa tải được yêu cầu'
                          : '${pending.length} yêu cầu chờ duyệt',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    failure('requests'),
                    for (final r in (pending ?? []).take(3))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          '${r['employeeName'] ?? 'Nhân viên'} · ${r['type'] ?? 'Yêu cầu'}',
                        ),
                      ),
                    FilledButton(
                      onPressed: () => widget.onSelect(2),
                      child: const Text('Mở danh sách duyệt'),
                    ),
                  ],
                ),
              ),
              LayoutBuilder(
                builder: (c, b) => b.maxWidth > 540
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: metric(
                              'employees',
                              'Nhân sự trong hệ thống',
                              1,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: metric('shifts', 'Ca làm đã thiết lập', 1),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          metric('employees', 'Nhân sự trong hệ thống', 1),
                          metric('shifts', 'Ca làm đã thiết lập', 1),
                        ],
                      ),
              ),
              InteriorPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('NƠI LÀM VIỆC', style: TextStyle(fontSize: 14)),
                    const SizedBox(height: 12),
                    Text(
                      (_data['office'] as Map?)?['configured'] == false
                          ? 'Chưa cấu hình địa điểm'
                          : ((_data['office'] as Map?)?['name'] ??
                                    'Chưa tải được địa điểm')
                                .toString(),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    failure('office'),
                    TextButton.icon(
                      onPressed: () => widget.onSelect(3),
                      icon: const Icon(Icons.qr_code),
                      label: const Text('Địa điểm và QR'),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: widget.onHistory,
                icon: const Icon(Icons.history),
                label: const Text('Lịch sử chấm công'),
              ),
            ] else ...[
              failure('me'),
              InteriorPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: StatusLabel(
                        open ? 'Đang trong ca' : 'Ca làm của bạn',
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      (open ? latest['shiftName'] : shift?['name'])
                              ?.toString() ??
                          (user.shiftId == null
                              ? 'Chưa được phân ca'
                              : 'Chưa tải được ca làm'),
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 8),
                    if (shift != null)
                      Text(
                        '${minuteTime(shift['startMinute'])} — ${minuteTime(shift['endMinute'])}',
                      ),
                    failure('shifts'),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 32,
                      runSpacing: 16,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Vào ca'),
                            Text(
                              attendanceTime(latest?['checkIn'], date: false),
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Ra ca'),
                            Text(
                              attendanceTime(latest?['checkOut'], date: false),
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (latest != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'Ngày làm: ${latest['workDate'] ?? 'Chưa rõ'} · Giờ Việt Nam',
                        ),
                      ),
                    const SizedBox(height: 24),
                    if (_errors['attendance'] != null) ...[
                      const Text('Chưa tải được ca gần nhất'),
                      failure('attendance'),
                    ] else
                      FilledButton.icon(
                        onPressed: canPunch ? () => _punch(open) : null,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: Text(
                          open ? 'Chấm công ra ca' : 'Chấm công vào ca',
                        ),
                      ),
                    if (user.shiftId == null && !open)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text('Liên hệ quản trị viên để được phân ca.'),
                      ),
                    if (widget.session.pendingPunch != null) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Có thao tác chưa xác định kết quả. Kiểm tra lịch sử trước khi gửi lại.',
                      ),
                      OutlinedButton(
                        onPressed: () => _punch(widget.session.pendingCheckOut),
                        child: const Text('Tiếp tục thao tác trước'),
                      ),
                    ],
                  ],
                ),
              ),
              InteriorPanel(
                tonal: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pending == null
                          ? 'Yêu cầu của bạn'
                          : '${pending.length} đơn đang chờ duyệt',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    failure('requests'),
                    TextButton.icon(
                      onPressed: () => widget.onSelect(2),
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Xem yêu cầu'),
                    ),
                  ],
                ),
              ),
              InteriorPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('GẦN ĐÂY', style: TextStyle(fontSize: 14)),
                    const SizedBox(height: 12),
                    if (latest != null)
                      Text(
                        '${latest['shiftName'] ?? 'Ca làm'} · ${attendanceTime(latest['checkIn'])}',
                      )
                    else
                      Text(
                        slice == null
                            ? 'Chưa tải được lịch sử'
                            : 'Chưa có bản ghi chấm công.',
                      ),
                    TextButton(
                      onPressed: () => widget.onSelect(1),
                      child: const Text('Xem toàn bộ lịch sử'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
