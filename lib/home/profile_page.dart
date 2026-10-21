import 'package:flutter/material.dart';

import '../api/team_api.dart';
import '../auth/auth_session.dart';
import '../resources/resource_page.dart' show parseRecords;
import '../ui/interior.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.api,
    required this.session,
    required this.onUnauthorized,
    required this.onSignOut,
  });
  final TeamApi api;
  final AuthSession session;
  final VoidCallback onUnauthorized;
  final Future<void> Function() onSignOut;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  AccountUser? _user;
  String? _shift, _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = AccountUser.fromJson(
        await widget.api.me(widget.session.accessToken),
      );
      if (!mounted) return;
      if (user.id != widget.session.user.id ||
          !user.active ||
          user.role.toLowerCase() != widget.session.user.role.toLowerCase()) {
        widget.onUnauthorized();
        return;
      }
      setState(() => _user = user);
      if (user.shiftId != null) {
        final shifts = parseRecords(
          await widget.api.list('shifts', widget.session.accessToken),
        );
        if (!mounted) return;
        _shift =
            shifts
                .where((s) => s['id'] == user.shiftId)
                .firstOrNull?['name']
                ?.toString() ??
            'Ca chưa có trong danh sách';
      }
    } on ApiFailure catch (e) {
      if (!mounted) return;
      if (e.status == 401) {
        widget.onUnauthorized();
        return;
      }
      setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Chưa tải được tài khoản.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => InteriorScope(
    builder: (context) {
      final user = _user ?? widget.session.user;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Tài khoản'),
          actions: [
            IconButton(
              tooltip: 'Tải lại',
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            InteriorHeading(
              user.name.isEmpty ? user.username : user.name,
              eyebrow: 'HỒ SƠ CỦA BẠN',
              subtitle: user.isAdmin
                  ? 'Quản trị viên'
                  : user.isEmployee
                  ? 'Nhân viên'
                  : user.role,
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null) InteriorError(_error!, retry: _load),
            if (!user.isAdmin && !user.isEmployee)
              const Text(
                'Tài khoản này chưa có trang được cấp quyền. Liên hệ quản trị viên.',
              ),
            InteriorPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in {
                    'Tên đăng nhập': user.username,
                    'Email': user.email,
                    'Phòng ban': user.department.isEmpty
                        ? 'Chưa cập nhật'
                        : user.department,
                    'Ca làm': user.shiftId == null
                        ? 'Chưa phân ca'
                        : _shift ?? 'Chưa tải được tên ca',
                    'Trạng thái': user.active
                        ? 'Đang hoạt động'
                        : 'Ngừng hoạt động',
                  }.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(entry.value),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: widget.onSignOut,
              icon: const Icon(Icons.logout),
              label: const Text('Đăng xuất'),
            ),
          ],
        ),
      );
    },
  );
}
