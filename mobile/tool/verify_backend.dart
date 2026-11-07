// API smoke test for the TVV mobile app's data layer.
//
// Runs the app's REAL ApiClient + repositories (pure Dart, no Flutter needed) against a Django backend and checks
// that every endpoint the app uses answers in the shape the app expects, that each role is allowed / refused what
// it should be, and that JWT refresh (with rotation), single-flight refresh, session expiry and cold-start retry work.
//
//   dart tool/verify_backend.dart
//
// Environment variables:
//   API_BASE_URL   default http://127.0.0.1:8000/api
//   STUDENT_USER / STUDENT_PASS     a student account
//   TEACHER_USER / TEACHER_PASS     a teacher account
//   ADMIN_USER   / ADMIN_PASS       the Super Admin (e-mail + password)
//   ALLOW_WRITES=1                  ALSO run create/update/delete checks. Use ONLY on a throw-away test database.
//
// Without ALLOW_WRITES the script is read-only (it still logs in and ticks nothing).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../lib/core/api_client.dart';
import '../lib/core/api_exception.dart';
import '../lib/core/json.dart';
import '../lib/core/token_store.dart';
import '../lib/data/attendance_stats.dart';
import '../lib/data/models/academics.dart';
import '../lib/data/models/user.dart';
import '../lib/data/repositories/academics_repository.dart';
import '../lib/data/repositories/admin_repository.dart';
import '../lib/data/repositories/auth_repository.dart';
import '../lib/data/repositories/content_repository.dart';
import '../lib/data/repositories/profile_repository.dart';
import '../lib/ui/format.dart';

int _passed = 0;
final List<String> _failures = [];

void ok(bool cond, String name, [String detail = '']) {
  if (cond) {
    _passed++;
    stdout.writeln('  PASS  $name');
  } else {
    _failures.add(name);
    stdout.writeln('  FAIL  $name ${detail.isEmpty ? '' : '-> $detail'}');
  }
}

Future<void> expectError(String name, Future<Object?> Function() run, ApiErrorKind kind) async {
  try {
    await run();
    ok(false, name, 'expected ${kind.name} but the call succeeded');
  } on ApiException catch (e) {
    ok(e.kind == kind, name, 'got ${e.kind.name} (${e.status}): ${e.message}');
  } catch (e) {
    ok(false, name, 'unexpected ${e.runtimeType}: $e');
  }
}

void section(String s) => stdout.writeln('\n== $s');

String env(String k, [String d = '']) => Platform.environment[k] ?? d;

class Rig {
  Rig(String base) {
    store = MemoryTokenStore();
    api = ApiClient(baseUrl: base, tokens: store, retryDelays: const [Duration(milliseconds: 100), Duration(milliseconds: 200)]);
    api.onSessionExpired = () => expired++;
    auth = AuthRepository(api);
    academics = AcademicsRepository(api);
    content = ContentRepository(api);
    profile = ProfileRepository(api);
    admin = AdminRepository(api);
  }
  late final MemoryTokenStore store;
  late final ApiClient api;
  late final AuthRepository auth;
  late final AcademicsRepository academics;
  late final ContentRepository content;
  late final ProfileRepository profile;
  late final AdminRepository admin;
  int expired = 0;
}

