import 'package:flutter/material.dart';

import '../data/models/user.dart';
import 'screens/academics/attendance_views.dart';
import 'screens/academics/exams_view.dart';
import 'screens/academics/homework_view.dart';
import 'screens/academics/results_views.dart';
import 'screens/academics/students_class_views.dart';
import 'screens/academics/timetable_view.dart';
import 'screens/admin/accounts_view.dart';
import 'screens/admin/inbox_view.dart';
import 'screens/content/notices_view.dart';
import 'screens/content/public_views.dart';
import 'screens/home/admin_home.dart';
import 'screens/home/student_home.dart';
import 'screens/home/teacher_home.dart';
import 'screens/profile/my_profile_view.dart';
import 'screens/settings/settings_view.dart';

/// One section of the app. Which sections a person gets is decided here from their role; the Django API is what
/// actually enforces permissions (a student who somehow reached an admin screen would only see "permission" errors).
class Feature {
  const Feature({required this.key, required this.title, required this.icon, required this.builder, this.subtitle = ''});
  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget Function(BuildContext context) builder;
}

typedef OpenFeature = void Function(String key);

class AppNav {
  AppNav({required this.tabs, required this.more});

  /// Bottom-bar sections (the "More" tab is added by the shell).
  final List<Feature> tabs;

  /// Everything else, shown in the More grid.
  final List<Feature> more;

  Feature? find(String key) {
    for (final f in [...tabs, ...more]) {
      if (f.key == key) return f;
    }
    return null;
  }

  int tabIndexOf(String key) => tabs.indexWhere((f) => f.key == key);
}

// Sections every signed-in person gets.
Feature _notices() => Feature(
    key: 'notices', title: 'Notices', subtitle: 'School announcements', icon: Icons.campaign_outlined, builder: (_) => const NoticesView());
Feature _events() => Feature(
    key: 'events', title: 'Events', subtitle: 'What\u2019s coming up', icon: Icons.event_outlined, builder: (_) => const EventsView());
Feature _exams() => Feature(
    key: 'exams', title: 'Exam schedule', subtitle: 'Dates, rooms and times', icon: Icons.quiz_outlined, builder: (_) => const ExamsView());
Feature _classInfo(String subtitle) => Feature(
    key: 'class_info', title: 'Class & subjects', subtitle: subtitle, icon: Icons.class_outlined, builder: (_) => const ClassInfoView());
Feature _faculty() =>
    Feature(key: 'faculty', title: 'Faculty', subtitle: 'Our teachers', icon: Icons.school_outlined, builder: (_) => const FacultyView());
Feature _blog() => Feature(
    key: 'blog', title: 'School blog', subtitle: 'News and stories', icon: Icons.article_outlined, builder: (_) => const BlogView());
Feature _gallery() => Feature(
    key: 'gallery', title: 'Gallery', subtitle: 'School photos', icon: Icons.photo_library_outlined, builder: (_) => const GalleryView());
Feature _downloads() => Feature(
    key: 'downloads',
    title: 'Downloads',
    subtitle: 'Forms and documents',
    icon: Icons.download_outlined,
    builder: (_) => const DownloadsView());
Feature _achievements() => Feature(
    key: 'achievements',
    title: 'Achievements',
    subtitle: 'School milestones',
    icon: Icons.emoji_events_outlined,
    builder: (_) => const AchievementsView());
Feature _profile() => Feature(
    key: 'profile',
    title: 'My profile',
    subtitle: 'Edit what you share',
    icon: Icons.account_circle_outlined,
    builder: (_) => const MyProfileView());
Feature _settings() => Feature(
    key: 'settings',
    title: 'Settings',
    subtitle: 'Theme, password, sign out',
    icon: Icons.settings_outlined,
    builder: (_) => const SettingsView());
Feature _timetable(String subtitle) => Feature(
    key: 'timetable',
    title: 'Timetable',
    subtitle: subtitle,
    icon: Icons.calendar_view_week_rounded,
    builder: (_) => const TimetableView());
Feature _homework(String subtitle) =>
    Feature(key: 'homework', title: 'Homework', subtitle: subtitle, icon: Icons.assignment_outlined, builder: (_) => const HomeworkView());
