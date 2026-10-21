import 'package:flutter/material.dart';

import '../api/team_api.dart';
import '../auth/auth_session.dart';
import '../resources/resource_page.dart';
import '../attendance/punch_page.dart';
import '../attendance/history_page.dart';
import 'office_page.dart';

class AccountHome extends StatelessWidget {
  const AccountHome({
    super.key,
    required this.api,
    required this.session,
    required this.onSignOut,
    required this.onUnauthorized,
  });
  final TeamApi api;
  final AuthSession session;
  final Future<void> Function() onSignOut;
  final VoidCallback onUnauthorized;
  @override
  Widget build(BuildContext context) {
    final user = session.user;
    final known = user.isAdmin || user.isEmployee;
    void open(String resource, String title) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ResourcePage(
          api: api,
          session: session,
          resource: resource,
          title: title,
          onUnauthorized: onUnauthorized,
        ),
      ),
    );
    Widget tile(String text, IconData icon, VoidCallback action) => Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Icon(icon),
        title: Text(text),
        trailing: const Icon(Icons.chevron_right),
        onTap: action,
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          user.isAdmin
              ? 'Quản trị'
              : user.isEmployee
              ? 'Dashboard nhân viên'
              : 'Tài khoản',
        ),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: onSignOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Chào ${user.name.isEmpty ? user.username : user.name}.',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 10),
            Text('${user.username} · ${user.role}'),
            if (user.email.isNotEmpty) Text(user.email),
            const SizedBox(height: 24),
            if (user.isAdmin) ...[
              tile(
                'Quản lý nhân viên',
                Icons.people_outline,
                () => open('employees', 'Quản lý nhân viên'),
              ),
              tile(
                'Quản lý ca làm',
                Icons.schedule,
                () => open('shifts', 'Quản lý ca làm'),
              ),
              tile(
                'Yêu cầu nhân viên',
                Icons.fact_check_outlined,
                () => open('requests', 'Yêu cầu nhân viên'),
              ),
            ],
            if (user.isEmployee)
              tile(
                'Yêu cầu của tôi',
                Icons.edit_calendar_outlined,
                () => open('requests', 'Yêu cầu của tôi'),
              ),
            if (user.isAdmin)
              tile(
                'Địa điểm và QR',
                Icons.location_on_outlined,
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => OfficePage(
                      api: api,
                      session: session,
                      onUnauthorized: onUnauthorized,
                    ),
                  ),
                ),
              ),
            if (user.isEmployee)
              tile(
                'Chấm công',
                Icons.qr_code_scanner,
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PunchPage(
                      api: api,
                      session: session,
                      onUnauthorized: onUnauthorized,
                    ),
                  ),
                ),
              ),
            if (known)
              tile(
                'Lịch sử chấm công',
                Icons.history,
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => HistoryPage(
                      api: api,
                      session: session,
                      onUnauthorized: onUnauthorized,
                    ),
                  ),
                ),
              ),
            if (!known)
              const Text(
                'Tài khoản này chưa có trang được cấp quyền. Liên hệ quản trị viên.',
              ),
          ],
        ),
      ),
    );
  }
}