void _logicChecks() {
  section('App logic (no server)');
  AttendanceRecord rec(int d, AttendanceStatus st) => AttendanceRecord(id: '$d', studentId: 's', date: DateTime(2026, 11, d), status: st);
  final five = [for (var i = 1; i <= 5; i++) rec(i, i <= 4 ? AttendanceStatus.present : AttendanceStatus.absent)];
  final a = AttendanceSummary.of(five, workingDays: 200, minPercent: 75);
  ok(a.present == 4 && a.absent == 1 && a.marked == 5, 'attendance counts');
  ok(a.countLabel == '4 of 200', 'attendance label uses working days', a.countLabel);
  ok((a.percentOfMarked! - 80).abs() < 1e-9 && a.tone == 'good', '80% of days held is "good" against a 75% minimum');
  ok((a.ringPercent - 2).abs() < 1e-9, 'ring shows share of the whole session (4/200 = 2%)', '${a.ringPercent}');
  final b = AttendanceSummary.of(
      five.take(3).toList()
        ..add(rec(9, AttendanceStatus.absent))
        ..add(rec(10, AttendanceStatus.absent))
        ..add(rec(11, AttendanceStatus.absent)),
      minPercent: 75);
  ok(b.countLabel == '3 of 6' && b.tone == 'bad', 'no working days -> "present of marked"; 50% is "bad"', '${b.countLabel} ${b.tone}');
  final w = AttendanceSummary.of(
      five.take(3).toList()
        ..add(rec(9, AttendanceStatus.absent))
        ..add(rec(10, AttendanceStatus.absent)),
      minPercent: 75);
  ok(w.tone == 'warn', '60% (minimum minus 15) is "warn", the same bands as the website', w.tone);
  ok(AttendanceSummary.of(const [], minPercent: 75).tone == 'accent', 'no data -> neutral tone');

  final sessions = [
    AcademicSession(id: 'old', label: '2025', startDate: DateTime(2025, 1, 1)),
    AcademicSession(id: 'cur', label: '2026', isCurrent: true, startDate: DateTime(2026, 1, 1)),
  ];
  ResultRow r(String sess, String term, double m) =>
      ResultRow(id: '$sess$term$m', studentId: 's', subjectId: 'x', sessionId: sess, term: term, marks: m, fullMarks: 100);
  final groups =
      ResultGroup.group([r('old', 'SEM1', 50), r('cur', 'SEM1', 80), r('cur', 'SEM2', 90), r('cur', 'SEM2', 70)], sessions: sessions);
  ok(groups.length == 3 && groups.first.sessionId == 'cur' && groups.first.term == 'SEM2',
      'results: current session first, later term first');
  ok(groups.first.total == 160 && groups.first.fullTotal == 200 && (groups.first.percent - 80).abs() < 1e-9,
      'results totals and percentage');

  ok(
      fmtTime('10:00:00') == '10:00 AM' &&
          fmtTime('00:05') == '12:05 AM' &&
          fmtTime('13:45:00') == '1:45 PM' &&
          fmtTime('12:00') == '12:00 PM',
      'time formatting (12-hour)');
  ok(fmtDate(DateTime(2026, 11, 5)) == '5 Nov 2026', 'date formatting');
  ok(marks(91.0) == '91' && marks(41.5) == '41.5', 'marks formatting');
  ok(isoDate(DateTime(2026, 3, 7)) == '2026-03-07', 'ISO date for the API');
  ok(dateOnlyOrNull({'d': '2026-11-05'}, 'd') == DateTime(2026, 11, 5), 'API dates parse without time-zone shifts');
  ok(dbl({'m': '91.00'}, 'm') == 91.0 && intOr({'n': '7'}, 'n') == 7, 'decimal strings and numeric strings parse');
  ok(str({'x': null}, 'x') == '' && asJsonList('nope').isEmpty, 'null / wrong-type JSON is tolerated');
  final lastDay = DateTime(2026, 12, 31);
  ok(
      relativeDay(DateTime.now()) == 'Today' &&
          relativeDay(DateTime.now().add(const Duration(days: 1))) == 'Tomorrow' &&
          lastDay.year == 2026,
      'relative day labels');
}

Future<void> main() async {
  final base = env('API_BASE_URL', 'http://127.0.0.1:8000/api');
  final writes = env('ALLOW_WRITES') == '1';
  stdout.writeln('TVV mobile data-layer check against $base (writes ${writes ? 'ON' : 'off'})');

  _logicChecks();
  await _offlineChecks();
  await _studentChecks(base, writes);
  await _teacherChecks(base, writes);
  await _adminChecks(base, writes);

  stdout.writeln('\n----------------------------------------');
  stdout.writeln('$_passed passed, ${_failures.length} failed');
  if (_failures.isNotEmpty) {
    for (final f in _failures) {
      stdout.writeln('  - $f');
    }
    exit(1);
  }
}

