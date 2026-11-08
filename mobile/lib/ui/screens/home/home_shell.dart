import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config.dart';
import '../../../state/app_scope.dart';
import '../../features.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/insta.dart';
import '../../widgets/me_avatar.dart';

/// Role-based home: Instagram-style bottom bar (4 main sections + your picture), lazy tabs, back returns to the first tab.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final Set<int> _visited = {0};
  late AppNav _nav;
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_ready) {
      _ready = true;
      _nav = navFor(context.me, _open);
      final svc = context.svc;
      svc.myPhoto.value = null; // a different person may have been signed in before
      svc.refreshMyPhoto();
    }
  }

  /// Opens a section: switches tab if it is one, otherwise pushes it as a screen.
  void _open(String key) {
    final tab = _nav.tabIndexOf(key);
    if (tab >= 0) {
      setState(() {
        _index = tab;
        _visited.add(tab);
      });
      return;
    }
    final f = _nav.find(key);
    if (f == null) return;
    pushFeature(context, f);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final moreIndex = _nav.tabs.length;
    final titles = [..._nav.tabs.map((f) => f.title), 'Menu'];
    final notices = _nav.find('notices');
    final offline = context.svc.offlineData;

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _index = 0);
      },
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.bg,
          foregroundColor: c.text,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleSpacing: 16,
          title: _index == 0
              ? Row(children: [
                  const SchoolLogo(size: 34),
                  const SizedBox(width: 10),
                  Flexible(child: Text('TVV School', maxLines: 1, overflow: TextOverflow.ellipsis, style: c.h1.copyWith(fontSize: 22))),
                ])
              : Text(titles[_index], maxLines: 1, overflow: TextOverflow.ellipsis, style: c.h1),
          actions: [
            if (notices != null)
              IconButton(
                tooltip: 'Notices',
                icon: Icon(Icons.campaign_outlined, color: c.text, size: 26),
                onPressed: () => pushFeature(context, notices),
              ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(children: [
            ValueListenableBuilder<bool>(
              valueListenable: offline,
              builder: (_, isOffline, __) => AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: isOffline
                    ? Container(
                        width: double.infinity,
                        color: c.warn.withValues(alpha: 0.16),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                        child: Row(children: [
                          Icon(Icons.cloud_off_rounded, size: 16, color: c.warn),
                          const SizedBox(width: 8),
                          Expanded(child: Text('You are offline \u2014 showing your last saved data.', style: TextStyle(fontSize: 12.5, color: c.text))),
                        ]),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: [
                  for (var i = 0; i < _nav.tabs.length; i++) _visited.contains(i) ? _nav.tabs[i].builder(context) : const SizedBox.shrink(),
                  _visited.contains(moreIndex) ? MoreView(nav: _nav, open: _open) : const SizedBox.shrink(),
                ],
              ),
            ),
          ]),
        ),
        bottomNavigationBar: _BottomBar(
          index: _index,
          tabs: _nav.tabs,
          onTap: (i) => setState(() {
            _index = i;
            _visited.add(i);
          }),
        ),
      ),
    );
  }
}

void pushFeature(BuildContext context, Feature f) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (ctx) => ScreenScaffold(title: f.title, body: f.builder(ctx))));
}

/// Icons only, hairline on top, filled icon for the selected tab, your own picture as the last tab.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.index, required this.tabs, required this.onTap});
  final int index;
  final List<Feature> tabs;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    Widget cell(int i, String label, Widget icon) => Expanded(
          child: Semantics(
            button: true,
            selected: i == index,
            label: label,
            child: InkResponse(
              onTap: () {
                HapticFeedback.selectionClick();
                onTap(i);
              },
              radius: 32,
              child: SizedBox(height: 52, child: Center(child: ExcludeSemantics(child: icon))),
            ),
          ),
        );
    return DecoratedBox(
      decoration: BoxDecoration(color: c.bg, border: Border(top: BorderSide(color: c.edge))),
      child: SafeArea(
        top: false,
        child: Row(children: [
          for (var i = 0; i < tabs.length; i++)
            cell(i, tabs[i].title, Icon(i == index ? (tabs[i].activeIcon ?? tabs[i].icon) : tabs[i].icon, size: 27, color: i == index ? c.text : c.muted)),
          cell(tabs.length, 'Menu', MeAvatar(size: 30, ring: tabs.length == index)),
        ]),
      ),
    );
  }
}

/// The last tab: your picture and name, then every other section as a clean list.
class MoreView extends StatelessWidget {
  const MoreView({super.key, required this.nav, required this.open});
  final AppNav nav;
  final OpenFeature open;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final me = context.me;
    return PageList(padding: const EdgeInsets.fromLTRB(0, 8, 0, 40), children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Row(children: [
          const MeAvatar(size: 84, ring: true),
          const SizedBox(width: 18),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(me.fullName, maxLines: 2, overflow: TextOverflow.ellipsis, style: c.h1),
              const SizedBox(height: 2),
              Text('@${me.username}', maxLines: 1, overflow: TextOverflow.ellipsis, style: c.small),
              const SizedBox(height: 8),
              Text('${me.role.label} \u00b7 ${AppConfig.schoolName}', maxLines: 2, overflow: TextOverflow.ellipsis, style: c.small.copyWith(color: c.text)),
            ]),
          ),
        ]),
      ),
      const Hairline(),
      for (final f in nav.more) ...[
        InkWell(
          onTap: () => open(f.key),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            child: Row(children: [
              Icon(f.icon, color: c.text, size: 26),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: c.bodyStrong.copyWith(fontSize: 15.5)),
                  if (f.subtitle.isNotEmpty) Text(f.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: c.small),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: c.muted),
            ]),
          ),
        ),
        const Hairline(indent: 62),
      ],
    ]);
  }
}
