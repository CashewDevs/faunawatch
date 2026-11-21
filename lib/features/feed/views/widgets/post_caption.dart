import 'package:flutter/material.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/public_profile/views/widgets/profile_link.dart';
import 'package:faunawatch/features/feed/views/widgets/post_ai_analysis_sheet.dart';

/// Author, title, and description of a post. The full description stays hidden
/// until expanded so the caption does not cover the photos. The location opens
/// the map when [onLocationTap] is given, and "AI analysis" opens everything
/// the AI suggested.
class PostCaption extends StatefulWidget {
  const PostCaption({
    super.key,
    required this.post,
    this.now,
    this.onAuthorTap,
    this.onLocationTap,
  });
  final FeedPost post;
  final VoidCallback? onAuthorTap;

  /// Shows the post on the map; null leaves the location as plain text.
  final VoidCallback? onLocationTap;

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
            ProfileLink(
              name: post.authorName,
              onTap: widget.onAuthorTap,
              child: Text.rich(
                TextSpan(
                  text: post.authorName,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  children: [TextSpan(text: ' · $age', style: detailStyle)],
                ),
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
            _LocationRow(
              location: post.location,
              style: detailStyle,
              color: mutedColor,
              onTap: widget.onLocationTap,
            ),
            if (post.aiAnalysis != null) ...[
              const SizedBox(height: 4),
              _AiAnalysisButton(
                onTap: () =>
                    PostAiAnalysisSheet.show(context, post.aiAnalysis!),
              ),
            ],
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

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.location,
    required this.style,
    required this.color,
    this.onTap,
  });
  final String location;
  final TextStyle? style;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        Icon(Icons.location_on_outlined, color: color, size: 16),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            location,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: onTap == null
                ? style
                : style?.copyWith(
                    decoration: TextDecoration.underline,
                    decorationColor: color,
                  ),
          ),
        ),
        if (onTap != null) ...[
          const SizedBox(width: 2),
          Icon(Icons.map_outlined, color: color, size: 14),
        ],
      ],
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      hint: 'Show on the map',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: row,
        ),
      ),
    );
  }
}

class _AiAnalysisButton extends StatelessWidget {
  const _AiAnalysisButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurface;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                'AI analysis',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: color),
            ],
          ),
        ),
      ),
    );
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