// -------------------------------------------------------------- no backend needed
Future<void> _offlineChecks() async {
  section('Network behaviour (local fake server)');

  // 1) A server that answers 503 twice (Render waking up) then 200: GET must retry and succeed.
  var hits = 0;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) async {
    hits++;
    if (req.uri.path.endsWith('/flaky/') && hits <= 2) {
      req.response.statusCode = 503;
      req.response.write('<html>starting</html>');
    } else if (req.uri.path.endsWith('/html500/')) {
      req.response.statusCode = 500;
      req.response.write('<html>boom</html>');
    } else if (req.uri.path.endsWith('/throttled/')) {
      req.response.statusCode = 429;
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode({'detail': 'Request was throttled. Expected available in 30 seconds.'}));
    } else if (req.uri.path.endsWith('/validation/')) {
      req.response.statusCode = 400;
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode({
        'username': ['A user with that username already exists.'],
        'password': ['Too short.']
      }));
    } else {
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode({'ok': true, 'results': [], 'next': null}));
    }
    await req.response.close();
  });
  final fake = ApiClient(
    baseUrl: 'http://127.0.0.1:${server.port}/api',
    tokens: MemoryTokenStore(),
    retryDelays: const [Duration(milliseconds: 20), Duration(milliseconds: 20), Duration(milliseconds: 20)],
  );
  final r = await fake.getMap('/flaky/', auth: false);
  ok(r['ok'] == true && hits == 3, 'GET retries through two 503s (cold start) then succeeds', 'hits=$hits');
  await expectError('HTML 500 page becomes a clean server error', () => fake.getMap('/html500/', auth: false), ApiErrorKind.server);
  await expectError('429 maps to throttled', () => fake.post('/throttled/', {}, false), ApiErrorKind.throttled);
  try {
    await fake.post('/validation/', {}, false);
  } on ApiException catch (e) {
    ok(e.kind == ApiErrorKind.validation && e.fieldErrors['username'] == 'A user with that username already exists.',
        'validation errors keep per-field messages', '${e.fieldErrors}');
    ok(e.message.startsWith('Username') || e.message.startsWith('Password'), 'validation message is readable', e.message);
  }
  ok((await fake.listAll('/anything/', auth: false)).isEmpty, 'listAll handles an empty page');
  await server.close(force: true);

  // 2) Nothing listening: must be a friendly network error, not a crash.
  final dead = ApiClient(baseUrl: 'http://127.0.0.1:1/api', tokens: MemoryTokenStore(), retryDelays: const [Duration(milliseconds: 10)]);
  await expectError('Unreachable server -> network error (after retry)', () => dead.getMap('/x/', auth: false), ApiErrorKind.network);
}

