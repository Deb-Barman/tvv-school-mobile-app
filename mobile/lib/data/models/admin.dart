import '../../core/json.dart';

class DayAttendance {
  const DayAttendance(this.date, this.present, this.absent);
  final DateTime? date;
  final int present;
  final int absent;
}

/// GET /auth/admin/stats/ - the Super Admin command centre numbers.
class AdminStats {
  const AdminStats({
    this.students = 0,
    this.teachers = 0,
    this.disabled = 0,
    this.studentsWithoutClass = 0,
    this.admissionsTotal = 0,
    this.admissionsPending = 0,
    this.passwordRequests = 0,
    this.newMessages = 0,
    this.totalMessages = 0,
    this.notices = 0,
    this.articlesPublished = 0,
    this.articleDrafts = 0,
    this.eventsUpcoming = 0,
    this.gallery = 0,
    this.forms = 0,
    this.achievements = 0,
    this.sessions = 0,
    this.classes = 0,
    this.subjects = 0,
    this.currentSession,
    this.presentToday = 0,
    this.absentToday = 0,
    this.last7 = const [],
    this.recentAdmissions = const [],
    this.recentNotices = const [],
  });

  final int students, teachers, disabled, studentsWithoutClass;
  final int admissionsTotal, admissionsPending, passwordRequests, newMessages, totalMessages;
  final int notices, articlesPublished, articleDrafts, eventsUpcoming, gallery, forms, achievements;
  final int sessions, classes, subjects;
  final String? currentSession;
  final int presentToday, absentToday;
  final List<DayAttendance> last7;
  final List<Json> recentAdmissions;
  final List<Json> recentNotices;

  int get markedToday => presentToday + absentToday;

  static AdminStats fromJson(Json j) {
    final people = asJson(j['people']);
    final adm = asJson(j['admissions']);
    final content = asJson(j['content']);
    final msgs = asJson(j['messages']);
    final acad = asJson(j['academics']);
    final att = asJson(j['attendance']);
    final today = asJson(att['today']);
    return AdminStats(
      students: intOr(people, 'students'),
      teachers: intOr(people, 'teachers'),
      disabled: intOr(people, 'disabled'),
      studentsWithoutClass: intOr(people, 'students_without_class'),
      admissionsTotal: intOr(adm, 'total'),
      admissionsPending: intOr(adm, 'pending'),
      passwordRequests: intOr(j, 'password_requests'),
      newMessages: intOr(msgs, 'new'),
      totalMessages: intOr(msgs, 'total'),
      notices: intOr(content, 'notices'),
      articlesPublished: intOr(content, 'articles_published'),
      articleDrafts: intOr(content, 'articles_drafts'),
      eventsUpcoming: intOr(content, 'events_upcoming'),
      gallery: intOr(content, 'gallery'),
      forms: intOr(content, 'forms'),
      achievements: intOr(content, 'achievements'),
      sessions: intOr(acad, 'sessions'),
      classes: intOr(acad, 'classes'),
      subjects: intOr(acad, 'subjects'),
      currentSession: strOrNull(acad, 'current_session'),
      presentToday: intOr(today, 'present'),
      absentToday: intOr(today, 'absent'),
      last7:
          asJsonList(att['last7']).map((d) => DayAttendance(dateOnlyOrNull(d, 'date'), intOr(d, 'present'), intOr(d, 'absent'))).toList(),
      recentAdmissions: asJsonList(j['recent_admissions']),
      recentNotices: asJsonList(j['recent_notices']),
    );
  }
}

class ReportRow {
  const ReportRow({
    required this.id,
    required this.name,
    required this.username,
    required this.group,
    this.rollNumber = '',
    required this.present,
    required this.absent,
    required this.marked,
    this.percent,
    this.percentOfTotal,
    this.daysLeft,
    this.bestPossible,
    required this.status,
  });

  final String id;
  final String name;
  final String username;
  final String group;
  final String rollNumber;
  final int present;
  final int absent;
  final int marked;
  final double? percent;
  final double? percentOfTotal;
  final int? daysLeft;
  final double? bestPossible;

  /// 'ok' | 'low' | 'critical' | 'no_data'
  final String status;

  static ReportRow fromJson(Json j) => ReportRow(
        id: str(j, 'id'),
        name: str(j, 'name'),
        username: str(j, 'username'),
        group: str(j, 'group'),
        rollNumber: str(j, 'roll_number'),
        present: intOr(j, 'present'),
        absent: intOr(j, 'absent'),
        marked: intOr(j, 'marked'),
        percent: dblOrNull(j, 'percent'),
        percentOfTotal: dblOrNull(j, 'percent_of_total'),
        daysLeft: intOrNull(j, 'days_left'),
        bestPossible: dblOrNull(j, 'best_possible_percent'),
        status: str(j, 'status', 'no_data'),
      );
}

class AttendanceReport {
  const AttendanceReport({
    required this.kind,
    this.sessionLabel,
    this.workingDays,
    this.minPercent = 75,
    this.people = 0,
    this.averagePercent,
    this.ok = 0,
    this.low = 0,
    this.critical = 0,
    this.noData = 0,
    this.daysHeld = 0,
    this.daysLeft,
    this.percentOfSessionDone,
    this.rows = const [],
  });

  final String kind;
  final String? sessionLabel;
  final int? workingDays;
  final int minPercent;
  final int people;
  final double? averagePercent;
  final int ok, low, critical, noData, daysHeld;
  final int? daysLeft;
  final double? percentOfSessionDone;
  final List<ReportRow> rows;

  static AttendanceReport fromJson(Json j) {
    final session = asJson(j['session']);
    final s = asJson(j['summary']);
    return AttendanceReport(
      kind: str(j, 'kind', 'students'),
      sessionLabel: strOrNull(session, 'label'),
      workingDays: intOrNull(session, 'working_days'),
      minPercent: intOr(session, 'min_percent', 75),
      people: intOr(s, 'people'),
      averagePercent: dblOrNull(s, 'average_percent'),
      ok: intOr(s, 'ok'),
      low: intOr(s, 'low'),
      critical: intOr(s, 'critical'),
      noData: intOr(s, 'no_data'),
      daysHeld: intOr(s, 'days_held'),
      daysLeft: intOrNull(s, 'days_left'),
      percentOfSessionDone: dblOrNull(s, 'percent_of_session_done'),
      rows: asJsonList(j['rows']).map(ReportRow.fromJson).toList(),
    );
  }
}
