import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_exception.dart';
import '../theme/tokens.dart';
import '../../core/clock.dart';
import 'insta.dart';
import 'neu.dart';

// ------------------------------------------------------------------ feedback

/// Message that is safe to show to a student; never raw exception text.
String errorText(Object e) => e is ApiException ? e.message : 'Something went wrong. Please try again.';

void toast(BuildContext context, String message, {bool error = false}) {
  final c = AppColors.of(context);
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    content: Row(children: [
      Icon(error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: error ? c.bad : c.good, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(message)),
    ]),
    duration: Duration(seconds: error ? 5 : 3),
  ));
}

Future<bool> confirm(BuildContext context,
    {required String title, required String message, String confirmLabel = 'Delete', bool danger = true}) async {
  final c = AppColors.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: c.h2),
      content: Text(message, style: c.body),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Cancel', style: TextStyle(color: c.muted))),
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel, style: TextStyle(color: danger ? c.bad : c.accent, fontWeight: FontWeight.w700))),
      ],
    ),
  );
  return ok ?? false;
}

/// Opens only web links (http/https). Anything else a user pasted into the system (file:, javascript:, ...) is refused.
Future<void> openLink(BuildContext context, String? url) async {
  final raw = (url ?? '').trim();
  final uri = Uri.tryParse(raw);
  if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http') || uri.host.isEmpty) {
    toast(context, 'That link can\u2019t be opened.', error: true);
    return;
  }
  var launched = false;
  try {
    launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    launched = false;
  }
  if (!launched && context.mounted) toast(context, 'No app could open that link.', error: true);
}

// ------------------------------------------------------------------ sheets + pickers

Future<T?> showSheet<T>(BuildContext context, WidgetBuilder builder) {
  final c = AppColors.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: c.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: SingleChildScrollView(child: builder(ctx)),
    ),
  );
}

/// Standard layout for the inside of a bottom sheet.
class SheetBody extends StatelessWidget {
  const SheetBody({super.key, required this.title, required this.children, this.subtitle});
  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(title, style: c.h1),
        if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, style: c.small)],
        const SizedBox(height: 18),
        ...children,
      ]),
    );
  }
}

/// Replacement for a dropdown: opens a clean list in a sheet.
Future<T?> pickOne<T>(BuildContext context,
    {required String title, required List<T> options, required String Function(T) labelOf, T? selected, String Function(T)? subtitleOf}) {
  final c = AppColors.of(context);
  return showSheet<T>(
    context,
    (ctx) => SheetBody(
      title: title,
      children: [
        if (options.isEmpty)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('Nothing to choose from yet.', style: c.small))),
        for (final o in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: NeuCard(
              inset: o != selected,
              color: o == selected ? c.accentSoft : null,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              radius: 12,
              onTap: () => Navigator.of(ctx).pop(o),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(labelOf(o), style: c.bodyStrong),
                    if (subtitleOf != null && subtitleOf(o).isNotEmpty) Text(subtitleOf(o), style: c.small),
                  ]),
                ),
                if (o == selected) Icon(Icons.check_circle_rounded, color: c.accent),
              ]),
            ),
          ),
      ],
    ),
  );
}

/// A tappable field that shows the current choice (for [pickOne] / dates).
class PickerField extends StatelessWidget {
  const PickerField(
      {super.key,
      required this.label,
      required this.value,
      required this.onTap,
      this.icon = Icons.unfold_more_rounded,
      this.placeholder = 'Choose'});
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final IconData icon;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return NeuCard(
      inset: true,
      radius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: onTap,
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: c.small.copyWith(fontSize: 11.5)),
            const SizedBox(height: 2),
            Text(value == null || value!.isEmpty ? placeholder : value!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (value == null || value!.isEmpty) ? c.small.copyWith(fontSize: 14.5) : c.bodyStrong),
          ]),
        ),
        Icon(icon, color: c.muted, size: 20),
      ]),
    );
  }
}

Future<DateTime?> pickDate(BuildContext context, {DateTime? initial, DateTime? first, DateTime? last}) {
  final now = schoolNow();
  final f = first ?? DateTime(now.year - 3);
  final l = last ?? DateTime(now.year + 3, 12, 31);
  var i = initial ?? now;
  if (i.isBefore(f)) i = f;
  if (i.isAfter(l)) i = l;
  return showDatePicker(context: context, initialDate: i, firstDate: f, lastDate: l);
}

