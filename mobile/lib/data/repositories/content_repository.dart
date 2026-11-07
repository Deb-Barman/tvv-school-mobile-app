import '../../core/api_client.dart';
import '../../core/json.dart';
import '../models/content.dart';

class ContentRepository {
  ContentRepository(this._api);
  final ApiClient _api;

  // Notices: everyone reads, Super Admin writes
  Future<List<Notice>> notices() async => (await _api.listAll('/notices/')).map(Notice.fromJson).toList();

  Future<Notice> saveNotice({String? id, required String title, required String body, String targetClass = ''}) async {
    final payload = {'title': title, 'body': body, 'target_class': targetClass};
    final data = id == null ? await _api.post('/notices/', payload) : await _api.patch('/notices/$id/', payload);
    return Notice.fromJson(data);
  }

  Future<void> deleteNotice(String id) => _api.delete('/notices/$id/');

  // Events
  Future<List<SchoolEvent>> events() async => (await _api.listAll('/content/events/')).map(SchoolEvent.fromJson).toList();

  Future<SchoolEvent> saveEvent(
      {String? id, required String title, String description = '', required DateTime date, String audience = ''}) async {
    final payload = {'title': title, 'description': description, 'event_date': isoDate(date), 'audience': audience};
    final data = id == null ? await _api.post('/content/events/', payload) : await _api.patch('/content/events/$id/', payload);
    return SchoolEvent.fromJson(data);
  }

  Future<void> deleteEvent(String id) => _api.delete('/content/events/$id/');

  // Public website content (read-only in the app; managed on the website)
  Future<List<Article>> articles() async =>
      (await _api.listAll('/content/articles/public/', pageSize: 50, maxPages: 4)).map(Article.fromJson).toList();

  Future<List<GalleryImage>> gallery() async =>
      (await _api.listAll('/content/gallery/public/', pageSize: 60, maxPages: 4)).map(GalleryImage.fromJson).toList();

  Future<List<SchoolForm>> downloads() async => (await _api.listAll('/content/forms/public/')).map(SchoolForm.fromJson).toList();

  Future<List<Achievement>> achievements() async =>
      (await _api.listAll('/content/achievements/public/')).map(Achievement.fromJson).toList();

  // Super Admin inboxes
  Future<List<Admission>> admissions() async => (await _api.listAll('/content/admissions/')).map(Admission.fromJson).toList();

  Future<Admission> setAdmissionStatus(String id, String status) async =>
      Admission.fromJson(await _api.patch('/content/admissions/$id/', {'status': status}));

  Future<void> deleteAdmission(String id) => _api.delete('/content/admissions/$id/');

  Future<List<ContactMessage>> messages() async => (await _api.listAll('/content/contact/')).map(ContactMessage.fromJson).toList();

  Future<ContactMessage> setMessageStatus(String id, String status) async =>
      ContactMessage.fromJson(await _api.patch('/content/contact/$id/', {'status': status}));

  Future<void> deleteMessage(String id) => _api.delete('/content/contact/$id/');
}
