import 'package:flutter/material.dart';

import '../../../core/json.dart';
import '../../../data/models/profile.dart';
import '../../../state/app_scope.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/neu.dart';
import '../../widgets/states.dart';
import 'public_profile_screen.dart';

/// "My profile": what the school shows about me, and the editor.
class MyProfileView extends StatelessWidget {
  const MyProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    final me = context.me;
    return AsyncPage<MyProfile>(
      load: svc.profile.mine,
      skeleton: const ProfileSkeleton(),
      builder: (ctx, p, reload) {
        final c = AppColors.of(ctx);
        final photo = p.displayPhoto;
        if (svc.myPhoto.value != photo) WidgetsBinding.instance.addPostFrameCallback((_) => svc.myPhoto.value = photo);
        return PageList(children: [
          NeuCard(
            depth: 3,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 14),
            child: Column(children: [
              Avatar(
                  name: p.fullName.isEmpty ? me.fullName : p.fullName,
                  url: photo,
                  size: 92,
                  onTap: photo == null ? null : () => showFullImage(ctx, photo, title: p.fullName)),
              const SizedBox(height: 14),
              Text(p.fullName.isEmpty ? me.fullName : p.fullName, textAlign: TextAlign.center, style: c.display.copyWith(fontSize: 23)),
              const SizedBox(height: 4),
              Text('@${p.username}', style: c.small),
              if (p.headline.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 8), child: Text(p.headline, textAlign: TextAlign.center, style: c.body)),
              const SizedBox(height: 12),
              Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 6, children: [
                Pill(me.role.label, tone: me.isTeacher ? 'warn' : 'accent'),
                if (p.classLabel != null) Pill(p.classLabel!, tone: 'good'),
                if (p.department != null) Pill(p.department!),
                Pill(p.isPublic ? 'Public page ON' : 'Public page OFF',
                    tone: p.isPublic ? 'good' : 'warn', icon: p.isPublic ? Icons.public_rounded : Icons.lock_outline_rounded),
              ]),
              const SizedBox(height: 18),
              NeuButton(
                label: 'Edit profile',
                icon: Icons.edit_rounded,
                onPressed: () async {
                  final saved = await Navigator.of(ctx).push<bool>(MaterialPageRoute<bool>(builder: (_) => EditProfileScreen(profile: p)));
                  if (saved == true) {
                    if (ctx.mounted) toast(ctx, 'Profile saved.');
                    await reload();
                  }
                },
              ),
              if (p.isPublic) ...[
                const SizedBox(height: 10),
                NeuButton(
                  label: 'View my public page',
                  icon: Icons.visibility_outlined,
                  secondary: true,
                  onPressed: () => Navigator.of(ctx).push(MaterialPageRoute<void>(
                      builder: (_) => PublicProfileScreen(
                          role: me.isTeacher ? 'teacher' : 'student', username: p.username, fallbackName: 'My public page'))),
                ),
              ],
            ]),
          ),
          NeuCard(
            margin: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ACCOUNT', style: c.eyebrow),
              const SizedBox(height: 8),
              InfoRow('Name', p.fullName.isEmpty ? me.fullName : p.fullName, icon: Icons.person_outline_rounded),
              InfoRow('Username', p.username, icon: Icons.alternate_email_rounded),
              if (p.classLabel != null) InfoRow('Class', p.classLabel!, icon: Icons.class_outlined),
              if (p.department != null) InfoRow('Department', p.department!, icon: Icons.apartment_outlined),
              if (me.phone.isNotEmpty) InfoRow('Phone', me.phone, icon: Icons.phone_outlined),
            ]),
          ),
          if (p.about.isNotEmpty) _Block('About', Text(p.about, style: c.body)),
          if (p.city.isNotEmpty || p.favoriteSubject.isNotEmpty || p.careerGoal.isNotEmpty || p.qualification.isNotEmpty || p.age != null)
            _Block(
              'Details',
              Column(children: [
                if (p.city.isNotEmpty) InfoRow('City', p.city),
                if (p.qualification.isNotEmpty) InfoRow('Qualification', p.qualification),
                if (p.favoriteSubject.isNotEmpty) InfoRow('Favourite subject', p.favoriteSubject),
                if (p.careerGoal.isNotEmpty) InfoRow('Career goal', p.careerGoal),
                if (p.age != null) InfoRow('Age', '${p.age}${p.showAge ? '' : ' (hidden)'}'),
              ]),
            ),
          if (p.talents.isNotEmpty)
            _Block('Talents', Wrap(spacing: 8, runSpacing: 8, children: [for (final t in p.talents) Pill(t, tone: 'good')])),
          if (p.interests.isNotEmpty)
            _Block('Interests', Wrap(spacing: 8, runSpacing: 8, children: [for (final t in p.interests) Pill(t)])),
          if (p.socialLinks.isNotEmpty)
            _Block(
              'Links',
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final e in p.socialLinks.entries)
                  NeuButton(
                      label: socialName(e.key),
                      icon: Icons.open_in_new_rounded,
                      expand: false,
                      compact: true,
                      secondary: true,
                      onPressed: () => openLink(ctx, e.value))
              ]),
            ),
          if (p.projectCount > 0 || p.skills.isNotEmpty || p.achievementCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Skills, project cards and achievement cards are edited on the school website.',
                  textAlign: TextAlign.center, style: c.small),
            ),
        ]);
      },
    );
  }
}

