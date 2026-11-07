import 'package:flutter/material.dart';

import '../../../state/app_scope.dart';
import '../../features.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/neu.dart';

/// Role-based home: bottom navigation (4 main sections + More), lazy tabs, hardware-back returns to the first tab.
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
    final me = context.me;
    final moreIndex = _nav.tabs.length;
    final titles = [..._nav.tabs.map((f) => f.title), 'More'];
    final profile = _nav.find('profile') ?? _nav.find('settings');

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
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          title: Text(titles[_index], style: c.h1),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Avatar(name: me.fullName, size: 38, onTap: profile == null ? null : () => pushFeature(context, profile)),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: IndexedStack(
            index: _index,
            children: [
              for (var i = 0; i < _nav.tabs.length; i++) _visited.contains(i) ? _nav.tabs[i].builder(context) : const SizedBox.shrink(),
              _visited.contains(moreIndex) ? MoreView(nav: _nav, open: _open) : const SizedBox.shrink(),
            ],
          ),
        ),
        bottomNavigationBar: _BottomBar(
          index: _index,
          items: [
            for (final f in _nav.tabs) (f.icon, f.title),
            (Icons.grid_view_rounded, 'More'),
          ],
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

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.index, required this.items, required this.onTap});
  final int index;
  final List<(IconData, String)> items;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
          color: c.surface,
          boxShadow: [BoxShadow(color: c.shadowDark.withValues(alpha: 0.5), blurRadius: 18, offset: const Offset(0, -4))]),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Row(children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == index,
                  label: items[i].$2,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => onTap(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration:
                          BoxDecoration(color: i == index ? c.accentSoft : Colors.transparent, borderRadius: BorderRadius.circular(18)),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(items[i].$1, size: 23, color: i == index ? c.accent : c.muted),
                        const SizedBox(height: 3),
                        Text(items[i].$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: i == index ? FontWeight.w800 : FontWeight.w600,
                                color: i == index ? c.accent : c.muted)),
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class MoreView extends StatelessWidget {
  const MoreView({super.key, required this.nav, required this.open});
  final AppNav nav;
  final OpenFeature open;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final me = context.me;
    return PageList(children: [
      NeuCard(
        child: Row(children: [
          Avatar(name: me.fullName, size: 52),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text(me.fullName, style: c.h2), Text('${me.role.label} \u00b7 @${me.username}', style: c.small)])),
        ]),
      ),
      const SizedBox(height: 14),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.2,
        children: [
          for (final f in nav.more)
            NeuCard(
              onTap: () => open(f.key),
              padding: const EdgeInsets.all(14),
              radius: 20,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(12)),
                    child: Icon(f.icon, color: c.accent, size: 21)),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f.title, style: c.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (f.subtitle.isNotEmpty)
                    Text(f.subtitle, style: c.small.copyWith(fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ]),
            ),
        ],
      ),
    ]);
  }
}
