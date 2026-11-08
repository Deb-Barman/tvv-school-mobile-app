import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/content.dart';
import '../../format.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/insta.dart';
import '../../widgets/neu.dart';

/// Opens one notice in full.
void openNotice(BuildContext context, Notice notice) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => NoticeDetailScreen(notice: notice)));
}

/// A notice read in full: who posted it, when, for which class, and the whole text (selectable, copyable).
class NoticeDetailScreen extends StatelessWidget {
  const NoticeDetailScreen({super.key, required this.notice});
  final Notice notice;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final author = notice.createdByName.isNotEmpty ? notice.createdByName : 'School office';
    return ScreenScaffold(
      title: 'Notice',
      actions: [
        IconButton(
          tooltip: 'Copy text',
          icon: Icon(Icons.copy_rounded, color: c.text),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: '${notice.title}\n\n${notice.body}'));
            if (context.mounted) toast(context, 'Notice copied.');
          },
        ),
      ],
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 48), children: [
        Row(children: [
          const SchoolLogo(size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(author, maxLines: 1, overflow: TextOverflow.ellipsis, style: c.bodyStrong),
              Text(fmtDate(notice.createdAt), style: c.small),
            ]),
          ),
          if (notice.targetClass.isNotEmpty) Flexible(child: Pill(notice.targetClass, tone: 'good', icon: Icons.groups_outlined)),
        ]),
        const SizedBox(height: 22),
        SelectableText(notice.title, style: c.display.copyWith(fontSize: 26)),
        const SizedBox(height: 16),
        const Hairline(),
        const SizedBox(height: 16),
        SelectableText(notice.body, style: c.body.copyWith(fontSize: 16.5, height: 1.65)),
      ]),
    );
  }
}
