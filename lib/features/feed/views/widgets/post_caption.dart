import 'package:flutter/material.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';

/// Author, title, and description of a post. The full body stays hidden until
/// expanded so the caption does not cover the photos.
class PostCaption extends StatefulWidget {
  const PostCaption({super.key, required this.post});
  final FeedPost post;

  @override
  State<PostCaption> createState() => _PostCaptionState();
}

class _PostCaptionState extends State<PostCaption> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final mutedColor = theme.colorScheme.onSurfaceVariant;
    final bodyStyle = textTheme.bodyMedium;
    final detailStyle = textTheme.bodySmall?.copyWith(color: mutedColor);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.4,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  post.author,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const _SampleBadge(),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              post.title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              post.summary,
              maxLines: _expanded ? null : 2,
              overflow: _expanded ? null : TextOverflow.ellipsis,
              style: bodyStyle,
            ),
            if (_expanded) ...[
              const SizedBox(height: 8),
              Text(post.body, style: bodyStyle),
            ],
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  _expanded ? 'less' : 'more',
                  style: bodyStyle?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 4),
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
            const SizedBox(height: 4),
            Text('Demo only - Not a real wildlife report', style: detailStyle),
          ],
        ),
      ),
    );
  }
}

class _SampleBadge extends StatelessWidget {
  const _SampleBadge();

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
            Icon(Icons.science_outlined, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              'Sample post',
              style: theme.textTheme.labelSmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
