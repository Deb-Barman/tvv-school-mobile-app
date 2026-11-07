import 'package:flutter/material.dart';

import '../../../data/models/content.dart';
import '../../../data/models/profile.dart';
import '../../../state/app_scope.dart';
import '../../format.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/neu.dart';
import '../../widgets/states.dart';
import '../profile/public_profile_screen.dart';

// ================================================================= faculty

class FacultyView extends StatelessWidget {
  const FacultyView({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    return AsyncPage<List<FacultyMember>>(
      load: svc.academics.faculty,
      builder: (ctx, items, reload) {
        final c = AppColors.of(ctx);
        return PageList(children: [
          if (items.isEmpty)
            const EmptyState(
                icon: Icons.school_outlined,
                title: 'Faculty list is empty',
                message: 'Teachers will appear here once the school adds them.'),
          for (final t in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: NeuCard(
                onTap: t.username == null
                    ? null
                    : () => Navigator.of(ctx).push(MaterialPageRoute<void>(
                        builder: (_) => PublicProfileScreen(role: 'teacher', username: t.username!, fallbackName: t.fullName))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Avatar(name: t.fullName, url: t.photo, size: 56),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.fullName, style: c.h2),
                      if (t.headline.isNotEmpty) Text(t.headline, style: c.small.copyWith(fontSize: 13.5)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        if (t.department.isNotEmpty) Pill(t.department),
                        if (t.yearsExperience != null) Pill('${t.yearsExperience} yrs experience', tone: 'good'),
                        for (final s in t.subjects) Pill(s, tone: 'warn'),
                      ]),
                      if (t.bio.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(t.bio, style: c.body, maxLines: 3, overflow: TextOverflow.ellipsis)),
                    ]),
                  ),
                  if (t.username != null) Icon(Icons.chevron_right_rounded, color: c.muted),
                ]),
              ),
            ),
        ]);
      },
    );
  }
}

// ================================================================= blog

class BlogView extends StatelessWidget {
  const BlogView({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    return AsyncPage<List<Article>>(
      load: svc.content.articles,
      builder: (ctx, items, reload) {
        final c = AppColors.of(ctx);
        return PageList(children: [
          if (items.isEmpty)
            const EmptyState(icon: Icons.article_outlined, title: 'No articles yet', message: 'School news and stories will appear here.'),
          for (final a in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: NeuCard(
                padding: EdgeInsets.zero,
                onTap: () => Navigator.of(ctx).push(MaterialPageRoute<void>(builder: (_) => ArticleScreen(article: a))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (a.coverUrl != null) NetImage(a.coverUrl, height: 170, width: double.infinity, radius: 20),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.title, style: c.h2),
                      const SizedBox(height: 6),
                      Text(stripHtml(a.excerpt.isNotEmpty ? a.excerpt : a.body),
                          maxLines: 3, overflow: TextOverflow.ellipsis, style: c.body),
                      const SizedBox(height: 10),
                      Text(fmtDate(a.createdAt), style: c.small),
                    ]),
                  ),
                ]),
              ),
            ),
        ]);
      },
    );
  }
}

class ArticleScreen extends StatelessWidget {
  const ArticleScreen({super.key, required this.article});
  final Article article;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ScreenScaffold(
      title: 'Blog',
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
        if (article.coverUrl != null)
          Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: NetImage(article.coverUrl, height: 200, width: double.infinity, radius: 22)),
        Text(article.title, style: c.display),
        const SizedBox(height: 8),
        Text(fmtDate(article.createdAt), style: c.small),
        const SizedBox(height: 18),
        Text(stripHtml(article.body), style: c.body.copyWith(fontSize: 15.5, height: 1.6)),
      ]),
    );
  }
}

// ================================================================= gallery

class GalleryView extends StatelessWidget {
  const GalleryView({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    return AsyncPage<List<GalleryImage>>(
      load: svc.content.gallery,
      skeleton: const _GallerySkeleton(),
      builder: (ctx, items, reload) {
        final c = AppColors.of(ctx);
        if (items.isEmpty)
          return const PageList(children: [
            EmptyState(icon: Icons.photo_library_outlined, title: 'No photos yet', message: 'School photos will appear here.')
          ]);
        return GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.9),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final g = items[i];
            return NeuCard(
              padding: const EdgeInsets.all(6),
              radius: 18,
              onTap: () => showFullImage(ctx, g.url, title: g.caption),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: NetImage(g.url, width: double.infinity, height: double.infinity, radius: 14)),
                if (g.caption.isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
                      child: Text(g.caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: c.small.copyWith(color: c.text))),
              ]),
            );
          },
        );
      },
    );
  }
}

/// The loading state is a photo grid, like the real page.
class _GallerySkeleton extends StatelessWidget {
  const _GallerySkeleton();

  @override
  Widget build(BuildContext context) {
    return Pulse(
      child: GridView.count(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.9,
        children: [for (var i = 0; i < 6; i++) const SkeletonBox(radius: 18)],
      ),
    );
  }
}

// ================================================================= downloads

class DownloadsView extends StatelessWidget {
  const DownloadsView({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    return AsyncPage<List<SchoolForm>>(
      load: svc.content.downloads,
      builder: (ctx, items, reload) {
        final c = AppColors.of(ctx);
        return PageList(children: [
          if (items.isEmpty)
            const EmptyState(
                icon: Icons.download_outlined,
                title: 'No downloads yet',
                message: 'Forms and documents from the school office will appear here.'),
          for (final f in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: NeuCard(
                onTap: () => openLink(ctx, f.url),
                child: Row(children: [
                  Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(14)),
                      child: Icon(Icons.description_outlined, color: c.accent)),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(f.title, style: c.bodyStrong),
                    if (f.createdAt != null) Text(fmtDate(f.createdAt), style: c.small)
                  ])),
                  Icon(Icons.open_in_new_rounded, color: c.muted, size: 20),
                ]),
              ),
            ),
        ]);
      },
    );
  }
}

// ================================================================= achievements

class AchievementsView extends StatelessWidget {
  const AchievementsView({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    return AsyncPage<List<Achievement>>(
      load: svc.content.achievements,
      builder: (ctx, items, reload) {
        final c = AppColors.of(ctx);
        return PageList(children: [
          if (items.isEmpty)
            const EmptyState(
                icon: Icons.emoji_events_outlined, title: 'No achievements yet', message: 'School achievements will appear here.'),
          for (final a in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: NeuCard(
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(14)),
                      child: Icon(Icons.emoji_events_rounded, color: c.accent)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.title, style: c.h2),
                      if (a.description.isNotEmpty)
                        Padding(padding: const EdgeInsets.only(top: 4), child: Text(a.description, style: c.body)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, children: [Pill('${a.year}', tone: 'good'), Pill(a.categoryLabel)]),
                    ]),
                  ),
                ]),
              ),
            ),
        ]);
      },
    );
  }
}
