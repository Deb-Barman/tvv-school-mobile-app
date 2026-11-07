import 'package:flutter/material.dart';

import '../../../data/models/profile.dart';
import '../../../state/app_scope.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/neu.dart';
import '../../widgets/states.dart';

/// Someone's public page - only what they chose to share. The server answers 404 for private pages.
class PublicProfileScreen extends StatelessWidget {
  const PublicProfileScreen({super.key, required this.role, required this.username, this.fallbackName = 'Profile'});
  final String role;
  final String username;
  final String fallbackName;

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    return ScreenScaffold(
      title: fallbackName,
      body: AsyncPage<PublicProfile>(
        load: () => svc.profile.publicProfile(role: role, username: username),
        skeleton: const DashboardSkeleton(),
        builder: (ctx, p, reload) => PageList(children: profileSections(ctx, p)),
      ),
    );
  }
}

const _socialNames = {
  'instagram': 'Instagram',
  'facebook': 'Facebook',
  'x': 'X',
  'youtube': 'YouTube',
  'linkedin': 'LinkedIn',
  'github': 'GitHub',
  'telegram': 'Telegram',
  'threads': 'Threads',
  'pinterest': 'Pinterest',
  'snapchat': 'Snapchat',
  'behance': 'Behance',
  'medium': 'Medium',
  'website': 'Website',
};

String socialName(String key) => _socialNames[key] ?? key;

List<Widget> profileSections(BuildContext ctx, PublicProfile p) {
  final c = AppColors.of(ctx);

  Widget block(String title, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: NeuCard(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(title.toUpperCase(), style: c.eyebrow), const SizedBox(height: 10), child])),
      );

  Widget chips(List<String> items, [String tone = 'accent']) =>
      Wrap(spacing: 8, runSpacing: 8, children: [for (final i in items) Pill(i, tone: tone)]);

  final photo = p.photo;
  return [
    NeuCard(
      depth: 3,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(children: [
        Avatar(name: p.fullName, url: photo, size: 96, onTap: photo == null ? null : () => showFullImage(ctx, photo, title: p.fullName)),
        const SizedBox(height: 14),
        Text(p.fullName, textAlign: TextAlign.center, style: c.display.copyWith(fontSize: 23)),
        if (p.headline.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 4), child: Text(p.headline, textAlign: TextAlign.center, style: c.body)),
        const SizedBox(height: 12),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 6, children: [
          Pill(p.role == 'teacher' ? 'Teacher' : 'Student', tone: p.role == 'teacher' ? 'warn' : 'accent'),
          if (p.classLabel != null) Pill(p.classLabel!, tone: 'good'),
          if (p.department != null) Pill(p.department!),
          if (p.city.isNotEmpty) Pill(p.city, icon: Icons.place_outlined),
        ]),
      ]),
    ),
    if (p.quote.isNotEmpty)
      block('Quote', Text('\u201c${p.quote}\u201d', style: c.body.copyWith(fontStyle: FontStyle.italic, fontSize: 15.5))),
    if (p.about.isNotEmpty) block('About', Text(p.about, style: c.body)),
    if (p.background.isNotEmpty) block('Background', Text(p.background, style: c.body)),
    if (p.qualification.isNotEmpty ||
        p.yearsExperience != null ||
        p.favoriteSubject.isNotEmpty ||
        p.careerGoal.isNotEmpty ||
        p.age != null ||
        p.gender.isNotEmpty)
      block(
        'Details',
        Column(children: [
          if (p.qualification.isNotEmpty) InfoRow('Qualification', p.qualification),
          if (p.yearsExperience != null) InfoRow('Experience', '${p.yearsExperience} years'),
          if (p.favoriteSubject.isNotEmpty) InfoRow('Favourite subject', p.favoriteSubject),
          if (p.careerGoal.isNotEmpty) InfoRow('Career goal', p.careerGoal),
          if (p.age != null) InfoRow('Age', '${p.age}'),
          if (p.gender.isNotEmpty) InfoRow('Gender', '${p.gender[0].toUpperCase()}${p.gender.substring(1)}'),
        ]),
      ),
    if (p.talents.isNotEmpty) block('Talents', chips(p.talents, 'good')),
    if (p.interests.isNotEmpty) block('Interests', chips(p.interests)),
    if (p.languages.isNotEmpty) block('Languages', chips(p.languages, 'warn')),
    if (p.learning.isNotEmpty) block('Learning now', chips(p.learning)),
    if (p.skills.isNotEmpty)
      block(
        'Skills',
        Column(children: [
          for (final s in p.skills)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Expanded(flex: 3, child: Text(s.name, style: c.bodyStrong)),
                Expanded(
                  flex: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(value: s.level / 5, minHeight: 8, backgroundColor: c.inset, color: c.accent),
                  ),
                ),
              ]),
            ),
        ]),
      ),
    if (p.projectItems.isNotEmpty)
      block(
        'Projects',
        Column(children: [
          for (final pr in p.projectItems)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.rocket_launch_outlined, size: 20, color: c.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(pr.title, style: c.bodyStrong),
                    if (pr.summary.isNotEmpty) Text(pr.summary, style: c.small.copyWith(fontSize: 13.5)),
                    if (pr.link.isNotEmpty)
                      TextButton(
                          onPressed: () => openLink(ctx, pr.link),
                          style: TextButton.styleFrom(
                              padding: EdgeInsets.zero, minimumSize: const Size(0, 28), alignment: Alignment.centerLeft),
                          child: const Text('Open project')),
                  ]),
                ),
              ]),
            ),
        ]),
      )
    else if (p.projects.isNotEmpty)
      block('Projects', Text(p.projects, style: c.body)),
    if (p.achievementItems.isNotEmpty)
      block(
        'Achievements',
        Column(children: [
          for (final a in p.achievementItems)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.emoji_events_outlined, size: 20, color: c.warn),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.year.isEmpty ? a.title : '${a.title} (${a.year})', style: c.bodyStrong),
                  if (a.detail.isNotEmpty) Text(a.detail, style: c.small.copyWith(fontSize: 13.5))
                ])),
              ]),
            ),
        ]),
      )
    else if (p.achievements.isNotEmpty)
      block('Achievements', Text(p.achievements, style: c.body)),
    if (p.socialLinks.isNotEmpty || p.website.isNotEmpty)
      block(
        'Links',
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (p.website.isNotEmpty && !p.socialLinks.containsKey('website'))
            NeuButton(
                label: 'Website',
                icon: Icons.language_rounded,
                expand: false,
                compact: true,
                secondary: true,
                onPressed: () => openLink(ctx, p.website)),
          for (final e in p.socialLinks.entries)
            NeuButton(
                label: socialName(e.key),
                icon: Icons.open_in_new_rounded,
                expand: false,
                compact: true,
                secondary: true,
                onPressed: () => openLink(ctx, e.value)),
        ]),
      ),
  ];
}