// -------------------------------------------------------------- student
Future<void> _studentChecks(String base, bool writes) async {
  final user = env('STUDENT_USER'), pass = env('STUDENT_PASS');
  if (user.isEmpty) {
    stdout.writeln('\n(student checks skipped: set STUDENT_USER / STUDENT_PASS)');
    return;
  }
  section('Student');
  final rig = Rig(base);
  await expectError(
      'wrong password is refused', () => rig.auth.login(username: user, password: 'definitely-wrong'), ApiErrorKind.unauthorized);
  await expectError('student cannot use the Super Admin sign-in',
      () => rig.auth.login(username: user, password: pass, portal: LoginPortal.superAdmin), ApiErrorKind.unauthorized);
  final me = await rig.auth.login(username: user, password: pass);
  ok(me.isStudent && me.username == user, 'student signs in', me.fullName);
  ok((await rig.store.readRefresh()) != null && (await rig.store.readAccess()) != null, 'tokens were stored');
  ok((await rig.auth.me()).id == me.id, 'GET /auth/me/ returns the same person');

  final sessions = await rig.academics.sessions();
  ok(sessions.isNotEmpty, 'sessions list parses', '${sessions.length}');
  final classYears = await rig.academics.myClassYears();
  ok(classYears.isNotEmpty && classYears.any((c) => c.current), 'my-classes has a current class', '${classYears.length}');
  final tt = await rig.academics.timetable();
  for (final y in classYears) {
    final older = await rig.academics.timetable(classId: y.id);
    ok(older.every((e) => e.classId == y.id), 'student can open the timetable of class year "${y.title}"', '${older.length} periods');
  }
  ok(tt.isNotEmpty, 'timetable parses', '${tt.length} periods');
  final hw = await rig.academics.homework();
  ok(hw.isNotEmpty && hw.first.done != null, 'homework carries the per-student done flag', '${hw.length}');
  final exams = await rig.academics.exams();
  final upcomingExams = await rig.academics.exams(upcomingOnly: true);
  final today0 = DateTime.now();
  ok(upcomingExams.every((e) => e.date != null && !e.date!.isBefore(DateTime(today0.year, today0.month, today0.day))), 'exams?upcoming=1 only returns today or later', '${upcomingExams.length}/${exams.length}');
  ok((await rig.academics.homework(upcomingOnly: true)).length <= hw.length, 'homework?upcoming=1 is accepted');
  ok(exams.isNotEmpty && exams.first.date != null, 'exam schedule parses');
  final att = await rig.academics.attendance();
  ok(att.isNotEmpty, 'own attendance parses', '${att.length} days');
  final res = await rig.academics.results();
  ok(res.isNotEmpty && res.first.fullMarks > 0, 'results parse (decimal strings -> numbers)',
      res.isEmpty ? '' : '${res.first.marks}/${res.first.fullMarks}');
  final sheets = await rig.academics.marksheets();
  ok(sheets.isNotEmpty && (sheets.first.url ?? '').isNotEmpty, 'marksheet has an address to open', '${sheets.length}');
  ok((await rig.content.notices()).isNotEmpty, 'notices parse');
  ok((await rig.content.events()).isNotEmpty, 'events parse');
  ok((await rig.content.articles()).isNotEmpty, 'blog articles parse (public)');
  ok((await rig.content.gallery()).isNotEmpty, 'gallery parses (public)');
  ok((await rig.content.downloads()).isNotEmpty, 'downloads parse (public)');
  final faculty = await rig.academics.faculty();
  ok(faculty.isNotEmpty, 'faculty parses');
  final mine = await rig.profile.mine();
  ok(mine.username == user && mine.role == 'STUDENT', 'my profile parses', mine.classLabel ?? '');
  final students = await rig.academics.students();
  ok(students.length == 1 && students.first.username == user, 'student sees ONLY their own profile row', '${students.length}');

  section('Student: role-based access control');
  await expectError('student blocked from admin stats', () => rig.admin.stats(), ApiErrorKind.forbidden);
  await expectError('student blocked from account list', () => rig.admin.users(), ApiErrorKind.forbidden);
  await expectError('student blocked from teacher attendance', () => rig.academics.myTeacherAttendance(), ApiErrorKind.forbidden);
  await expectError('student blocked from attendance report', () => rig.admin.attendanceReport(), ApiErrorKind.forbidden);
  await expectError('student blocked from admissions inbox', () => rig.content.admissions(), ApiErrorKind.forbidden);
  await expectError('student cannot save class attendance',
      () => rig.academics.saveClassAttendance(DateTime.now(), {me.id: AttendanceStatus.present}), ApiErrorKind.forbidden);
  await expectError('student cannot create a notice', () => rig.content.saveNotice(title: 'x', body: 'y'), ApiErrorKind.forbidden);

  section('Token refresh');
  // Corrupt the access token: the client must refresh by itself, store the ROTATED refresh token, and carry on.
  final refresh0 = await rig.store.readRefresh();
  rig.store.access = 'not-a-valid-token';
  // The client caches tokens after first use, so also reset its cache through a fresh client sharing the same store.
  final rig2 = Rig(base)..store.access = 'not-a-valid-token';
  rig2.store.refresh = refresh0;
  final again = await rig2.auth.me();
  ok(again.id == me.id, '401 -> automatic refresh -> request succeeds');
  final refresh1 = await rig2.store.readRefresh();
  ok(refresh1 != null && refresh1 != refresh0, 'rotated refresh token was stored (old one is blacklisted by the server)');

  // Do it again with the NEW refresh token: proves rotation is handled every time (the website only survives one refresh).
  final rig3 = Rig(base)..store.access = 'garbage';
  rig3.store.refresh = refresh1;
  ok((await rig3.auth.me()).id == me.id, 'second refresh with the rotated token also works');

  // Single flight: five requests fail at once; exactly one refresh may be sent or the others hit a blacklisted token.
  final refresh2 = await rig3.store.readRefresh();
  final rig4 = Rig(base)..store.access = 'garbage';
  rig4.store.refresh = refresh2;
  final results = await Future.wait([
    for (var i = 0; i < 5; i++) rig4.academics.homework().then((_) => true).catchError((Object _) => false),
  ]);
  ok(results.every((x) => x), 'five simultaneous 401s share ONE refresh and all succeed', '$results');
  ok(rig4.expired == 0, 'no false "session expired" during concurrent refresh');

  // A dead refresh token = session over: callback fires, store is wiped, error is "unauthorized".
  final rig5 = Rig(base)..store.access = 'garbage';
  rig5.store.refresh = refresh0; // already rotated away -> blacklisted
  await expectError('blacklisted refresh token ends the session', () => rig5.auth.me(), ApiErrorKind.unauthorized);
  ok(rig5.expired == 1, 'onSessionExpired fired exactly once', '${rig5.expired}');
  ok(await rig5.store.readRefresh() == null, 'dead session is wiped from storage');

  if (writes) {
    section('Student: homework tick');
    final open = hw.where((h) => h.canTick).toList();
    if (open.isEmpty) {
      stdout.writeln('  (no open homework to tick)');
    } else {
      final h = open.first;
      ok(await rig.academics.setHomeworkDone(h.id, true), 'tick homework');
      ok((await rig.academics.homework()).firstWhere((x) => x.id == h.id).done == true, 'tick is saved');
      ok(!(await rig.academics.setHomeworkDone(h.id, false)), 'untick homework');
    }
  }

  if (writes) {
    section('Student: profile editor payload');
    final before = await rig.profile.mine();
    // Same shape EditProfileScreen sends: blanks, null age, empty gender, all social keys (some empty).
    final saved = await rig.profile.update(asJson({
      'headline': 'verify_backend headline',
      'about': 'About text',
      'background': '',
      'quote': '',
      'city': 'Cooch Behar',
      'favorite_subject': 'Physics',
      'career_goal': '',
      'languages': ['Bengali', 'English'],
      'talents': <String>[],
      'interests': ['Coding'],
      'learning': <String>[],
      'photo_link': '',
      'age': null,
      'show_age': false,
      'gender': '',
      'show_gender': false,
      'is_public': true,
      'social_links': {
        'instagram': '',
        'facebook': '',
        'x': '',
        'youtube': '',
        'linkedin': '',
        'github': '@verify-user',
        'telegram': '',
        'website': ''
      },
    }));
    ok(saved.headline == 'verify_backend headline' && saved.languages.length == 2 && saved.isPublic, 'profile editor payload is accepted');
    ok((saved.socialLinks['github'] ?? '').contains('github.com/verify-user') && !saved.socialLinks.containsKey('instagram'),
        'social handle expanded to a link, blank links dropped', '${saved.socialLinks}');
    ok(saved.skills.length == before.skills.length && saved.projectCount == before.projectCount,
        'fields the app does not edit (skills, projects) are untouched');
    await expectError('bad age is rejected with a message', () => rig.profile.update(asJson({'age': 3})), ApiErrorKind.validation);
    final pub = await rig.profile.publicProfile(role: 'student', username: user);
    ok(pub.headline == 'verify_backend headline', 'public profile shows the saved headline');
    await rig.profile.update(asJson({
      'headline': before.headline,
      'about': before.about,
      'city': before.city,
      'favorite_subject': before.favoriteSubject,
      'languages': before.languages,
      'interests': before.interests,
      'is_public': before.isPublic,
      'social_links': <String, String>{}
    }));
  }

  section('Student: sign out');
  await rig.auth.signOut();
  ok(await rig.store.readRefresh() == null, 'tokens cleared on sign-out');
  await expectError('after sign-out the API refuses the old session', () => rig.auth.me(), ApiErrorKind.unauthorized);
}

