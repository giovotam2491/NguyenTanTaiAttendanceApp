# Interior redesign — Implementation Plan

> Execute inline with executing-plans; approved design is binding. User approved implementation on 22/10/2026 after asking for blue button highlights.

Goal: implement the approved post-login employee/admin UI while preserving auth, API contracts and data integrity.
Architecture: reuse pages and TeamApi, one role-aware shell, page-local state and shared interior widgets/theme. No dependency, nested Navigator or backend change.
Spec: interior-design-approved.md plus blue selected/pressed/focus states from approved prototype.

## Constraints and review focus

AuthForm/OtpScreen/AppTheme remain unchanged. User/session/logout/401 rules and pending punch key retention survive every route/tab change. Empty/error is not zero; partial attendance pages must never become global totals. Open shift uses latest scoped attendance, including overnight workDate. All controls 48dp, body16/label14, 200% text, light/dark and reduced motion. No live credentials, backend mutations, push or deployment.

## Task 1 — Interior shell and components

Files: lib/ui/interior.dart, lib/home/account_home.dart, test/interior_shell_test.dart; update dashboard/session host assertions for the new information architecture.
- [ ] RED: employee 4 destinations; admin overview/people/reviews/settings; unknown role only account; tab Back returns home; 401/logout removes protected content.
- [ ] Implement scoped theme, heading/panel/status/error helpers and highlighted buttons. Lazy tab bodies, bottom navigation for phones, labelled rail >=840. Resource pages may embed beneath shell brand, retain full standalone support. Keep root Navigator and session host.
- [ ] GREEN tests before next task.

## Task 2 — Live dashboards and account

Files: lib/home/overview_page.dart, lib/home/profile_page.dart, lib/attendance/attendance_data.dart, test/overview_test.dart.
- [ ] RED: scoped latest open/closed/no record, overnight, malformed/failed block, missing assignment, counts from lists, unknown vs zero, late completion after disposal.
- [ ] Employee gets me/shifts/requests and latest attendance pageSize1 without date restriction (an open record must be latest by backend invariants). Admin gets employee/shifts/requests/office. Each block reports its own failure and retains old data on refresh. Me id/role/active must match current session before enabling actions. Pending session punch gets a continuation action.
- [ ] Profile shows current account/assignment, refreshes me and supports logout. No fake figures.
- [ ] GREEN targeted tests.

## Task 3 — Employee pages

Files: punch_page.dart, history_page.dart, resource_page.dart, record_editor.dart; test/attendance/history/request rules and lifecycle suites.
- [ ] RED: correct initial in/out intent with pending override, midnight and non-null checkout, filtering/detail preserves values, list search and request ownership unaffected.
- [ ] Redesign QR acquisition + GPS disclosure + confirmation, existing scanner/manual paste, safe retry, typed payload unchanged. History two-line records with full detail, real paging and date filters. Requests status filters, cards/readable notes and grouped form. Scoped theme for every pushed route.
- [ ] GREEN tests including all existing lifecycle/punch cases.

## Task 4 — Administration

Files: resource_page.dart, record_editor.dart, office_page.dart, people_page.dart; test/resource/request/office tests.
- [ ] RED: employees/shift tabs, search loaded lists, pending review queue, mandatory note/version, shift picker uses server names, QR expiry.
- [ ] Restyle lists and forms; full CRUD/assign/review remains. Group employee fields; pick shift by name rather than requiring UUID where API data is available. Settings shows office/QR, expired state and editing. No silent defaults on missing data.
- [ ] GREEN tests, no auth/transport changes beyond shared pagination extraction.

## Task 5 — Verification and delivery

- [ ] Full flutter test, analyze, format and diff checks. Auth source diff must be empty.
- [ ] Widget layout at 360x800 / 800x360 / tablet with text200%, light/dark and reduced motion. Real visual inspection using CUA on a debug-only fixture preview, never production login bypass.
- [ ] One fresh read-only final code review; important issues get regression RED/GREEN fixes and whole suite. Minor issues recorded.
- [ ] Build APK, copy outputs and report limitations. Commit reviewed local feature branch if clean; do not push without user request.
