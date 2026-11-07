import '../../core/json.dart';

class AcademicSession {
  const AcademicSession(
      {required this.id, required this.label, this.isCurrent = false, this.startDate, this.workingDays, this.minPercent = 75});

  final String id;
  final String label;
  final bool isCurrent;
  final DateTime? startDate;
  final int? workingDays;
  final int minPercent;

  static AcademicSession fromJson(Json j) => AcademicSession(
        id: str(j, 'id'),
        label: str(j, 'label'),
        isCurrent: boolOr(j, 'is_current'),
        startDate: dateOnlyOrNull(j, 'start_date'),
        workingDays: intOrNull(j, 'working_days'),
        minPercent: intOr(j, 'attendance_min_percent', 75),
      );
}

class SchoolClass {
  const SchoolClass({required this.id, required this.name, this.stream = '', required this.sessionId});

  final String id;
  final String name;
  final String stream;
  final String sessionId;

  String get label => stream.isEmpty ? name : '$name $stream';

  static SchoolClass fromJson(Json j) =>
      SchoolClass(id: str(j, 'id'), name: str(j, 'name'), stream: str(j, 'stream'), sessionId: str(j, 'session'));
}

class Subject {
  const Subject({required this.id, required this.name, required this.classId});

  final String id;
  final String name;
  final String classId;

  static Subject fromJson(Json j) => Subject(id: str(j, 'id'), name: str(j, 'name'), classId: str(j, 'school_class'));
}

class StudentProfile {
  const StudentProfile({
    required this.userId,
    required this.fullName,
    required this.username,
    this.classId,
    this.rollNumber = '',
    this.guardianName = '',
    this.guardianContact = '',
    this.isAlumni = false,
  });

  /// The student's user id. Attendance / results / marksheets reference the student by this value.
  final String userId;
  final String fullName;
  final String username;
  final String? classId;
  final String rollNumber;
  final String guardianName;
  final String guardianContact;
  final bool isAlumni;

  static StudentProfile fromJson(Json j) => StudentProfile(
        userId: str(j, 'user'),
        fullName: str(j, 'full_name'),
        username: str(j, 'username'),
        classId: strOrNull(j, 'school_class'),
        rollNumber: str(j, 'roll_number'),
        guardianName: str(j, 'guardian_name'),
        guardianContact: str(j, 'guardian_contact'),
        isAlumni: boolOr(j, 'is_alumni'),
      );
}

/// One of the classes a student has been in (current and earlier years). GET /academics/my-classes/
class ClassYear {
  const ClassYear({required this.id, required this.label, required this.session, required this.current, this.outcome = ''});

  final String id;
  final String label;
  final String session;
  final bool current;
  final String outcome;

  String get title => '$label \u00b7 $session';

  static ClassYear fromJson(Json j) => ClassYear(
        id: str(j, 'id'),
        label: str(j, 'label'),
        session: str(j, 'session'),
        current: boolOr(j, 'current'),
        outcome: str(j, 'outcome'),
      );
}

const weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class TimetableEntry {
  const TimetableEntry({
    required this.id,
    required this.classId,
    required this.weekday,
    required this.period,
    required this.startTime,
    required this.endTime,
    this.subjectId,
    this.subjectName = '',
    this.label = '',
    this.teacherId,
    this.teacherName = '',
    this.room = '',
  });

  final String id;
  final String classId;

  /// 0 = Monday ... 5 = Saturday (Python's weekday(); Dart's DateTime.weekday - 1).
  final int weekday;
  final int period;

  /// "HH:MM:SS" as sent by the API.
  final String startTime;
  final String endTime;
  final String? subjectId;
  final String subjectName;
  final String label;
  final String? teacherId;
  final String teacherName;
  final String room;

  bool get isBreak => subjectId == null;
  String get title => subjectName.isNotEmpty ? subjectName : (label.isNotEmpty ? label : 'Period $period');

  static TimetableEntry fromJson(Json j) => TimetableEntry(
        id: str(j, 'id'),
        classId: str(j, 'school_class'),
        weekday: intOr(j, 'weekday'),
        period: intOr(j, 'period'),
        startTime: str(j, 'start_time'),
        endTime: str(j, 'end_time'),
        subjectId: strOrNull(j, 'subject'),
        subjectName: str(j, 'subject_name'),
        label: str(j, 'label'),
        teacherId: strOrNull(j, 'teacher'),
        teacherName: str(j, 'teacher_name'),
        room: str(j, 'room'),
      );
}