class _Block extends StatelessWidget {
  const _Block(this.title, this.child);
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: NeuCard(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(title.toUpperCase(), style: c.eyebrow), const SizedBox(height: 10), child])),
    );
  }
}

// ================================================================= editor

List<String> _splitList(String raw) => raw.split(RegExp(r'[,\n]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

/// Platforms with their own field; other saved links are kept untouched.
const _editableSocial = ['instagram', 'facebook', 'x', 'youtube', 'linkedin', 'github', 'telegram', 'website'];

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.profile});
  final MyProfile profile;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _key = GlobalKey<FormState>();
  late final MyProfile p = widget.profile;
  late final _headline = TextEditingController(text: p.headline);
  late final _about = TextEditingController(text: p.about);
  late final _background = TextEditingController(text: p.background);
  late final _quote = TextEditingController(text: p.quote);
  late final _city = TextEditingController(text: p.city);
  late final _fav = TextEditingController(text: p.favoriteSubject);
  late final _goal = TextEditingController(text: p.careerGoal);
  late final _qualification = TextEditingController(text: p.qualification);
  late final _languages = TextEditingController(text: p.languages.join(', '));
  late final _talents = TextEditingController(text: p.talents.join(', '));
  late final _interests = TextEditingController(text: p.interests.join(', '));
  late final _learning = TextEditingController(text: p.learning.join(', '));
  late final _photo = TextEditingController(text: p.photoLink);
  late final _age = TextEditingController(text: p.age?.toString() ?? '');
  late final Map<String, TextEditingController> _social = {
    for (final k in _editableSocial) k: TextEditingController(text: p.socialLinks[k] ?? '')
  };
  late bool _public = p.isPublic;
  late bool _showAge = p.showAge;
  late bool _showGender = p.showGender;
  late String _gender = p.gender;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _headline,
      _about,
      _background,
      _quote,
      _city,
      _fav,
      _goal,
      _qualification,
      _languages,
      _talents,
      _interests,
      _learning,
      _photo,
      _age,
      ..._social.values
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isTeacher => p.role.toUpperCase() == 'TEACHER';

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final links = <String, String>{
      // Keep links this form has no field for (threads, medium...) exactly as they are.
      for (final e in p.socialLinks.entries)
        if (!_editableSocial.contains(e.key)) e.key: e.value,
      for (final k in _editableSocial) k: _social[k]!.text.trim(),
    };
    final changes = <String, dynamic>{
      'headline': _headline.text.trim(),
      'about': _about.text.trim(),
      'background': _background.text.trim(),
      'quote': _quote.text.trim(),
      'city': _city.text.trim(),
      'favorite_subject': _fav.text.trim(),
      'career_goal': _goal.text.trim(),
      if (_isTeacher) 'qualification': _qualification.text.trim(),
      'languages': _splitList(_languages.text),
      'talents': _splitList(_talents.text),
      'interests': _splitList(_interests.text),
      'learning': _splitList(_learning.text),
      'photo_link': _photo.text.trim(),
      'age': int.tryParse(_age.text.trim()),
      'show_age': _showAge,
      'gender': _gender,
      'show_gender': _showGender,
      'is_public': _public,
      'social_links': links,
    };
    try {
      await context.svc.profile.update(asJson(changes));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    Widget gap([double h = 14]) => SizedBox(height: h);
    return ScreenScaffold(
      title: 'Edit profile',
      body: Form(
        key: _key,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
          NeuCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('VISIBILITY', style: c.eyebrow),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _public,
                onChanged: (v) => setState(() => _public = v),
                title: Text('Public profile page', style: c.bodyStrong),
                subtitle: Text('Anyone with your link can see what you share below. Turn off to keep it private.', style: c.small),
              ),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _showAge,
                  onChanged: (v) => setState(() => _showAge = v),
                  title: Text('Show my age', style: c.bodyStrong)),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _showGender,
                  onChanged: (v) => setState(() => _showGender = v),
                  title: Text('Show my gender', style: c.bodyStrong)),
            ]),
          ),
          gap(18),
          Text(
              'Anything you write here can appear on your public page. Please do not add phone numbers, addresses or other private details.',
              style: c.small),
          gap(),
          AppField(
              controller: _photo,
              label: 'Profile photo link',
              hint: 'Paste a Google Drive or image link',
              icon: Icons.image_outlined,
              keyboard: TextInputType.url,
              maxLines: 2),
          gap(),
          AppField(
              controller: _headline,
              label: 'Headline',
              hint: 'One line about you',
              icon: Icons.short_text_rounded,
              maxLength: 120,
              capitalization: TextCapitalization.sentences),
          gap(),
          AppField(controller: _about, label: 'About me', maxLines: 5, maxLength: 1200, capitalization: TextCapitalization.sentences),
          gap(),
          AppField(
              controller: _background, label: 'Background', maxLines: 4, maxLength: 1500, capitalization: TextCapitalization.sentences),
          gap(),
          AppField(controller: _quote, label: 'Favourite quote', maxLines: 2, maxLength: 300, capitalization: TextCapitalization.sentences),
          gap(),
          AppField(controller: _city, label: 'City', icon: Icons.place_outlined, maxLength: 80, capitalization: TextCapitalization.words),
          gap(),
          if (_isTeacher) ...[
            AppField(
                controller: _qualification,
                label: 'Qualification',
                icon: Icons.school_outlined,
                maxLength: 120,
                capitalization: TextCapitalization.sentences),
            gap(),
          ],
          AppField(
              controller: _fav,
              label: 'Favourite subject',
              icon: Icons.menu_book_outlined,
              maxLength: 80,
              capitalization: TextCapitalization.words),
          gap(),
          AppField(
              controller: _goal,
              label: 'Career goal',
              icon: Icons.flag_outlined,
              maxLength: 120,
              capitalization: TextCapitalization.sentences),
          gap(),
          AppField(
              controller: _age,
              label: 'Age',
              icon: Icons.cake_outlined,
              keyboard: TextInputType.number,
              maxLength: 3,
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null;
                final n = int.tryParse(t);
                return (n == null || n < 4 || n > 100) ? 'Enter an age between 4 and 100' : null;
              }),
          gap(),
          PickerField(
            label: 'Gender',
            value: _gender.isEmpty ? 'Prefer not to say' : '${_gender[0].toUpperCase()}${_gender.substring(1)}',
            onTap: () async {
              final v = await pickOne<String>(context,
                  title: 'Gender',
                  options: const ['', 'male', 'female', 'other'],
                  labelOf: (s) => s.isEmpty ? 'Prefer not to say' : '${s[0].toUpperCase()}${s.substring(1)}',
                  selected: _gender);
              if (v != null) setState(() => _gender = v);
            },
          ),
          gap(),
          AppField(controller: _talents, label: 'Talents', hint: 'Separate with commas', maxLines: 2),
          gap(),
          AppField(controller: _interests, label: 'Interests', hint: 'Separate with commas', maxLines: 2),
          gap(),
          AppField(controller: _languages, label: 'Languages', hint: 'Separate with commas', maxLines: 2),
          gap(),
          AppField(controller: _learning, label: 'Learning now', hint: 'Separate with commas', maxLines: 2),
          gap(20),
          Text('SOCIAL LINKS', style: c.eyebrow),
          const SizedBox(height: 4),
          Text('Paste a link or just your @handle.', style: c.small),
          gap(),
          for (final k in _editableSocial) ...[
            AppField(controller: _social[k]!, label: socialName(k), icon: Icons.link_rounded, keyboard: TextInputType.url, maxLength: 300),
            gap(12),
          ],
          gap(8),
          SaveBar(onSave: _busy ? null : _save, busy: _busy, error: _error, label: 'Save profile'),
        ]),
      ),
    );
  }
}
