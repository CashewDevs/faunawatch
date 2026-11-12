import 'package:flutter/material.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';

/// Author, title, and description of a post. The full description stays hidden
/// until expanded so the caption does not cover the photos.
class PostCaption extends StatefulWidget {
  const PostCaption({super.key, required this.post, this.now});
  final FeedPost post;

  /// The time ages are measured from; defaults to now.
  final DateTime? now;

  @override
  State<PostCaption> createState() => _PostCaptionState();
}

class _PostCaptionState extends State<PostCaption> {
  static const _collapsedLines = 2;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final mutedColor = theme.colorScheme.onSurfaceVariant;
    final bodyStyle = textTheme.bodyMedium;
    final detailStyle = textTheme.bodySmall?.copyWith(color: mutedColor);
    final age = formatPostAge(post.feedAt, widget.now ?? DateTime.now());
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.4,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                text: post.authorName,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                children: [TextSpan(text: ' · $age', style: detailStyle)],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              post.title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (post.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              LayoutBuilder(
                builder: (context, constraints) {
                  final overflows = _overflows(
                    post.description,
                    bodyStyle,
                    constraints.maxWidth,
                    Directionality.of(context),
                    MediaQuery.textScalerOf(context),
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.description,
                        maxLines: _expanded ? null : _collapsedLines,
                        overflow: _expanded ? null : TextOverflow.ellipsis,
                        style: bodyStyle,
                      ),
                      if (overflows)
                        GestureDetector(
                          onTap: () => setState(() => _expanded = !_expanded),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              _expanded ? 'less' : 'more',
                              style: bodyStyle?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _Tag(label: post.categoryLabel),
                if (post.severity != null)
                  _Tag(label: 'Severity: ${post.severity!.label}'),
                if (post.possibleInvasive)
                  const _Tag(
                    label: 'Possible invasive species',
                    icon: Icons.warning_amber_rounded,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.location_on_outlined, color: mutedColor, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    post.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: detailStyle,
                  ),
                ),
              ],
            ),
            if (post.hasAiContent) ...[
              const SizedBox(height: 4),
              Text(FeedPost.aiNote, style: detailStyle),
            ],
          ],
        ),
      ),
    );
  }

  bool _overflows(
    String text,
    TextStyle? style,
    double width,
    TextDirection direction,
    TextScaler scaler,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: _collapsedLines,
      textDirection: direction,
      textScaler: scaler,
    )..layout(maxWidth: width);
    final exceeded = painter.didExceedMaxLines;
    painter.dispose();
    return exceeded;
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.icon});
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurface;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