class Homework {
  const Homework({
    required this.id,
    required this.classId,
    this.className = '',
    required this.subjectId,
    this.subjectName = '',
    required this.title,
    this.details = '',
    this.startDate,
    required this.dueDate,
    this.phase = 'open',
    this.canTick = false,
    this.createdByName = '',
    this.done,
    this.submitted,
    this.classSize,
  });

  final String id;
  final String classId;
  final String className;
  final String subjectId;
  final String subjectName;
  final String title;
  final String details;
  final DateTime? startDate;
  final DateTime? dueDate;

  /// 'upcoming' | 'open' | 'closed' (decided by the server from the start/end dates).
  final String phase;
  final bool canTick;
  final String createdByName;

  /// Students only: have they ticked it? (null for staff)
  final bool? done;

  /// Staff only: how many students ticked it, out of [classSize].
  final int? submitted;
  final int? classSize;

  Homework copyWith({bool? done, int? submitted}) => Homework(
        id: id,
        classId: classId,
        className: className,
        subjectId: subjectId,
        subjectName: subjectName,
        title: title,
        details: details,
        startDate: startDate,
        dueDate: dueDate,
        phase: phase,
        canTick: canTick,
        createdByName: createdByName,
        done: done ?? this.done,
        submitted: submitted ?? this.submitted,
        classSize: classSize,
      );

  static Homework fromJson(Json j) => Homework(
        id: str(j, 'id'),
        classId: str(j, 'school_class'),
        className: str(j, 'class_name'),
        subjectId: str(j, 'subject'),
        subjectName: str(j, 'subject_name'),
        title: str(j, 'title'),
        details: str(j, 'details'),
        startDate: dateOnlyOrNull(j, 'start_date'),
        dueDate: dateOnlyOrNull(j, 'due_date'),
        phase: str(j, 'phase', 'open'),
        canTick: boolOr(j, 'can_tick'),
        createdByName: str(j, 'created_by_name'),
        done: j['done'] is bool ? j['done'] as bool : null,
        submitted: intOrNull(j, 'submitted'),
        classSize: intOrNull(j, 'class_size'),
      );
}

class HomeworkCompletion {
  const HomeworkCompletion(
      {required this.studentId, required this.fullName, required this.rollNumber, required this.done, this.completedAt});

  final String studentId;
  final String fullName;
  final String rollNumber;
  final bool done;
  final DateTime? completedAt;

  static HomeworkCompletion fromJson(Json j) => HomeworkCompletion(
        studentId: str(j, 'student'),
        fullName: str(j, 'full_name'),
        rollNumber: str(j, 'roll_number'),
        done: boolOr(j, 'done'),
        completedAt: dateTimeOrNull(j, 'completed_at'),
      );
}

class Exam {
  const Exam({
    required this.id,
    required this.classId,
    this.className = '',
    required this.subjectId,
    this.subjectName = '',
    required this.name,
    required this.date,
    this.startTime,
    this.room = '',
  });

  final String id;
  final String classId;
  final String className;
  final String subjectId;
  final String subjectName;
  final String name;
  final DateTime? date;
  final String? startTime;
  final String room;

  static Exam fromJson(Json j) => Exam(
        id: str(j, 'id'),
        classId: str(j, 'school_class'),
        className: str(j, 'class_name'),
        subjectId: str(j, 'subject'),
        subjectName: str(j, 'subject_name'),
        name: str(j, 'name'),
        date: dateOnlyOrNull(j, 'date'),
        startTime: strOrNull(j, 'start_time'),
        room: str(j, 'room'),
      );
}

