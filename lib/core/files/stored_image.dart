import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:community_admin/core/files/stored_file_links_provider.dart';

/// [Image.network] for a stored file's raw URL (`photo_url`, `image_url`,
/// ...): resolves the signed link first, then loads it.
///
/// [placeholder] shows while the link resolves and the image loads;
/// [unavailable] (defaults to [placeholder]) when there is no URL, the file
/// is not available to this user, or the image fails to load.
class StoredNetworkImage extends ConsumerStatefulWidget {
  const StoredNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit,
    this.placeholder,
    this.unavailable,
  });

  final String? url;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final WidgetBuilder? placeholder;
  final WidgetBuilder? unavailable;

  @override
  ConsumerState<StoredNetworkImage> createState() => _StoredNetworkImageState();
}

class _StoredNetworkImageState extends ConsumerState<StoredNetworkImage> {
  late Future<String?> _link;

  @override
  void initState() {
    super.initState();
    _link = _resolve();
  }

  @override
  void didUpdateWidget(covariant StoredNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _link = _resolve();
  }

  Future<String?> _resolve() =>
      ref.read(storedFileLinksProvider).resolve(widget.url);

  Widget _box(BuildContext context, WidgetBuilder? builder) => SizedBox(
    width: widget.width,
    height: widget.height,
    child: builder?.call(context),
  );

  @override
  Widget build(BuildContext context) {
    final unavailable = widget.unavailable ?? widget.placeholder;
    return FutureBuilder<String?>(
      future: _link,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return _box(context, widget.placeholder);
        }
        final link = snap.data;
        if (link == null) return _box(context, unavailable);
        return Image.network(
          link,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : _box(context, widget.placeholder),
          errorBuilder: (context, error, stackTrace) =>
              _box(context, unavailable),
        );
      },
    );
  }
}

/// A [CircleAvatar] showing a stored photo; [fallback] (initials, an icon)
/// shows while it loads and when there is no photo to show.
class StoredAvatar extends StatelessWidget {
  const StoredAvatar({
    super.key,
    required this.url,
    this.radius = 20,
    this.backgroundColor,
    this.fallback,
  });

  final String? url;
  final double radius;
  final Color? backgroundColor;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final diameter = radius * 2;
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: ClipOval(
        child: StoredNetworkImage(
          url: url,
          width: diameter,
          height: diameter,
          fit: BoxFit.cover,
          placeholder: (_) => Center(child: fallback),
        ),
      ),
    );
  }
}
