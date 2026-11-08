import 'package:flutter/material.dart';

import 'neu.dart';
import 'states.dart';

/// Loading placeholders that have the SAME shape as the real screens (so people can see the layout before the data
/// arrives, like YouTube / Facebook). Every one of them shimmers through [Pulse].

const _pagePad = EdgeInsets.fromLTRB(16, 8, 16, 16);

class _Circle extends StatelessWidget {
  const _Circle(this.size);
  final double size;
  @override
  Widget build(BuildContext context) => SkeletonBox(width: size, height: size, radius: size / 2);
}

/// A feed post: header (circle + two lines), a title line and two text lines. [image] adds a picture block.
class _PostShape extends StatelessWidget {
  const _PostShape({this.image = false});
  final bool image;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Row(children: [
            const _Circle(38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Align(alignment: Alignment.centerLeft, child: FractionallySizedBox(widthFactor: 0.45, child: const SkeletonBox(height: 12))),
                const SizedBox(height: 7),
                Align(alignment: Alignment.centerLeft, child: FractionallySizedBox(widthFactor: 0.3, child: const SkeletonBox(height: 10))),
              ]),
            ),
          ]),
        ),
        if (image) const AspectRatio(aspectRatio: 16 / 10, child: SkeletonBox(radius: 0, height: double.infinity)),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Align(alignment: Alignment.centerLeft, child: FractionallySizedBox(widthFactor: 0.7, child: const SkeletonBox(height: 16))),
            const SizedBox(height: 12),
            const SkeletonBox(height: 11),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: FractionallySizedBox(widthFactor: 0.8, child: const SkeletonBox(height: 11))),
          ]),
        ),
      ]),
    );
  }
}

/// Notices / feed posts.
class PostFeedSkeleton extends StatelessWidget {
  const PostFeedSkeleton({super.key, this.count = 3, this.image = false});
  final int count;
  final bool image;

  @override
  Widget build(BuildContext context) => Pulse(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: _pagePad,
          children: [
            for (var i = 0; i < count; i++) Padding(padding: const EdgeInsets.only(bottom: 14), child: _PostShape(image: image)),
          ],
        ),
      );
}

/// Dashboards: story row, greeting header, a big card, then rows.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Pulse(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
        children: [
          SizedBox(
            height: 96,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              for (var i = 0; i < 4; i++)
                const Column(children: [_Circle(64), SizedBox(height: 8), SkeletonBox(width: 50, height: 10)]),
            ]),
          ),
          const SizedBox(height: 14),
          const Row(children: [
            _Circle(68),
            SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SkeletonBox(width: 90, height: 11),
                SizedBox(height: 10),
                SkeletonBox(width: 170, height: 22),
                SizedBox(height: 10),
                SkeletonBox(width: 80, height: 18, radius: 9),
              ]),
            ),
          ]),
          const SizedBox(height: 22),
          const _PostShape(),
          const SizedBox(height: 22),
          const SkeletonBox(width: 130, height: 16),
          const SizedBox(height: 12),
          for (var i = 0; i < 3; i++) const Padding(padding: EdgeInsets.only(bottom: 8), child: SkeletonBox(height: 58, radius: 14)),
        ],
      ),
    );
  }
}

/// Blog: big picture, title, two lines.
class ArticleListSkeleton extends StatelessWidget {
  const ArticleListSkeleton({super.key});
  @override
  Widget build(BuildContext context) => const PostFeedSkeleton(count: 2, image: true);
}

/// Gallery mosaic: one big tile, two small, then a row of three.
class MosaicSkeleton extends StatelessWidget {
  const MosaicSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Pulse(
      child: LayoutBuilder(builder: (context, box) {
        const g = 2.0;
        final small = (box.maxWidth - 2 * g) / 3;
        final big = small * 2 + g;
        Widget row3() => Padding(
              padding: const EdgeInsets.only(top: g),
              child: Row(children: [
                for (var i = 0; i < 3; i++) ...[if (i > 0) const SizedBox(width: g), SkeletonBox(width: small, height: small, radius: 0)],
              ]),
            );
        return ListView(physics: const NeverScrollableScrollPhysics(), padding: EdgeInsets.zero, children: [
          const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 12), child: SkeletonBox(width: 150, height: 16)),
          Row(children: [
            SkeletonBox(width: big, height: big, radius: 0),
            const SizedBox(width: g),
            Column(children: [
              SkeletonBox(width: small, height: small, radius: 0),
              const SizedBox(height: g),
              SkeletonBox(width: small, height: small, radius: 0),
            ]),
          ]),
          row3(),
          row3(),
          row3(),
        ]);
      }),
    );
  }
}

/// Trophy-style cards.
class AchievementSkeleton extends StatelessWidget {
  const AchievementSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Pulse(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: _pagePad,
          children: [
            for (var i = 0; i < 3; i++)
              const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: NeuCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      _Circle(46),
                      SizedBox(width: 12),
                      Expanded(child: SkeletonBox(height: 16)),
                    ]),
                    SizedBox(height: 14),
                    SkeletonBox(height: 11),
                    SizedBox(height: 8),
                    SkeletonBox(height: 11),
                    SizedBox(height: 8),
                    SkeletonBox(width: 160, height: 11),
                    SizedBox(height: 14),
                    Row(children: [SkeletonBox(width: 54, height: 22, radius: 11), SizedBox(width: 8), SkeletonBox(width: 80, height: 22, radius: 11)]),
                  ]),
                ),
              ),
          ],
        ),
      );
}

/// A profile page: ring picture + name, pills, then sections.
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Pulse(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: _pagePad,
          children: [
            const Row(children: [
              _Circle(92),
              SizedBox(width: 18),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SkeletonBox(width: 160, height: 20),
                  SizedBox(height: 12),
                  Row(children: [SkeletonBox(width: 64, height: 22, radius: 11), SizedBox(width: 8), SkeletonBox(width: 80, height: 22, radius: 11)]),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            const SkeletonBox(height: 14),
            const SizedBox(height: 22),
            for (var i = 0; i < 3; i++) const Padding(padding: EdgeInsets.only(bottom: 12), child: SkeletonBox(height: 84, radius: 16)),
          ],
        ),
      );
}

/// Timetable: selector, day strip, period rows.
class TimetableSkeleton extends StatelessWidget {
  const TimetableSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Pulse(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: _pagePad,
          children: [
            const SkeletonBox(height: 44, radius: 12),
            const SizedBox(height: 12),
            Row(children: [
              for (var i = 0; i < 6; i++) ...[if (i > 0) const SizedBox(width: 6), const Expanded(child: SkeletonBox(height: 38, radius: 19))],
            ]),
            const SizedBox(height: 16),
            for (var i = 0; i < 5; i++)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: NeuCard(
                  padding: EdgeInsets.all(14),
                  radius: 14,
                  child: Row(children: [
                    SkeletonBox(width: 64, height: 12),
                    SizedBox(width: 14),
                    Expanded(child: SkeletonBox(height: 14)),
                    SizedBox(width: 14),
                    SkeletonBox(width: 40, height: 12),
                  ]),
                ),
              ),
          ],
        ),
      );
}
