import '../../core/json.dart';

class Notice {
  const Notice({required this.id, required this.title, required this.body, this.targetClass = '', this.createdByName = '', this.createdAt});

  final String id;
  final String title;
  final String body;
  final String targetClass;
  final String createdByName;
  final DateTime? createdAt;

  static Notice fromJson(Json j) => Notice(
        id: str(j, 'id'),
        title: str(j, 'title'),
        body: str(j, 'body'),
        targetClass: str(j, 'target_class'),
        createdByName: str(j, 'created_by_name'),
        createdAt: dateTimeOrNull(j, 'created_at'),
      );
}

class SchoolEvent {
  const SchoolEvent({required this.id, required this.title, this.description = '', required this.date, this.audience = ''});

  final String id;
  final String title;
  final String description;
  final DateTime? date;
  final String audience;

  static SchoolEvent fromJson(Json j) => SchoolEvent(
        id: str(j, 'id'),
        title: str(j, 'title'),
        description: str(j, 'description'),
        date: dateOnlyOrNull(j, 'event_date'),
        audience: str(j, 'audience'),
      );
}

class Article {
  const Article(
      {required this.id, required this.title, required this.slug, this.excerpt = '', required this.body, this.coverUrl, this.createdAt});

  final String id;
  final String title;
  final String slug;
  final String excerpt;
  final String body;
  final String? coverUrl;
  final DateTime? createdAt;

  static Article fromJson(Json j) => Article(
        id: str(j, 'id'),
        title: str(j, 'title'),
        slug: str(j, 'slug'),
        excerpt: str(j, 'excerpt'),
        body: str(j, 'body'),
        coverUrl: strOrNull(j, 'cover_image'),
        createdAt: dateTimeOrNull(j, 'created_at'),
      );
}

class GalleryImage {
  const GalleryImage({required this.id, this.caption = '', this.url});

  final String id;
  final String caption;
  final String? url;

  static GalleryImage fromJson(Json j) => GalleryImage(id: str(j, 'id'), caption: str(j, 'caption'), url: strOrNull(j, 'image'));
}

class SchoolForm {
  const SchoolForm({required this.id, required this.title, this.url, this.createdAt});

  final String id;
  final String title;
  final String? url;
  final DateTime? createdAt;

  static SchoolForm fromJson(Json j) => SchoolForm(
        id: str(j, 'id'),
        title: str(j, 'title'),
        url: strOrNull(j, 'download_url') ?? strOrNull(j, 'file'),
        createdAt: dateTimeOrNull(j, 'created_at'),
      );
}

class Achievement {
  const Achievement(
      {required this.id, required this.title, this.description = '', required this.year, this.category = 'OTHER', this.imageUrl});

  final String id;
  final String title;
  final String description;
  final int year;
  final String category;
  final String? imageUrl;

  String get categoryLabel =>
      const {'ACADEMIC': 'Academic', 'SPORTS': 'Sports', 'ARTS': 'Arts & culture', 'OTHER': 'Other'}[category] ?? category;

  static Achievement fromJson(Json j) => Achievement(
        id: str(j, 'id'),
        title: str(j, 'title'),
        description: str(j, 'description'),
        year: intOr(j, 'year'),
        category: str(j, 'category', 'OTHER'),
        imageUrl: strOrNull(j, 'image'),
      );
}

class Admission {
  const Admission(
      {required this.id,
      required this.applicantName,
      required this.guardianContact,
      required this.applyingForClass,
      this.message = '',
      this.status = 'PENDING',
      this.submittedAt});

  final String id;
  final String applicantName;
  final String guardianContact;
  final String applyingForClass;
  final String message;
  final String status;
  final DateTime? submittedAt;

  static const statuses = ['PENDING', 'CONTACTED', 'CLOSED'];

  static Admission fromJson(Json j) => Admission(
        id: str(j, 'id'),
        applicantName: str(j, 'applicant_name'),
        guardianContact: str(j, 'guardian_contact'),
        applyingForClass: str(j, 'applying_for_class'),
        message: str(j, 'message'),
        status: str(j, 'status', 'PENDING'),
        submittedAt: dateTimeOrNull(j, 'submitted_at'),
      );
}

class ContactMessage {
  const ContactMessage(
      {required this.id,
      required this.name,
      this.email = '',
      this.phone = '',
      required this.subject,
      required this.message,
      this.status = 'NEW',
      this.createdAt});

  final String id;
  final String name;
  final String email;
  final String phone;
  final String subject;
  final String message;
  final String status;
  final DateTime? createdAt;

  static const statuses = ['NEW', 'READ', 'REPLIED'];

  static ContactMessage fromJson(Json j) => ContactMessage(
        id: str(j, 'id'),
        name: str(j, 'name'),
        email: str(j, 'email'),
        phone: str(j, 'phone'),
        subject: str(j, 'subject'),
        message: str(j, 'message'),
        status: str(j, 'status', 'NEW'),
        createdAt: dateTimeOrNull(j, 'created_at'),
      );
}
