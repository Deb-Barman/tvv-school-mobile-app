import 'package:flutter/material.dart';

/// One picture in the full-screen viewer.
class ViewerPhoto {
  const ViewerPhoto(this.url, {this.caption = '', this.heroTag});
  final String url;
  final String caption;
  final Object? heroTag;
}

/// Opens the full-screen viewer: swipe left/right between pictures, pinch or double-tap to zoom, tap to hide the bars.
Future<void> openPhotoViewer(BuildContext context, List<ViewerPhoto> photos, {int initial = 0}) {
  if (photos.isEmpty) return Future<void>.value();
  return Navigator.of(context).push<void>(PageRouteBuilder<void>(
    opaque: false,
    barrierColor: Colors.black,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, __, ___) => PhotoViewerScreen(photos: photos, initial: initial.clamp(0, photos.length - 1)),
    transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
  ));
}

class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen({super.key, required this.photos, this.initial = 0});
  final List<ViewerPhoto> photos;
  final int initial;

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final PageController _pages = PageController(initialPage: widget.initial);
  late int _page = widget.initial;
  bool _chrome = true;
  bool _zoomed = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photos[_page];
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        PageView.builder(
          controller: _pages,
          physics: _zoomed ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
          itemCount: widget.photos.length,
          onPageChanged: (i) => setState(() {
            _page = i;
            _zoomed = false;
          }),
          itemBuilder: (_, i) => _ZoomablePhoto(
            photo: widget.photos[i],
            zoomed: _zoomed && i == _page,
            onZoomChanged: (z) {
              if (_zoomed != z) setState(() => _zoomed = z);
            },
            onTap: () => setState(() => _chrome = !_chrome),
          ),
        ),
        // top bar
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: _chrome ? 1 : 0,
            child: IgnorePointer(
              ignoring: !_chrome,
              child: Container(
                decoration: const BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xAA000000), Color(0x00000000)])),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 4, 16, 18),
                    child: Row(children: [
                      IconButton(
                        tooltip: 'Close',
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const Spacer(),
                      if (widget.photos.length > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(color: const Color(0x66000000), borderRadius: BorderRadius.circular(20)),
                          child: Text('${_page + 1} / ${widget.photos.length}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
        // caption
        if (photo.caption.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _chrome ? 1 : 0,
              child: IgnorePointer(
                child: Container(
                  decoration: const BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xCC000000), Color(0x00000000)])),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 36, 20, 20),
                      child: Text(photo.caption, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4)),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

class _ZoomablePhoto extends StatefulWidget {
  const _ZoomablePhoto({required this.photo, required this.zoomed, required this.onZoomChanged, required this.onTap});
  final ViewerPhoto photo;
  final bool zoomed;
  final ValueChanged<bool> onZoomChanged;
  final VoidCallback onTap;

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto> {
  final TransformationController _t = TransformationController();

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  void _checkZoom() => widget.onZoomChanged(_t.value.getMaxScaleOnAxis() > 1.02);

  void _doubleTap(Size size) {
    if (_t.value.getMaxScaleOnAxis() > 1.02) {
      _t.value = Matrix4.identity();
    } else {
      const s = 2.6;
      _t.value = Matrix4.identity()
        ..translate(-size.width * (s - 1) / 2, -size.height * (s - 1) / 2)
        ..scale(s);
    }
    _checkZoom();
  }

  @override
  Widget build(BuildContext context) {
    Widget image = Image.network(
      widget.photo.url,
      fit: BoxFit.contain,
      loadingBuilder: (_, child, p) => p == null ? child : const Center(child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2.4)),
      errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 56)),
    );
    if (widget.photo.heroTag != null) image = Hero(tag: widget.photo.heroTag!, child: image);
    return LayoutBuilder(builder: (context, box) {
      final size = Size(box.maxWidth, box.maxHeight);
      return GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: () => _doubleTap(size),
        child: InteractiveViewer(
          transformationController: _t,
          minScale: 1,
          maxScale: 5,
          panEnabled: widget.zoomed,
          onInteractionEnd: (_) => _checkZoom(),
          child: SizedBox(width: size.width, height: size.height, child: image),
        ),
      );
    });
  }
}
