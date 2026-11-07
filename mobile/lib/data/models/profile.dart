import '../../core/json.dart';

class SkillItem {
  const SkillItem(this.name, this.level);
  final String name;
  final int level;

  static SkillItem fromJson(Json j) => SkillItem(str(j, 'name'), intOr(j, 'level', 3).clamp(1, 5));
  Json toJson() => {'name': name, 'level': level};
}

class ProjectItem {
  const ProjectItem({required this.title, this.summary = '', this.link = '', this.tags = const []});
  final String title;
  final String summary;
  final String link;
  final List<String> tags;

  static ProjectItem fromJson(Json j) =>
      ProjectItem(title: str(j, 'title'), summary: str(j, 'summary'), link: str(j, 'link'), tags: strList(j, 'tags'));
}

class AchievementItem {
  const AchievementItem({required this.title, this.year = '', this.kind = 'other', this.detail = ''});
  final String title;
  final String year;
  final String kind;
  final String detail;

  static AchievementItem fromJson(Json j) =>
      AchievementItem(title: str(j, 'title'), year: str(j, 'year'), kind: str(j, 'kind', 'other'), detail: str(j, 'detail'));
}

/// The signed-in person's own profile (GET/PATCH /auth/me/profile/).
class MyProfile {
  const MyProfile({
    required this.username,
    required this.fullName,
    required this.role,
    this.publicPath = '',
    this.classLabel,
    this.department,
    this.yearsExperience,
    this.headline = '',
    this.about = '',
    this.background = '',
    this.talents = const [],
    this.interests = const [],
    this.languages = const [],
    this.learning = const [],
    this.skills = const [],
    this.city = '',
    this.favoriteSubject = '',
    this.careerGoal = '',
    this.qualification = '',
    this.quote = '',
    this.photoUrl,
    this.photoLink = '',
    this.isPublic = false,
    this.age,
    this.showAge = false,
    this.gender = '',
    this.showGender = false,
    this.socialLinks = const {},
    this.visibility = const {},
    this.resultsMode = 'summary',
    this.projectCount = 0,
    this.achievementCount = 0,
  });

  final String username;
  final String fullName;
  final String role;
  final String publicPath;
  final String? classLabel;
  final String? department;
  final int? yearsExperience;
  final String headline;
  final String about;
  final String background;
  final List<String> talents;
  final List<String> interests;
  final List<String> languages;
  final List<String> learning;
  final List<SkillItem> skills;
  final String city;
  final String favoriteSubject;
  final String careerGoal;
  final String qualification;
  final String quote;
  final String? photoUrl;
  final String photoLink;
  final bool isPublic;
  final int? age;
  final bool showAge;
  final String gender;
  final bool showGender;
  final Map<String, String> socialLinks;
  final Map<String, bool> visibility;
  final String resultsMode;
  final int projectCount;
  final int achievementCount;

  static MyProfile fromJson(Json j) {
    final social = <String, String>{};
    asJson(j['social_links']).forEach((k, v) {
      if (v is String && v.isNotEmpty) social[k] = v;
    });
    final vis = <String, bool>{};
    asJson(j['visibility']).forEach((k, v) {
      if (v is bool) vis[k] = v;
    });
    return MyProfile(
      username: str(j, 'username'),
      fullName: str(j, 'full_name'),
      role: str(j, 'role'),
      publicPath: str(j, 'public_path'),
      classLabel: strOrNull(j, 'class_label'),
      department: strOrNull(j, 'department'),
      yearsExperience: intOrNull(j, 'years_experience'),
      headline: str(j, 'headline'),
      about: str(j, 'about'),
      background: str(j, 'background'),
      talents: strList(j, 'talents'),
      interests: strList(j, 'interests'),
      languages: strList(j, 'languages'),
      learning: strList(j, 'learning'),
      skills: asJsonList(j['skills']).map(SkillItem.fromJson).toList(),
      city: str(j, 'city'),
      favoriteSubject: str(j, 'favorite_subject'),
      careerGoal: str(j, 'career_goal'),
      qualification: str(j, 'qualification'),
      quote: str(j, 'quote'),
      photoUrl: strOrNull(j, 'photo'),
      photoLink: str(j, 'photo_link'),
      isPublic: boolOr(j, 'is_public'),
      age: intOrNull(j, 'age'),
      showAge: boolOr(j, 'show_age'),
      gender: str(j, 'gender'),
      showGender: boolOr(j, 'show_gender'),
      socialLinks: social,
      visibility: vis,
      resultsMode: str(j, 'results_mode', 'summary'),
      projectCount: asJsonList(j['project_list']).length,
      achievementCount: asJsonList(j['achievement_items']).length,
    );
  }

