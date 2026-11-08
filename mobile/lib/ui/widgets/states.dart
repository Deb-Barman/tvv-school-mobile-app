import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'neu.dart';

export 'skeletons.dart';

/// Skeleton loading: a soft light sweeps across every placeholder inside it (like YouTube / Facebook).
class Pulse extends StatefulWidget {
  const Pulse({super.key, required this.child});
  final Widget child;

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final base = c.isDark ? const Color(0xFF1E1E24) : const Color(0xFFEAEAEF);
    final glow = c.isDark ? const Color(0xFF34343D) : const Color(0xFFF8F8FB);
    return AnimatedBuilder(
      animation: _ctl,
      child: widget.child,
      builder: (context, child) {
        final t = _ctl.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [base, glow, base],
            stops: [(t - 0.3).clamp(0.0, 1.0), t, (t + 0.3).clamp(0.0, 1.0)],
            tileMode: TileMode.clamp,
          ).createShader(rect),
          child: child,
        );
      },
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 10});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: c.inset, borderRadius: BorderRadius.circular(radius)));
  }
}

/// A list of card-shaped placeholders (rows with a leading circle and two text lines).
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.count = 6, this.header = false});
  final int count;
  final bool header;

  @override
  Widget build(BuildContext context) {
    return Pulse(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          if (header) ...[const SkeletonBox(height: 120, radius: 16), const SizedBox(height: 16)],
          for (var i = 0; i < count; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: NeuCard(
                padding: const EdgeInsets.all(14),
                inset: true,
                child: Row(children: [
                  const SkeletonBox(width: 44, height: 44, radius: 22),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Align(alignment: Alignment.centerLeft, child: FractionallySizedBox(widthFactor: 0.5 + 0.15 * (i % 3), child: const SkeletonBox(height: 14))),
                    const SizedBox(height: 10),
                    const SkeletonBox(height: 11),
                  ])),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message = ''});
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(color: c.inset, shape: BoxShape.circle),
          child: Icon(icon, size: 36, color: c.accent),
        ),
        const SizedBox(height: 20),
        Text(title, textAlign: TextAlign.center, style: c.h2),
        if (message.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: c.small.copyWith(fontSize: 14))
        ],
      ]),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry, this.offline = false});
  final String message;
  final VoidCallback onRetry;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(color: c.inset, shape: BoxShape.circle),
            child: Icon(offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded, size: 36, color: c.bad),
          ),
          const SizedBox(height: 20),
          Text(offline ? 'You\u2019re offline' : 'Couldn\u2019t load this', style: c.h2),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: c.small.copyWith(fontSize: 14)),
          const SizedBox(height: 22),
          NeuButton(label: 'Try again', icon: Icons.refresh_rounded, onPressed: onRetry, expand: false),
        ]),
      ),
    );
  }
}

/// Loads data, shows a skeleton until it ARRIVES (never half a page), a clear error with Retry if it fails,
/// and pull-to-refresh once it is there. [builder] must return a scrollable (see [PageList]).
class AsyncPage<T> extends StatefulWidget {
  const AsyncPage({super.key, required this.load, required this.builder, this.skeleton = const ListSkeleton(), this.refreshable = true});

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;
  final Widget skeleton;

  /// Turn off when the content contains its own AsyncPage (otherwise two pull-to-refresh spinners would show).
  final bool refreshable;

  @override
  State<AsyncPage<T>> createState() => _AsyncPageState<T>();
}

class _AsyncPageState<T> extends State<AsyncPage<T>> {
  T? _data;
  bool _hasData = false;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    if (!_hasData) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final d = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = d;
        _hasData = true;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!_hasData) _error = e;
      });
      if (_hasData) toast(context, errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasData) {
      final content = widget.builder(context, _data as T, _run);
      return widget.refreshable ? RefreshIndicator(onRefresh: _run, child: content) : content;
    }
    if (_loading) return widget.skeleton;
    final e = _error;
    return ErrorState(message: e == null ? 'Please try again.' : errorText(e), offline: e is ApiException && e.isNetwork, onRetry: _run);
  }
}
