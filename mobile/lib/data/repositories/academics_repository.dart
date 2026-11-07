import '../../core/api_client.dart';
import '../../core/json.dart';
import '../models/academics.dart';
import '../models/profile.dart';

class AcademicsRepository {
  AcademicsRepository(this._api);
  final ApiClient _api;

  // ----------------------------------------------------------- reference data

  Future<List<AcademicSession>> sessions() async => (await _api.listAll('/academics/sessions/')).map(AcademicSession.fromJson).toList();

  Future<List<SchoolClass>> classes({String? sessionId}) async =>
      (await _api.listAll('/academics/classes/', query: {'session': sessionId})).map(SchoolClass.fromJson).toList();

  Future<List<Subject>> subjects({String? classId}) async =>
      (await _api.listAll('/academics/subjects/', query: {'school_class': classId})).map(Subject.fromJson).toList();

  Future<List<StudentProfile>> students({String? classId, String? search, bool hideAlumni = true}) async {
    final rows = await _api.listAll('/academics/students/', query: {
      'school_class': classId,
      'search': search,
      'alumni': hideAlumni ? 'hide' : null,
    });
    return rows.map(StudentProfile.fromJson).toList();
  }

  /// Super Admin: put a student in a class / set roll number and guardian details. [studentUserId] is the student's user id.
  Future<StudentProfile> updateStudent(String studentUserId,
      {String? classId, bool clearClass = false, String? rollNumber, String? guardianName, String? guardianContact}) async {
    final body = <String, Object?>{
      if (classId != null || clearClass) 'school_class': classId,
      if (rollNumber != null) 'roll_number': rollNumber.trim(),
      if (guardianName != null) 'guardian_name': guardianName.trim(),
      if (guardianContact != null) 'guardian_contact': guardianContact.trim(),
    };
    return StudentProfile.fromJson(await _api.patch('/academics/students/$studentUserId/', body));
  }

  /// Student only: the classes they have been in, newest first.
  Future<List<ClassYear>> myClassYears() async => (await _api.listAll('/academics/my-classes/')).map(ClassYear.fromJson).toList();

  /// Teacher directory (id + name) for pickers. Staff only on the server.
  Future<List<TeacherProfileRow>> teachers() async => (await _api.listAll('/academics/teachers/')).map(TeacherProfileRow.fromJson).toList();

  Future<List<FacultyMember>> faculty() async =>
      (await _api.listAll('/academics/teachers/public/', pageSize: 100)).map(FacultyMember.fromJson).toList();

  // Super Admin: sessions / classes / subjects
  Future<AcademicSession> saveSession(
      {String? id, required String label, bool isCurrent = false, DateTime? startDate, int? workingDays, int minPercent = 75}) async {
    final body = <String, Object?>{
      'label': label,
      'is_current': isCurrent,
      'start_date': startDate == null ? null : isoDate(startDate),
      'working_days': workingDays,
      'attendance_min_percent': minPercent,
    };
    final data = id == null ? await _api.post('/academics/sessions/', body) : await _api.patch('/academics/sessions/$id/', body);
    return AcademicSession.fromJson(data);
  }

  Future<void> deleteSession(String id) => _api.delete('/academics/sessions/$id/');

  Future<SchoolClass> saveClass({String? id, required String name, String stream = '', required String sessionId}) async {
    final body = {'name': name, 'stream': stream, 'session': sessionId};
    final data = id == null ? await _api.post('/academics/classes/', body) : await _api.patch('/academics/classes/$id/', body);
    return SchoolClass.fromJson(data);
  }

  Future<void> deleteClass(String id) => _api.delete('/academics/classes/$id/');

  Future<Subject> saveSubject({String? id, required String name, required String classId}) async {
    final body = {'name': name, 'school_class': classId};
    final data = id == null ? await _api.post('/academics/subjects/', body) : await _api.patch('/academics/subjects/$id/', body);
    return Subject.fromJson(data);
  }

  Future<void> deleteSubject(String id) => _api.delete('/academics/subjects/$id/');

  // ----------------------------------------------------------- timetable

  /// Students are scoped to their own class by the server; pass [classId] to open an earlier class year or (staff) any class.
  Future<List<TimetableEntry>> timetable({String? classId, bool mineOnly = false}) async =>
      (await _api.listAll('/academics/timetable/', query: {'school_class': classId, 'mine': mineOnly ? 1 : null}))
          .map(TimetableEntry.fromJson)
          .toList();

  Future<TimetableEntry> saveTimetableEntry({
    String? id,
    required String classId,
    required int weekday,
    required int period,
    required String startTime,
    required String endTime,
    String? subjectId,
    String label = '',
    String? teacherId,
    String room = '',
  }) async {
    final body = <String, Object?>{
      'school_class': classId,
      'weekday': weekday,
      'period': period,
      'start_time': startTime,
      'end_time': endTime,
      'subject': subjectId,
      'label': label,
      'teacher': teacherId,
      'room': room,
    };
    final data = id == null ? await _api.post('/academics/timetable/', body) : await _api.patch('/academics/timetable/$id/', body);
    return TimetableEntry.fromJson(data);
  }

  Future<void> deleteTimetableEntry(String id) => _api.delete('/academics/timetable/$id/');

  // ----------------------------------------------------------- homework

  Future<List<Homework>> homework({String? classId, bool upcomingOnly = false}) async =>
      (await _api.listAll('/academics/homework/', query: {'school_class': classId, 'upcoming': upcomingOnly ? 1 : null}))
          .map(Homework.fromJson)
          .toList();