enum AttendanceStatus {
  present('PRESENT', 'Present'),
  absent('ABSENT', 'Absent');

  const AttendanceStatus(this.api, this.label);
  final String api;
  final String label;

  static AttendanceStatus? parse(String? v) {
    for (final s in AttendanceStatus.values) {
      if (s.api == v) return s;
    }
    return null;
  }
}

class AttendanceRecord {
  const AttendanceRecord({required this.id, required this.studentId, required this.date, required this.status});

  final String id;
  final String studentId;
  final DateTime date;
  final AttendanceStatus status;

  static AttendanceRecord? fromJson(Json j) {
    final d = dateOnlyOrNull(j, 'date');
    final s = AttendanceStatus.parse(strOrNull(j, 'status'));
    if (d == null || s == null) return null;
    return AttendanceRecord(id: str(j, 'id'), studentId: str(j, 'student'), date: d, status: s);
  }
}

/// One teacher with the mark for a chosen day (GET /academics/teacher-attendance/sheet/). status null = not marked.
class TeacherSheetRow {
  const TeacherSheetRow({required this.teacherId, required this.fullName, this.department = '', this.status});

  final String teacherId;
  final String fullName;
  final String department;
  final AttendanceStatus? status;

  static TeacherSheetRow fromJson(Json j) => TeacherSheetRow(
        teacherId: str(j, 'teacher'),
        fullName: str(j, 'full_name'),
        department: str(j, 'department'),
        status: AttendanceStatus.parse(strOrNull(j, 'status')),
      );
}

const termLabels = {
  'SEM1': 'First Semester',
  'SEM2': 'Second Semester',
  'SEM3': 'Third Semester',
  'SEM4': 'Fourth Semester',
  'ANNUAL': 'Annual / Final',
};
const termOrder = ['SEM1', 'SEM2', 'SEM3', 'SEM4', 'ANNUAL'];

class ResultRow {
  const ResultRow({
    required this.id,
    required this.studentId,
    required this.subjectId,
    required this.sessionId,
    required this.term,
    required this.marks,
    required this.fullMarks,
  });

  final String id;
  final String studentId;
  final String subjectId;
  final String sessionId;
  final String term;
  final double marks;
  final double fullMarks;

  String get termLabel => termLabels[term] ?? term;
  double get percent => fullMarks <= 0 ? 0 : marks / fullMarks * 100;

  static ResultRow fromJson(Json j) => ResultRow(
        id: str(j, 'id'),
        studentId: str(j, 'student'),
        subjectId: str(j, 'subject'),
        sessionId: str(j, 'session'),
        term: str(j, 'term', 'SEM1'),
        marks: dbl(j, 'marks_obtained'),
        fullMarks: dbl(j, 'full_marks', 100),
      );
}

class Marksheet {
  const Marksheet({required this.id, required this.studentId, required this.sessionId, this.url, this.generatedAt});

  final String id;
  final String studentId;
  final String sessionId;

  /// The address to open (an uploaded file's URL or a pasted Google Drive link).
  final String? url;
  final DateTime? generatedAt;

  static Marksheet fromJson(Json j) => Marksheet(
        id: str(j, 'id'),
        studentId: str(j, 'student'),
        sessionId: str(j, 'session'),
        url: strOrNull(j, 'download_url') ?? strOrNull(j, 'file'),
        generatedAt: dateTimeOrNull(j, 'generated_at'),
      );
}

class TeacherProfileRow {
  const TeacherProfileRow(
      {required this.userId,
      required this.fullName,
      this.department = '',
      this.bio = '',
      this.yearsExperience,
      this.subjectNames = const []});

  final String userId;
  final String fullName;
  final String department;
  final String bio;
  final int? yearsExperience;
  final List<String> subjectNames;

  static TeacherProfileRow fromJson(Json j) => TeacherProfileRow(
        userId: str(j, 'user'),
        fullName: str(j, 'full_name'),
        department: str(j, 'department'),
        bio: str(j, 'bio'),
        yearsExperience: intOrNull(j, 'years_experience'),
      );
}