// ------------------------------------------------------------------ inputs

class AppField extends StatelessWidget {
  const AppField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.obscure = false,
    this.keyboard,
    this.maxLines = 1,
    this.validator,
    this.action,
    this.onSubmitted,
    this.suffix,
    this.autofillHints,
    this.enabled = true,
    this.maxLength,
    this.capitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final bool obscure;
  final TextInputType? keyboard;
  final int maxLines;
  final String? Function(String?)? validator;
  final TextInputAction? action;
  final void Function(String)? onSubmitted;
  final Widget? suffix;
  final Iterable<String>? autofillHints;
  final bool enabled;
  final int? maxLength;
  final TextCapitalization capitalization;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    OutlineInputBorder border(Color col, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: col, width: w));
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      maxLines: obscure ? 1 : maxLines,
      minLines: 1,
      maxLength: maxLength,
      enabled: enabled,
      validator: validator,
      textInputAction: action,
      onFieldSubmitted: onSubmitted,
      autofillHints: autofillHints,
      textCapitalization: capitalization,
      style: c.body,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        prefixIcon: icon == null ? null : Icon(icon, size: 20, color: c.muted),
        suffixIcon: suffix,
        filled: true,
        fillColor: c.inset,
        labelStyle: c.small.copyWith(fontSize: 14),
        hintStyle: c.small.copyWith(fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: border(c.edge),
        enabledBorder: border(c.edge),
        focusedBorder: border(c.accent, 1.6),
        errorBorder: border(c.bad),
        focusedErrorBorder: border(c.bad, 1.6),
        disabledBorder: border(c.edge),
      ),
    );
  }
}

String? requiredField(String? v, [String name = 'This']) => (v == null || v.trim().isEmpty) ? '$name is required' : null;

/// Horizontal row of selectable chips (days of the week, filters...).
class ChipBar<T> extends StatelessWidget {
  const ChipBar(
      {super.key,
      required this.items,
      required this.selected,
      required this.labelOf,
      required this.onChanged,
      this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10)});
  final List<T> items;
  final T? selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(children: [
        for (final it in items)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Builder(builder: (_) {
              final on = it == selected;
              return Semantics(
                button: true,
                selected: on,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: on ? c.accent : c.inset,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => onChanged(it),
                      child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                          child: Text(labelOf(it),
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: on ? c.onAccent : c.text))),
                    ),
                  ),
                ),
              );
            }),
          ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ display bits

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing, this.padding = const EdgeInsets.fromLTRB(4, 20, 0, 6)});
  final String text;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: padding,
      child: Row(children: [
        Expanded(child: Text(text, style: c.h2)),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.icon});
  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (icon != null) ...[Icon(icon, size: 18, color: c.muted), const SizedBox(width: 10)],
        SizedBox(width: 112, child: Text(label, style: c.small.copyWith(fontSize: 13.5))),
        Expanded(child: Text(value.isEmpty ? '\u2014' : value, style: c.bodyStrong)),
      ]),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.url, this.size = 46, this.onTap, this.ring = false});
  final String name;
  final String? url;
  final double size;
  final VoidCallback? onTap;

  /// Draw the colourful story ring around the picture.
  final bool ring;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final fallback = Center(child: Text(_initials, style: TextStyle(color: c.accent, fontWeight: FontWeight.w800, fontSize: size * 0.34)));
    final hasUrl = url != null && url!.isNotEmpty;
    final px = (size * MediaQuery.devicePixelRatioOf(context)).round().clamp(48, 800);
    final pic = ColoredBox(
      color: c.accentSoft,
      child: hasUrl
          ? Image.network(url!,
              fit: BoxFit.cover,
              cacheWidth: px,
              errorBuilder: (_, __, ___) => fallback,
              loadingBuilder: (_, child, p) => p == null ? child : fallback)
          : fallback,
    );
    final Widget circle = ring ? GradientRing(size: size, thickness: size > 60 ? 3 : 2, gap: size > 60 ? 3 : 2, child: pic) : SizedBox(width: size, height: size, child: ClipOval(child: pic));
    return Semantics(
      label: name,
      image: true,
      button: onTap != null,
      child: onTap == null ? circle : GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: circle),
    );
  }
}

