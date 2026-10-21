import 'package:flutter/material.dart';

import '../api/team_api.dart';
import '../auth/auth_session.dart';
import '../resources/resource_page.dart' show parseRecords;

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
      final parsed = value is String ? DateTime.tryParse(value) : null;
      if (parsed == null) return 'Thời gian không hợp lệ';
      final vn = parsed.toUtc().add(const Duration(hours: 7));
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(vn.day)}/${two(vn.month)}/${vn.year} ${two(vn.hour)}:${two(vn.minute)}';
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
      if (response is! Map<String, dynamic> ||
          response['total'] is! int ||
          response['page'] is! int ||
          response['pageSize'] is! int ||
          (response['total'] as int) < 0 ||
          (response['page'] as int) < 1 ||
          (response['pageSize'] as int) < 1) {
        throw const ApiFailure('Chưa đọc được phân trang lịch sử.');
      }
      final data = parseRecords(response['items']);
      setState(() {
        _items = data;
        _page = response['page'] as int;
        _total = response['total'] as int;
        _pageSize = response['pageSize'] as int;
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
  Widget build(BuildContext context) => Scaffold(
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
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (item['employeeName'] ??
                                item['name'] ??
                                'Bản ghi chấm công')
                            .toString(),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
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
                          Text(
                            '${entry.value}: ${_display(entry.key, item[entry.key])}',
                          ),
                    ],
                  ),
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
  );
}