// -------------------------------------------------------------- teacher
Future<void> _teacherChecks(String base, bool writes) async {
  final user = env('TEACHER_USER'), pass = env('TEACHER_PASS');
  if (user.isEmpty) {
    stdout.writeln('\n(teacher checks skipped: set TEACHER_USER / TEACHER_PASS)');
    return;
  }
  section('Teacher');
  final rig = Rig(base);
  await expectError('teacher cannot use Super Admin sign-in',
      () => rig.auth.login(username: user, password: pass, portal: LoginPortal.superAdmin), ApiErrorKind.unauthorized);
  final me = await rig.auth.login(username: user, password: pass);
  ok(me.isTeacher, 'teacher signs in', me.fullName);
  final students = await rig.academics.students();
  ok(students.isNotEmpty, 'teacher sees the student list', '${students.length}');
  final classes = await rig.academics.classes();
  final subjects = await rig.academics.subjects();
  ok(classes.isNotEmpty && subjects.isNotEmpty, 'classes + subjects parse', '${classes.length}/${subjects.length}');
  ok((await rig.academics.timetable(mineOnly: true)).every((t) => t.teacherId == me.id), 'timetable?mine=1 only returns my periods');
  final hw = await rig.academics.homework();
  ok(hw.isEmpty || hw.first.classSize != null, 'homework shows class size to staff');
  final mine = await rig.academics.myTeacherAttendance();
  ok(mine.length >= 0, 'teacher can read own attendance', '${mine.length}');

  section('Teacher: role-based access control');
  await expectError('teacher blocked from admin stats', () => rig.admin.stats(), ApiErrorKind.forbidden);
  await expectError(
      'teacher blocked from creating accounts',
      () => rig.admin.createUser(username: 'xx_nope', password: 'Whatever@12345', fullName: 'No', role: Role.student),
      ApiErrorKind.forbidden);
  await expectError('teacher blocked from creating a notice', () => rig.content.saveNotice(title: 'x', body: 'y'), ApiErrorKind.forbidden);
  await expectError('teacher blocked from attendance report', () => rig.admin.attendanceReport(), ApiErrorKind.forbidden);

  if (writes && classes.isNotEmpty && subjects.isNotEmpty) {
    section('Teacher: write flows');
    final c = classes.first;
    final cs = subjects.where((s) => s.classId == c.id).toList();
    final inClass = students.where((s) => s.classId == c.id).toList();
    final today = DateTime.now();
    if (inClass.isNotEmpty) {
      final saved = await rig.academics.saveClassAttendance(today, {for (final s in inClass) s.userId: AttendanceStatus.present});
      ok(saved == inClass.length, 'save class attendance', '$saved');
      final back = await rig.academics.attendance(classId: c.id, date: today);
      ok(back.length >= inClass.length, 'attendance reads back for that class+day', '${back.length}');
      if (cs.isNotEmpty) {
        final sess =
            (await rig.academics.sessions()).firstWhere((s) => s.isCurrent, orElse: () => (throw StateError('no current session')));
        final n = await rig.academics
            .saveResults(subjectId: cs.first.id, sessionId: sess.id, term: 'SEM2', fullMarks: 50, marks: {inClass.first.userId: 41.5});
        ok(n == 1, 'save marks');
        final r = await rig.academics.results(studentId: inClass.first.userId, term: 'SEM2');
        ok(r.any((x) => x.marks == 41.5 && x.fullMarks == 50), 'marks read back with decimals');
        await expectError(
            'marks above full marks are rejected',
            () => rig.academics
                .saveResults(subjectId: cs.first.id, sessionId: sess.id, term: 'SEM2', fullMarks: 50, marks: {inClass.first.userId: 60}),
            ApiErrorKind.validation);
      }
    }
    if (cs.isNotEmpty) {
      final h = await rig.academics.saveHomework(
          classId: c.id,
          subjectId: cs.first.id,
          title: 'verify_backend homework',
          details: 'temp',
          dueDate: today.add(const Duration(days: 2)));
      ok(h.title == 'verify_backend homework' && h.startDate != null, 'create homework (start date defaults to today)');
      await expectError(
          'end date before start date is rejected',
          () => rig.academics.saveHomework(
              id: h.id, classId: c.id, subjectId: cs.first.id, title: 't', startDate: today.add(const Duration(days: 5)), dueDate: today),
          ApiErrorKind.validation);
      final comp = await rig.academics.homeworkCompletions(h.id);
      ok(comp.length == students.where((s) => s.classId == c.id).length, 'completions list one row per student', '${comp.length}');
      final e = await rig.academics.saveExam(
          classId: c.id,
          subjectId: cs.first.id,
          name: 'verify_backend exam',
          date: today.add(const Duration(days: 9)),
          startTime: '10:00',
          room: 'T1');
      ok(e.name == 'verify_backend exam', 'create exam');
      await rig.academics.deleteExam(e.id);
      await rig.academics.deleteHomework(h.id);
      ok(!(await rig.academics.homework()).any((x) => x.id == h.id), 'delete homework');
    }
  }
}

