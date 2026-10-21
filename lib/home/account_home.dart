import 'package:flutter/material.dart';

import '../api/team_api.dart';
import '../auth/auth_session.dart';
import '../attendance/history_page.dart';
import '../resources/resource_page.dart';
import '../ui/interior.dart';
import 'office_page.dart';
import 'overview_page.dart';
import 'profile_page.dart';

class AccountHome extends StatefulWidget {
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
  State<AccountHome> createState() => _AccountHomeState();
}

class _AccountHomeState extends State<AccountHome> {
  int _index = 0;
  bool _shifts = false;
  void _select(int value) => setState(() => _index = value);
  @override
  Widget build(BuildContext context) => InteriorScope(
    builder: (context) {
      final admin = widget.session.user.isAdmin;
      final known = admin || widget.session.user.isEmployee;
      final labels = admin
          ? ['Tổng quan', 'Nhân sự', 'Duyệt đơn', 'Thiết lập']
          : ['Hôm nay', 'Lịch sử', 'Đơn', 'Tài khoản'];
      final icons = admin
          ? [
              Icons.grid_view_rounded,
              Icons.people_outline,
              Icons.fact_check_outlined,
              Icons.tune,
            ]
          : [
              Icons.today_outlined,
              Icons.history,
              Icons.edit_calendar_outlined,
              Icons.person_outline,
            ];
      final profile = ProfilePage(
        api: widget.api,
        session: widget.session,
        onUnauthorized: widget.onUnauthorized,
        onSignOut: widget.onSignOut,
      );
      Widget resource(
        String kind,
        String title, {
        Widget? header,
        bool reviewOnly = false,
      }) => ResourcePage(
        key: ValueKey(kind),
        api: widget.api,
        session: widget.session,
        resource: kind,
        title: title,
        onUnauthorized: widget.onUnauthorized,
        header: header,
        reviewOnly: reviewOnly,
      );
      Widget history() => HistoryPage(
        api: widget.api,
        session: widget.session,
        onUnauthorized: widget.onUnauthorized,
      );
      final Widget body = !known
          ? profile
          : switch (_index) {
              0 => OverviewPage(
                api: widget.api,
                session: widget.session,
                onUnauthorized: widget.onUnauthorized,
                onSelect: _select,
                onHistory: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => history())),
              ),
              1 =>
                admin
                    ? resource(
                        _shifts ? 'shifts' : 'employees',
                        _shifts ? 'Quản lý ca làm' : 'Quản lý nhân viên',
                        header: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                          child: Wrap(
                            spacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('Nhân viên'),
                                selected: !_shifts,
                                onSelected: (_) =>
                                    setState(() => _shifts = false),
                              ),
                              ChoiceChip(
                                label: const Text('Ca làm'),
                                selected: _shifts,
                                onSelected: (_) =>
                                    setState(() => _shifts = true),
                              ),
                            ],
                          ),
                        ),
                      )
                    : history(),
              2 => resource(
                'requests',
                admin ? 'Yêu cầu nhân viên' : 'Yêu cầu của tôi',
                reviewOnly: admin,
              ),
              _ =>
                admin
                    ? OfficePage(
                        api: widget.api,
                        session: widget.session,
                        onUnauthorized: widget.onUnauthorized,
                      )
                    : profile,
            };
      final wide = MediaQuery.sizeOf(context).width >= 840;
      return PopScope<void>(
        canPop: _index == 0,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _index != 0) _select(0);
        },
        child: Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Icon(
                  Icons.schedule,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Tai Attendance',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Tài khoản',
                onPressed: () =>
                    Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => profile)),
                icon: const Icon(Icons.account_circle_outlined),
              ),
              IconButton(
                tooltip: 'Đăng xuất',
                onPressed: widget.onSignOut,
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Row(
              children: [
                if (known && wide)
                  NavigationRail(
                    selectedIndex: _index,
                    onDestinationSelected: _select,
                    labelType: NavigationRailLabelType.all,
                    destinations: List.generate(
                      4,
                      (i) => NavigationRailDestination(
                        icon: Icon(icons[i]),
                        label: Text(labels[i]),
                      ),
                    ),
                  ),
                Expanded(child: body),
              ],
            ),
          ),
          bottomNavigationBar: known && !wide
              ? NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: _select,
                  destinations: List.generate(
                    4,
                    (i) => NavigationDestination(
                      icon: Icon(icons[i]),
                      label: labels[i],
                    ),
                  ),
                )
              : null,
        ),
      );
    },
  );
}