/// Circular progress with text in the middle.
class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.percent, required this.label, this.sub = '', this.size = 112, this.tone = 'accent'});
  final double percent; // 0..100
  final String label;
  final String sub;
  final double size;
  final String tone;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final col = c.tone(tone);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(percent.clamp(0, 100) / 100, col, c.edge),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: TextStyle(fontSize: size * 0.2, fontWeight: FontWeight.w800, color: c.text)),
            if (sub.isNotEmpty) Text(sub, style: TextStyle(fontSize: size * 0.1, color: c.muted)),
          ]),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction, this.color, this.track);
  final double fraction;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.09;
    final rect = Offset(stroke / 2, stroke / 2) & Size(size.width - stroke, size.height - stroke);
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    final fillPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);
    if (fraction > 0) canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * fraction, false, fillPaint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction || old.color != color || old.track != track;
}

/// Network picture with a graceful fallback.
class NetImage extends StatelessWidget {
  const NetImage(this.url, {super.key, this.fit = BoxFit.cover, this.radius = 16, this.height, this.width});
  final String? url;
  final BoxFit fit;
  final double radius;
  final double? height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final mq = MediaQuery.of(context);
    final target = ((width != null && width!.isFinite) ? width! : mq.size.width) * mq.devicePixelRatio;
    final px = target.round().clamp(64, 1400);
    final placeholder = Container(height: height, width: width, color: c.inset, child: Icon(Icons.image_outlined, color: c.muted));
    if (url == null || url!.isEmpty) return ClipRRect(borderRadius: BorderRadius.circular(radius), child: placeholder);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        url!,
        fit: fit,
        height: height,
        width: width,
        cacheWidth: px,
        errorBuilder: (_, __, ___) => placeholder,
        loadingBuilder: (_, child, p) => p == null ? child : placeholder,
      ),
    );
  }
}

/// Full-screen, pinch-to-zoom picture viewer.
void showFullImage(BuildContext context, String? url, {String? title}) {
  if (url == null || url.isEmpty) return;
  Navigator.of(context).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (ctx) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
          backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(title ?? '', style: const TextStyle(fontSize: 16))),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Image.network(url,
              fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64)),
        ),
      ),
    ),
  ));
}

// ------------------------------------------------------------------ page scaffolding

class ScreenScaffold extends StatelessWidget {
  const ScreenScaffold({super.key, required this.title, required this.body, this.actions, this.fab, this.bottom});
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? fab;
  final PreferredSizeWidget? bottom;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        foregroundColor: c.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Text(title, style: c.h1, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: actions,
        bottom: bottom,
      ),
      floatingActionButton: fab,
      body: SafeArea(top: false, child: body),
    );
  }
}

/// A scrollable that always allows pull-to-refresh, with the app's standard padding.
class PageList extends StatelessWidget {
  const PageList({super.key, required this.children, this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 96)});
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => ListView(physics: const AlwaysScrollableScrollPhysics(), padding: padding, children: children);
}

/// Runs a button action: shows a clear message on failure, optional success message. Returns true on success.
Future<bool> guard(BuildContext context, Future<void> Function() action, {String? success}) async {
  try {
    await action();
    if (success != null && context.mounted) toast(context, success);
    return true;
  } catch (e) {
    if (context.mounted) toast(context, errorText(e), error: true);
    return false;
  }
}

/// Inline error + the main save button at the bottom of a form sheet.
class SaveBar extends StatelessWidget {
  const SaveBar({super.key, required this.onSave, this.busy = false, this.error, this.label = 'Save'});
  final VoidCallback? onSave;
  final bool busy;
  final String? error;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(children: [
      if (error != null && error!.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.error_outline_rounded, size: 18, color: c.bad),
            const SizedBox(width: 8),
            Expanded(child: Text(error!, style: TextStyle(color: c.bad, fontSize: 13.5, height: 1.35))),
          ]),
        ),
      NeuButton(label: label, icon: Icons.check_rounded, busy: busy, onPressed: onSave),
    ]);
  }
}

/// Plain-text version of text that may contain simple HTML.
String stripHtml(String input) {
  var s =
      input.replaceAll(RegExp(r'<\s*br\s*/?>', caseSensitive: false), '\n').replaceAll(RegExp(r'</\s*p\s*>', caseSensitive: false), '\n\n');
  s = s.replaceAll(RegExp(r'<[^>]*>'), '');
  s = s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  return s.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}
