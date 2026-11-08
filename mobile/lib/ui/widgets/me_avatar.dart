import 'package:flutter/material.dart';

import '../../state/app_scope.dart';
import 'common.dart';

/// The signed-in person's own picture (falls back to their initials until/unless a photo exists).
class MeAvatar extends StatelessWidget {
  const MeAvatar({super.key, this.size = 46, this.ring = false, this.onTap});
  final double size;
  final bool ring;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final name = context.me.fullName;
    return ValueListenableBuilder<String?>(
      valueListenable: context.svc.myPhoto,
      builder: (_, url, __) => Avatar(name: name, url: url, size: size, ring: ring, onTap: onTap),
    );
  }
}