  /// Student ticks / unticks. The server refuses it outside the start-end window and explains why.
  Future<bool> setHomeworkDone(String id, bool done) async {
    final data = await _api.post('/academics/homework/$id/done/', {'done': done});
    return boolOr(data, 'done', done);
  }

  Future<List<HomeworkCompletion>> homeworkCompletions(String id) async {
    final data = await _api.getMap('/academics/homework/$id/completions/');
    return asJsonList(data['students']).map(HomeworkCompletion.fromJson).toList();
  }

  Future<Homework> saveHomework({
    String? id,
    required String classId,
    required String subjectId,
    required String title,
    String details = '',
    DateTime? startDate,
    required DateTime dueDate,
  }) async {
    final body = <String, Object?>{
      'school_class': classId,
      'subject': subjectId,
      'title': title,
      'details': details,
      'start_date': startDate == null ? null : isoDate(startDate),
      'due_date': isoDate(dueDate),
    };
    final data = id == null ? await _api.post('/academics/homework/', body) : await _api.patch('/academics/homework/$id/', body);
    return Homework.fromJson(data);
  }

  Future<void> deleteHomework(String id) => _api.delete('/academics/homework/$id/');

  // ----------------------------------------------------------- exams

  Future<List<Exam>> exams({String? classId, bool upcomingOnly = false}) async =>
      (await _api.listAll('/academics/exams/', query: {'school_class': classId, 'upcoming': upcomingOnly ? 1 : null}))
          .map(Exam.fromJson)
          .toList();

  Future<Exam> saveExam(
      {String? id,
      required String classId,
      required String subjectId,
      required String name,
      required DateTime date,
      String? startTime,
      String room = ''}) async {
    final body = <String, Object?>{
      'school_class': classId,
      'subject': subjectId,
      'name': name,
      'date': isoDate(date),
      'start_time': startTime,
      'room': room,
    };
    final data = id == null ? await _api.post('/academics/exams/', body) : await _api.patch('/academics/exams/$id/', body);
    return Exam.fromJson(data);
  }

  Future<void> deleteExam(String id) => _api.delete('/academics/exams/$id/');

  // ----------------------------------------------------------- attendance

  /// Student: their own days (the server ignores any other filter). Staff: filter by class / date / student.
  Future<List<AttendanceRecord>> attendance({String? classId, DateTime? date, String? studentId}) async {
    final rows = await _api.listAll('/academics/attendance/', query: {
      'school_class': classId,
      'date': date == null ? null : isoDate(date),
      'student': studentId,
    });
    return rows.map(AttendanceRecord.fromJson).whereType<AttendanceRecord>().toList();
  }

  /// All-or-nothing save of a whole class for one day. Keys are student USER ids.
  Future<int> saveClassAttendance(DateTime date, Map<String, AttendanceStatus> marks) async {
    final data = await _api.post('/academics/attendance/bulk/', {
      'date': isoDate(date),
      'records': [
        for (final e in marks.entries) {'student': e.key, 'status': e.value.api}
      ],
    });
    return intOr(data, 'saved');
  }

  /// Teacher: their own days. (Super Admin uses [teacherSheet].)
  Future<List<AttendanceRecord>> myTeacherAttendance() async {
    final rows = await _api.listAll('/academics/teacher-attendance/');
    return rows.map((j) => AttendanceRecord.fromJson({...j, 'student': j['teacher']})).whereType<AttendanceRecord>().toList();
  }

  Future<List<TeacherSheetRow>> teacherSheet(DateTime date) async {
    final data = await _api.getMap('/academics/teacher-attendance/sheet/', query: {'date': isoDate(date)});
    return asJsonList(data['teachers']).map(TeacherSheetRow.fromJson).toList();
  }

  Future<int> saveTeacherAttendance(DateTime date, Map<String, AttendanceStatus> marks) async {
    final data = await _api.post('/academics/teacher-attendance/bulk/', {
      'date': isoDate(date),
      'records': [
        for (final e in marks.entries) {'teacher': e.key, 'status': e.value.api}
      ],
    });
    return intOr(data, 'saved');
  }

  // ----------------------------------------------------------- results + marksheets

  Future<List<ResultRow>> results({String? studentId, String? sessionId, String? subjectId, String? term}) async {
    final rows =
        await _api.listAll('/academics/results/', query: {'student': studentId, 'session': sessionId, 'subject': subjectId, 'term': term});
    return rows.map(ResultRow.fromJson).toList();
  }

  /// Marks for a whole class in one subject/term. [marks] is student user id -> marks obtained.
  Future<int> saveResults({
    required String subjectId,
    required String sessionId,
    required String term,
    required double fullMarks,
    required Map<String, double> marks,
  }) async {
    final data = await _api.post('/academics/results/bulk/', {
      'subject': subjectId,
      'session': sessionId,
      'term': term,
      'full_marks': fullMarks.toStringAsFixed(2),
      'records': [
        for (final e in marks.entries) {'student': e.key, 'marks_obtained': e.value.toStringAsFixed(2)}
      ],
    });
    return intOr(data, 'saved');
  }

  Future<List<Marksheet>> marksheets() async => (await _api.listAll('/academics/marksheets/')).map(Marksheet.fromJson).toList();

  /// Super Admin: attach a marksheet by pasting a share link (the same "link instead of upload" the website uses).
  Future<Marksheet> createMarksheet({required String studentId, required String sessionId, required String link}) async =>
      Marksheet.fromJson(await _api.post('/academics/marksheets/create/', {'student': studentId, 'session': sessionId, 'file_link': link}));

  Future<void> deleteMarksheet(String id) => _api.delete('/academics/marksheets/$id/');
}