// -------------------------------------------------------------- super admin
Future<void> _adminChecks(String base, bool writes) async {
  final user = env('ADMIN_USER'), pass = env('ADMIN_PASS');
  if (user.isEmpty) {
    stdout.writeln('\n(admin checks skipped: set ADMIN_USER / ADMIN_PASS)');
    return;
  }
  section('Super Admin');
  final rig = Rig(base);
  await expectError('Super Admin is refused by the student/teacher sign-in', () => rig.auth.login(username: user, password: pass),
      ApiErrorKind.unauthorized);
  final me = await rig.auth.login(username: user, password: pass, portal: LoginPortal.superAdmin);
  ok(me.isSuperAdmin, 'Super Admin signs in with e-mail', me.fullName);
  final stats = await rig.admin.stats();
  ok(stats.students >= 0 && stats.last7.length == 7, 'stats parse (7-day series)', 'students=${stats.students} teachers=${stats.teachers}');
  final users = await rig.admin.users();
  ok(users.every((u) => u.role != Role.superAdmin), 'account list never exposes Super Admins', '${users.length}');
  final report = await rig.admin.attendanceReport();
  ok(report.kind == 'students' && report.rows.length == report.people, 'attendance report (students) parses', '${report.rows.length} rows');
  final treport = await rig.admin.attendanceReport(kind: 'teachers');
  ok(treport.kind == 'teachers', 'attendance report (teachers) parses');
  final sheet = await rig.academics.teacherSheet(DateTime.now());
  ok(sheet.length >= 0, 'teacher attendance sheet parses', '${sheet.length}');
  ok((await rig.admin.resetRequests()).length >= 0, 'reset requests parse');
  ok((await rig.content.admissions()).length >= 0, 'admissions inbox parses');
  ok((await rig.content.messages()).length >= 0, 'contact messages parse');
  await expectError(
      'Super Admin cannot create another Super Admin through the API',
      () => rig.admin.createUser(username: 'zz_root', password: 'Whatever@12345', fullName: 'X', role: Role.superAdmin),
      ApiErrorKind.validation);

  if (writes) {
    section('Super Admin: write flows');
    final stamp = DateTime.now().millisecondsSinceEpoch.toString().substring(6);
    final u = await rig.admin
        .createUser(username: 'vb_user_$stamp', password: 'Verify@Pass$stamp', fullName: 'Verify Backend', role: Role.student);
    ok(u.role == Role.student && u.isActive, 'create account');
    await expectError(
        'duplicate username is refused with a field message',
        () => rig.admin.createUser(username: u.username, password: 'Verify@Pass$stamp', fullName: 'Dup', role: Role.student),
        ApiErrorKind.validation);
    final classes0 = await rig.academics.classes();
    if (classes0.isNotEmpty) {
      final placed = await rig.academics
          .updateStudent(u.id, classId: classes0.first.id, rollNumber: '77', guardianName: 'Guardian', guardianContact: '9000000000');
      ok(placed.classId == classes0.first.id && placed.rollNumber == '77', 'Super Admin places a student in a class with a roll number');
      final fresh = (await rig.academics.students(classId: classes0.first.id)).where((x) => x.userId == u.id);
      ok(fresh.length == 1, 'placed student appears in that class list');
    }
    final upd = await rig.admin.updateUser(u.id, fullName: 'Verify Backend 2', isActive: false);
    ok(upd.fullName == 'Verify Backend 2' && !upd.isActive, 'edit + disable account');
    await rig.admin.resetPassword(u.id, 'Changed@Pass$stamp');
    await rig.admin.unlock(u.id);
    final login = Rig(base);
    await expectError('disabled account cannot sign in', () => login.auth.login(username: u.username, password: 'Changed@Pass$stamp'),
        ApiErrorKind.unauthorized);
    await rig.admin.updateUser(u.id, isActive: true);
    final back = await login.auth.login(username: u.username, password: 'Changed@Pass$stamp');
    ok(back.username == u.username, 'new password works after reset + re-enable');
    await login.auth.changePassword(current: 'Changed@Pass$stamp', next: 'Third@Pass$stamp');
    await expectError('old tokens die after a password change', () => login.api.getMap('/auth/me/'), ApiErrorKind.unauthorized);
    await rig.admin.deleteUser(u.id);
    ok(!(await rig.admin.users()).any((x) => x.id == u.id), 'delete account');

    final n = await rig.content.saveNotice(title: 'verify_backend notice', body: 'temp');
    ok(n.title == 'verify_backend notice', 'create notice');
    await rig.content.saveNotice(id: n.id, title: 'verify_backend notice 2', body: 'temp');
    await rig.content.deleteNotice(n.id);
    final ev = await rig.content.saveEvent(title: 'verify_backend event', date: DateTime.now().add(const Duration(days: 3)));
    ok(ev.date != null, 'create event');
    await rig.content.deleteEvent(ev.id);

    final pub = ApiClient(baseUrl: base, tokens: MemoryTokenStore());
    await pub.post(
        '/content/admissions/submit/',
        {'applicant_name': 'verify_backend', 'guardian_contact': '9${stamp}000', 'applying_for_class': 'Class V', 'message': 'temp'},
        false);
    final adm = (await rig.content.admissions()).firstWhere((a) => a.applicantName == 'verify_backend');
    ok((await rig.content.setAdmissionStatus(adm.id, 'CONTACTED')).status == 'CONTACTED', 'admission status update');
    await rig.content.deleteAdmission(adm.id);

    final ss = await rig.academics.saveSession(label: 'VB$stamp', workingDays: 100, startDate: DateTime(2030, 1, 1));
    final cl = await rig.academics.saveClass(name: 'Class VB', stream: 'Test', sessionId: ss.id);
    final sub = await rig.academics.saveSubject(name: 'Verify subject', classId: cl.id);
    final tt = await rig.academics
        .saveTimetableEntry(classId: cl.id, weekday: 0, period: 1, startTime: '09:00', endTime: '09:40', subjectId: sub.id, room: 'R1');
    ok(tt.title == 'Verify subject', 'create session/class/subject/timetable chain');
    await rig.academics.deleteTimetableEntry(tt.id);
    await rig.academics.deleteSubject(sub.id);
    await rig.academics.deleteClass(cl.id);
    await rig.academics.deleteSession(ss.id);

    final teachers = await rig.academics.teacherSheet(DateTime.now());
    if (teachers.isNotEmpty) {
      final saved = await rig.academics.saveTeacherAttendance(DateTime.now(), {teachers.first.teacherId: AttendanceStatus.present});
      ok(saved == 1, 'save teacher attendance');
    }
  }
}