  /// Photo to display: a pasted link wins, otherwise the uploaded picture.
  String? get displayPhoto => photoLink.isNotEmpty ? photoLink : photoUrl;
}

/// Someone else's public page (GET /auth/profiles/<role>/<username>/). Only what the owner chose to share.
class PublicProfile {
  const PublicProfile({
    required this.role,
    required this.username,
    required this.fullName,
    this.headline = '',
    this.about = '',
    this.background = '',
    this.talents = const [],
    this.interests = const [],
    this.skills = const [],
    this.learning = const [],
    this.achievements = '',
    this.achievementItems = const [],
    this.projectItems = const [],
    this.website = '',
    this.photo,
    this.city = '',
    this.languages = const [],
    this.favoriteSubject = '',
    this.careerGoal = '',
    this.qualification = '',
    this.quote = '',
    this.projects = '',
    this.socialLinks = const {},
    this.age,
    this.gender = '',
    this.classLabel,
    this.department,
    this.yearsExperience,
  });

  final String role;
  final String username;
  final String fullName;
  final String headline;
  final String about;
  final String background;
  final List<String> talents;
  final List<String> interests;
  final List<SkillItem> skills;
  final List<String> learning;
  final String achievements;
  final List<AchievementItem> achievementItems;
  final List<ProjectItem> projectItems;
  final String website;
  final String? photo;
  final String city;
  final List<String> languages;
  final String favoriteSubject;
  final String careerGoal;
  final String qualification;
  final String quote;
  final String projects;
  final Map<String, String> socialLinks;
  final int? age;
  final String gender;
  final String? classLabel;
  final String? department;
  final int? yearsExperience;

  static PublicProfile fromJson(Json j) {
    final social = <String, String>{};
    asJson(j['social_links']).forEach((k, v) {
      if (v is String && v.isNotEmpty) social[k] = v;
    });
    return PublicProfile(
      role: str(j, 'role'),
      username: str(j, 'username'),
      fullName: str(j, 'full_name'),
      headline: str(j, 'headline'),
      about: str(j, 'about'),
      background: str(j, 'background'),
      talents: strList(j, 'talents'),
      interests: strList(j, 'interests'),
      skills: asJsonList(j['skills']).map(SkillItem.fromJson).toList(),
      learning: strList(j, 'learning'),
      achievements: str(j, 'achievements'),
      achievementItems: asJsonList(j['achievement_items']).map(AchievementItem.fromJson).toList(),
      projectItems: asJsonList(j['project_list']).map(ProjectItem.fromJson).toList(),
      website: str(j, 'website'),
      photo: strOrNull(j, 'photo'),
      city: str(j, 'city'),
      languages: strList(j, 'languages'),
      favoriteSubject: str(j, 'favorite_subject'),
      careerGoal: str(j, 'career_goal'),
      qualification: str(j, 'qualification'),
      quote: str(j, 'quote'),
      projects: str(j, 'projects'),
      socialLinks: social,
      age: intOrNull(j, 'age'),
      gender: str(j, 'gender'),
      classLabel: strOrNull(j, 'class_label'),
      department: strOrNull(j, 'department'),
      yearsExperience: intOrNull(j, 'years_experience'),
    );
  }
}

/// A teacher on the Faculty list (GET /academics/teachers/public/).
class FacultyMember {
  const FacultyMember(
      {required this.fullName,
      this.department = '',
      this.bio = '',
      this.yearsExperience,
      this.subjects = const [],
      this.username,
      this.photo,
      this.headline = '',
      this.qualification = ''});

  final String fullName;
  final String department;
  final String bio;
  final int? yearsExperience;
  final List<String> subjects;

  /// Set only when the teacher published their own profile page.
  final String? username;
  final String? photo;
  final String headline;
  final String qualification;

  static FacultyMember fromJson(Json j) {
    final card = asJson(j['profile']);
    return FacultyMember(
      fullName: str(j, 'full_name'),
      department: str(j, 'department'),
      bio: str(j, 'bio'),
      yearsExperience: intOrNull(j, 'years_experience'),
      subjects: strList(j, 'subjects'),
      username: strOrNull(card, 'username'),
      photo: strOrNull(card, 'photo'),
      headline: str(card, 'headline'),
      qualification: str(card, 'qualification'),
    );
  }
}
