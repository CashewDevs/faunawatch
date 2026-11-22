import 'package:flutter/material.dart';
import 'package:faunawatch/core/theme/tag_colors.dart';
import 'package:faunawatch/features/fauna_lens/views/widgets/severity_tone.dart';
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
  static const _collapsedLines = 3;

  /// How far an expanded caption must be pulled past its end before the
  /// swipe moves the feed instead.
  static const _handOffDistance = 24.0;

  bool _expanded = false;
  double _overscroll = 0;
  bool _handedOff = false;

  @override
  void didUpdateWidget(covariant PostCaption oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) _expanded = false;
  }

  /// An expanded caption scrolls on its own. Once it is at its end, keeps
  /// the swipe going to the next (or previous) post, as long as the post is
  /// in a paged feed.
  bool _onScroll(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      _overscroll = 0;
      _handedOff = false;
      return false;
    }
    if (notification is! OverscrollNotification ||
        !_expanded ||
        _handedOff ||
        notification.dragDetails == null) {
      return false;
    }
    _overscroll += notification.overscroll;
    if (_overscroll.abs() < _handOffDistance) return false;
    final feed = Scrollable.maybeOf(context, axis: Axis.vertical)?.position;
    if (feed == null || feed is! PageMetrics) return false;
    _handedOff = true;
    final target = (feed.pixels + _overscroll.sign * feed.viewportDimension)
        .clamp(feed.minScrollExtent, feed.maxScrollExtent);
    feed.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final textColor = theme.colorScheme.onSurface;
    // Readable on both themes: stronger than onSurfaceVariant.
    final detailColor = textColor.withValues(alpha: 0.78);
    final bodyStyle = textTheme.bodyLarge?.copyWith(
      fontSize: 15,
      height: 1.4,
      color: textColor,
    );
    final detailStyle = textTheme.bodyMedium?.copyWith(
      fontSize: 13.5,
      color: detailColor,
    );
    final when = formatPostWhen(post.feedAt, widget.now ?? DateTime.now());
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.45,
      ),
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
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
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                    children: [TextSpan(text: ' · $when', style: detailStyle)],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                post.title,
                style: textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              if (post.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final overflows = _overflows(
                      post.description,
                      bodyStyle,
                      constraints.maxWidth,
                      Directionality.of(context),
                      MediaQuery.textScalerOf(context),
                    );
                    final text = Text(
                      post.description,
                      maxLines: _expanded ? null : _collapsedLines,
                      overflow: _expanded ? null : TextOverflow.ellipsis,
                      style: bodyStyle,
                    );
                    if (!overflows) return text;
                    // The whole description toggles, so the target is large.
                    return Semantics(
                      button: true,
                      expanded: _expanded,
                      hint: _expanded ? 'Show less' : 'Show more',
                      child: GestureDetector(
                        onTap: () => setState(() => _expanded = !_expanded),
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            text,
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: ExcludeSemantics(
                                child: Text(
                                  _expanded ? 'less' : 'more',
                                  style: bodyStyle?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _Tag(label: post.categoryLabel),
                  if (post.severity != null)
                    _Tag(
                      label: 'Severity: ${post.severity!.label}',
                      tone: post.severity!.tagTone,
                    ),
                  if (post.possibleInvasive)
                    const _Tag(
                      label: 'Possible invasive species',
                      icon: Icons.warning_amber_rounded,
                      tone: TagTone.invasive,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              _LocationRow(
                location: post.location,
                style: detailStyle,
                color: detailColor,
                onTap: widget.onLocationTap,
              ),
              if (post.aiAnalysis != null)
                _AiAnalysisButton(
                  onTap: () =>
                      PostAiAnalysisSheet.show(context, post.aiAnalysis!),
                ),
              if (post.hasAiContent) ...[
                const SizedBox(height: 2),
                Text(
                  FeedPost.aiNote,
                  style: detailStyle?.copyWith(fontSize: 12.5),
                ),
              ],
            ],
          ),
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

/// The smallest touch height Android and iOS recommend.
const _minTouchHeight = 48.0;

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
        Icon(Icons.location_on_outlined, color: color, size: 18),
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
          const SizedBox(width: 4),
          Icon(Icons.map_outlined, color: color, size: 16),
        ],
      ],
    );
    if (onTap == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: row,
      );
    }
    return Semantics(
      button: true,
      hint: 'Show on the map',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _minTouchHeight),
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
    final radius = BorderRadius.circular(18);
    // The outlined pill is 36 dp tall; the touch area around it is 48 dp.
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _minTouchHeight),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 1,
            child: Container(
              constraints: const BoxConstraints(minHeight: 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: color.withValues(alpha: 0.5)),
                borderRadius: radius,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 16, color: color),
                  const SizedBox(width: 6),
                  Text(
                    'AI analysis',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontSize: 13.5,
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: color),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small label under the caption. Without a [tone] it stays a plain grey
/// tag (the category); with one it is filled with that tone's colours.
class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.icon, this.tone});
  final String label;
  final IconData? icon;
  final TagTone? tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tagColors = tone == null ? null : TagColors.of(context, tone!);
    final color = tagColors?.foreground ?? theme.colorScheme.onSurface;
    return DecoratedBox(
      key: tone == null ? null : ValueKey('post_tag_${tone!.name}'),
      decoration: BoxDecoration(
        color: tagColors?.background ?? color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                style: theme.textTheme.labelMedium?.copyWith(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