Feature _marksheets() => Feature(
    key: 'marksheets',
    title: 'Marksheets',
    subtitle: 'Official marksheets',
    icon: Icons.description_outlined,
    builder: (_) => const MarksheetsView());

AppNav navFor(AppUser user, OpenFeature open) {
  switch (user.role) {
    case Role.student:
      return AppNav(
        tabs: [
          Feature(key: 'home', title: 'Home', icon: Icons.home_rounded, builder: (_) => StudentHomeView(onOpen: open)),
          _timetable('Your weekly classes'),
          _homework('Tick it off when done'),
          Feature(key: 'attendance', title: 'Attendance', icon: Icons.fact_check_outlined, builder: (_) => const AttendanceHistoryView()),
        ],
        more: [
          Feature(
              key: 'results',
              title: 'Results',
              subtitle: 'Marks by term',
              icon: Icons.emoji_events_outlined,
              builder: (_) => const ResultsView()),
          _marksheets(),
          _exams(),
          _classInfo('Your class and subjects'),
          _notices(),
          _events(),
          _profile(),
          _faculty(),
          _blog(),
          _gallery(),
          _downloads(),
          _achievements(),
          _settings(),
        ],
      );
    case Role.teacher:
      return AppNav(
        tabs: [
          Feature(key: 'home', title: 'Home', icon: Icons.home_rounded, builder: (_) => TeacherHomeView(onOpen: open)),
          _timetable('Your periods or any class'),
          Feature(key: 'take_attendance', title: 'Attendance', icon: Icons.fact_check_outlined, builder: (_) => const TakeAttendanceView()),
          _homework('Set and review'),
        ],
        more: [
          Feature(
              key: 'results_entry',
              title: 'Enter marks',
              subtitle: 'Class results',
              icon: Icons.edit_note_rounded,
              builder: (_) => const ResultsEntryView()),
          Feature(
              key: 'my_attendance',
              title: 'My attendance',
              subtitle: 'Your own days',
              icon: Icons.event_available_outlined,
              builder: (_) => const AttendanceHistoryView(teacher: true)),
          _exams(),
          Feature(
              key: 'students',
              title: 'Students',
              subtitle: 'Class lists',
              icon: Icons.groups_outlined,
              builder: (_) => const StudentsView()),
          _classInfo('Classes and subjects'),
          _marksheets(),
          _notices(),
          _events(),
          _profile(),
          _faculty(),
          _blog(),
          _gallery(),
          _downloads(),
          _achievements(),
          _settings(),
        ],
      );
    case Role.superAdmin:
      return AppNav(
        tabs: [
          Feature(key: 'home', title: 'Dashboard', icon: Icons.dashboard_rounded, builder: (_) => AdminHomeView(onOpen: open)),
          Feature(key: 'accounts', title: 'Accounts', icon: Icons.manage_accounts_outlined, builder: (_) => const AccountsView()),
          Feature(
              key: 'attendance_report', title: 'Attendance', icon: Icons.fact_check_outlined, builder: (_) => const AttendanceReportView()),
          Feature(key: 'inbox', title: 'Inbox', icon: Icons.inbox_outlined, builder: (_) => const InboxView()),
        ],
        more: [
          _notices(),
          _events(),
          Feature(
              key: 'take_attendance',
              title: 'Mark attendance',
              subtitle: 'Students, by class',
              icon: Icons.how_to_reg_outlined,
              builder: (_) => const TakeAttendanceView()),
          Feature(
              key: 'teacher_attendance',
              title: 'Teacher attendance',
              subtitle: 'Mark teachers',
              icon: Icons.badge_outlined,
              builder: (_) => const TeacherAttendanceAdminView()),
          _classInfo('Sessions, classes, subjects'),
          _timetable('View and edit periods'),
          Feature(
              key: 'students',
              title: 'Students',
              subtitle: 'All students',
              icon: Icons.groups_outlined,
              builder: (_) => const StudentsView()),
          _homework('All classes'),
          _exams(),
          Feature(
              key: 'results_entry',
              title: 'Results',
              subtitle: 'Enter or correct marks',
              icon: Icons.edit_note_rounded,
              builder: (_) => const ResultsEntryView()),
          _marksheets(),
          _faculty(),
          _blog(),
          _gallery(),
          _downloads(),
          _achievements(),
          _settings(),
        ],
      );
  }
}
