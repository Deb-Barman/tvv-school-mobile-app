import 'package:flutter/material.dart';

import '../../../data/models/content.dart';
import '../../../data/models/profile.dart';
import '../../../state/app_scope.dart';
import '../../format.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/insta.dart';
import '../../widgets/neu.dart';
import '../../widgets/photo_viewer.dart';
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

int _readMinutes(String text) {
  final words = text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;
  final m = (words / 200).ceil();
  return m < 1 ? 1 : m;
}

class BlogView extends StatelessWidget {
  const BlogView({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    return AsyncPage<List<Article>>(
      load: svc.content.articles,
      skeleton: const ArticleListSkeleton(),
      builder: (ctx, items, reload) {
        return PageList(children: [
          if (items.isEmpty)
            const EmptyState(icon: Icons.article_outlined, title: 'No articles yet', message: 'School news and stories will appear here.'),
          for (final a in items) Padding(padding: const EdgeInsets.only(bottom: 16), child: _ArticleCard(article: a)),
        ]);
      },
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.article});
  final Article article;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final a = article;
    final text = stripHtml(a.excerpt.isNotEmpty ? a.excerpt : a.body);
    final shape = BorderRadius.circular(18);
    return DecoratedBox(
      decoration: BoxDecoration(color: c.surface, borderRadius: shape, border: Border.all(color: c.edge), boxShadow: c.raised(3)),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: shape,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ArticleScreen(article: a))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Row(children: [
                const SchoolLogo(size: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('TVV School', style: c.bodyStrong.copyWith(fontSize: 14)),
                    Text('${fmtDate(a.createdAt)} \u00b7 ${_readMinutes(stripHtml(a.body))} min read', style: c.small.copyWith(fontSize: 12)),
                  ]),
                ),
              ]),
            ),
            if (a.coverUrl != null && a.coverUrl!.isNotEmpty)
              AspectRatio(aspectRatio: 16 / 10, child: Hero(tag: 'article-${a.id}', child: NetImage(a.coverUrl, radius: 0, width: double.infinity))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.title, style: c.h1.copyWith(fontSize: 20)),
                if (text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(text, maxLines: 3, overflow: TextOverflow.ellipsis, style: c.body.copyWith(color: c.muted)),
                ],
                const SizedBox(height: 12),
                Row(children: [
                  Text('Read article', style: TextStyle(color: c.accent, fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, color: c.accent, size: 18),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A magazine-style article: the cover picture runs to the screen edges (tap it to open it full screen).
class ArticleScreen extends StatelessWidget {
  const ArticleScreen({super.key, required this.article});
  final Article article;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final a = article;
    final hasCover = a.coverUrl != null && a.coverUrl!.isNotEmpty;
    final paragraphs = stripHtml(a.body).split(RegExp(r'\n\s*\n')).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    final back = Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: hasCover ? const Color(0x73000000) : c.inset,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => Navigator.of(context).maybePop(),
          child: SizedBox(width: 42, height: 42, child: Icon(Icons.arrow_back_rounded, color: hasCover ? Colors.white : c.text)),
        ),
      ),
    );
    return Scaffold(
      backgroundColor: c.bg,
      body: ListView(padding: EdgeInsets.zero, children: [
        if (hasCover)
          Stack(children: [
            GestureDetector(
              onTap: () => showFullImage(context, a.coverUrl, title: a.title),
              child: AspectRatio(aspectRatio: 1.05, child: Hero(tag: 'article-${a.id}', child: NetImage(a.coverUrl, radius: 0, width: double.infinity))),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: IgnorePointer(
                child: Container(
                  height: 110,
                  decoration: const BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x99000000), Color(0x00000000)])),
                ),
              ),
            ),
            Positioned(left: 0, top: 0, child: SafeArea(child: back)),
            Positioned(
              right: 14,
              bottom: 38,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0x73000000), borderRadius: BorderRadius.circular(20)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.zoom_out_map_rounded, color: Colors.white, size: 15),
                    SizedBox(width: 5),
                    Text('Tap to enlarge', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
          ])
        else
          SafeArea(bottom: false, child: Align(alignment: Alignment.centerLeft, child: back)),
        Transform.translate(
          offset: Offset(0, hasCover ? -26 : 0),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 48),
            decoration: BoxDecoration(color: c.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(26))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SelectableText(a.title, style: c.display.copyWith(fontSize: 28, height: 1.15)),
              const SizedBox(height: 16),
              Row(children: [
                const SchoolLogo(size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('TVV School', style: c.bodyStrong),
                    Text('${fmtDate(a.createdAt)} \u00b7 ${_readMinutes(stripHtml(a.body))} min read', style: c.small),
                  ]),
                ),
              ]),
              const SizedBox(height: 18),
              const Hairline(),
              const SizedBox(height: 20),
              for (final p in paragraphs)
                Padding(padding: const EdgeInsets.only(bottom: 16), child: SelectableText(p, style: c.body.copyWith(fontSize: 16.5, height: 1.7))),
            ]),
          ),
        ),
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
      skeleton: const MosaicSkeleton(),
      builder: (ctx, all, reload) {
        final c = AppColors.of(ctx);
        final items = all.where((g) => g.url != null && g.url!.isNotEmpty).toList();
        if (items.isEmpty) {
          return const PageList(children: [
            EmptyState(icon: Icons.photo_library_outlined, title: 'No photos yet', message: 'School photos will appear here.')
          ]);
        }
        final photos = [for (final g in items) ViewerPhoto(g.url!, caption: g.caption, heroTag: 'gallery-${g.id}')];
        return LayoutBuilder(builder: (ctx, box) {
          const g = 2.0;
          final w = box.maxWidth;
          final small = (w - 2 * g) / 3;
          final bigSide = small * 2 + g;

          Widget tile(int i, double tw, double th, {bool caption = false}) {
            final item = items[i];
            return SizedBox(
              width: tw,
              height: th,
              child: Semantics(
                button: true,
                label: item.caption.isEmpty ? 'School photo ${i + 1}' : item.caption,
                child: GestureDetector(
                  onTap: () => openPhotoViewer(ctx, photos, initial: i),
                  child: Stack(fit: StackFit.expand, children: [
                    Hero(tag: 'gallery-${item.id}', child: NetImage(item.url, width: tw, height: th, radius: 0)),
                    if (caption && item.caption.isNotEmpty)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 26, 12, 10),
                          decoration: const BoxDecoration(
                              gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xB3000000), Color(0x00000000)])),
                          child: Text(item.caption, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ),
                  ]),
                ),
              ),
            );
          }

          final rows = <Widget>[];
          var i = 0;
          var bigRow = true;
          var bigLeft = true;
          while (i < items.length) {
            final left = items.length - i;
            if (left >= 3 && bigRow) {
              final bigTile = tile(i, bigSide, bigSide, caption: true);
              final stack = Column(children: [tile(i + 1, small, small), const SizedBox(height: g), tile(i + 2, small, small)]);
              rows.add(Row(children: bigLeft ? [bigTile, const SizedBox(width: g), stack] : [stack, const SizedBox(width: g), bigTile]));
              bigLeft = !bigLeft;
              bigRow = false;
              i += 3;
            } else if (left >= 3) {
              rows.add(Row(children: [tile(i, small, small), const SizedBox(width: g), tile(i + 1, small, small), const SizedBox(width: g), tile(i + 2, small, small)]));
              bigRow = true;
              i += 3;
            } else if (left == 2) {
              final half = (w - g) / 2;
              rows.add(Row(children: [tile(i, half, half, caption: true), const SizedBox(width: g), tile(i + 1, half, half, caption: true)]));
              i += 2;
            } else {
              rows.add(tile(i, w, w * 0.8, caption: true));
              i += 1;
            }
            rows.add(const SizedBox(height: g));
          }
          return ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.only(bottom: 40), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(children: [
                Text('School gallery', style: c.h2),
                const Spacer(),
                Text(items.length == 1 ? '1 photo' : '${items.length} photos', style: c.small),
              ]),
            ),
            ...rows,
          ]);
        });
      },
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
      skeleton: const AchievementSkeleton(),
      builder: (ctx, items, reload) {
        return PageList(children: [
          if (items.isEmpty)
            const EmptyState(
                icon: Icons.emoji_events_outlined, title: 'No achievements yet', message: 'School achievements will appear here.'),
          for (final a in items) Padding(padding: const EdgeInsets.only(bottom: 14), child: _AchievementCard(achievement: a)),
        ]);
      },
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.achievement});
  final Achievement achievement;

  void _open(BuildContext context) {
    final a = achievement;
    final c = AppColors.of(context);
    showSheet<void>(
      context,
      (ctx) => SheetBody(
        title: a.title,
        subtitle: '${a.year} \u00b7 ${a.categoryLabel}',
        children: [
          if (a.imageUrl != null && a.imageUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GestureDetector(
                onTap: () => showFullImage(ctx, a.imageUrl, title: a.title),
                child: NetImage(a.imageUrl, width: double.infinity, height: 200, radius: 14),
              ),
            ),
          if (a.description.isNotEmpty) SelectableText(a.description, style: c.body.copyWith(fontSize: 16, height: 1.65)) else Text('No more details.', style: c.small),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final a = achievement;
    final long = a.description.length > 150 || '\n'.allMatches(a.description).length > 2;
    final shape = BorderRadius.circular(18);
    return DecoratedBox(
      decoration: BoxDecoration(color: c.surface, borderRadius: shape, border: Border.all(color: c.edge)),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: shape,
        child: InkWell(
          onTap: () => _open(context),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (a.imageUrl != null && a.imageUrl!.isNotEmpty) AspectRatio(aspectRatio: 16 / 9, child: NetImage(a.imageUrl, radius: 0, width: double.infinity)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.storyGradient),
                    child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.title, style: c.h2.copyWith(fontSize: 17)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 6, children: [Pill('${a.year}', tone: 'good'), Pill(a.categoryLabel)]),
                    ]),
                  ),
                ]),
                if (a.description.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(a.description, maxLines: 4, overflow: TextOverflow.ellipsis, style: c.body),
                  if (long)
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('Read more', style: TextStyle(color: c.accent, fontWeight: FontWeight.w700, fontSize: 13.5))),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
