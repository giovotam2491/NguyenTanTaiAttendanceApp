import 'package:flutter/material.dart';

import '../ui/interior.dart';

import '../api/team_api.dart';
import '../auth/auth_session.dart';
import 'attendance_data.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    super.key,
    required this.api,
    required this.session,
    required this.onUnauthorized,
  });
  final TeamApi api;
  final AuthSession session;
  final VoidCallback onUnauthorized;
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  DateTime _from = DateTime.now().subtract(const Duration(days: 30)),
      _to = DateTime.now();
  List<Map<String, dynamic>> _items = [];
  bool _busy = true;
  String? _error;
  int _page = 1, _generation = 0, _total = 0, _pageSize = 50;
  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  @override
  void initState() {
    super.initState();
    _load();
  }

  String _display(String key, Object? value) {
    if (key == 'lateMinutes') return '$value phút';
    if (['checkIn', 'checkOut', 'scheduledEnd'].contains(key)) {
      return attendanceTime(value);
    }
    return value.toString();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await widget.api.attendance(
        widget.session.accessToken,
        from: _date(_from),
        to: _date(_to),
        page: _page,
      );
      if (!mounted || generation != _generation) return;
      final slice = AttendanceSlice(response);
      setState(() {
        _items = slice.items;
        _page = slice.page;
        _total = slice.total;
        _pageSize = slice.pageSize;
      });
    } on ApiFailure catch (e) {
      if (!mounted || generation != _generation) return;
      if (e.status == 401) {
        widget.onUnauthorized();
        return;
      }
      setState(() => _error = e.message);
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = 'Chưa tải được lịch sử chấm công.');
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _pick(bool from) async {
    final result = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (from) {
        _from = result;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = result;
        if (_from.isAfter(_to)) _from = _to;
      }
      _page = 1;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) => InteriorScope(
    builder: (context) => Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử chấm công'),
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
          padding: const EdgeInsets.all(20),
          children: [
            const InteriorHeading(
              'Dấu chân ca làm',
              subtitle: 'Thời gian hiển thị theo múi giờ Việt Nam.',
            ),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _busy ? null : () => _pick(true),
                  child: Text('Từ ${_date(_from)}'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : () => _pick(false),
                  child: Text('Đến ${_date(_to)}'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_busy)
              const Center(child: CircularProgressIndicator())
            else if (_error != null) ...[
              Text(_error!),
              FilledButton(onPressed: _load, child: const Text('Thử lại')),
            ] else if (_items.isEmpty)
              const Text('Chưa có bản ghi trong khoảng ngày này.')
            else
              for (final item in _items)
                Card(
                  child: ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    tilePadding: const EdgeInsets.all(20),
                    childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    title: Text(
                      (item['shiftName'] ?? 'Ca làm').toString(),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${item['employeeName'] ?? 'Nhân viên'} · ${item['workDate'] ?? 'Chưa rõ ngày'}\n${attendanceTime(item['checkIn'], date: false)} → ${attendanceTime(item['checkOut'], date: false)}',
                      ),
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final entry in {
                              'workDate': 'Ngày làm',
                              'shiftName': 'Ca làm',
                              'checkIn': 'Vào ca',
                              'checkOut': 'Ra ca',
                              'scheduledEnd': 'Kết thúc dự kiến',
                              'lateMinutes': 'Trễ',
                              'id': 'Mã bản ghi',
                            }.entries)
                              if (item[entry.key] != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    '${entry.value}: ${_display(entry.key, item[entry.key])}',
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: _busy || _page <= 1
                      ? null
                      : () {
                          setState(() => _page--);
                          _load();
                        },
                  child: const Text('Trang trước'),
                ),
                Text('Trang $_page'),
                OutlinedButton(
                  onPressed:
                      _busy || _error != null || _page * _pageSize >= _total
                      ? null
                      : () {
                          setState(() => _page++);
                          _load();
                        },
                  child: const Text('Trang sau'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
