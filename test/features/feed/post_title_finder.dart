import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Finds a post caption's title. The title shares one line of rich text with
/// the category and severity tags (so they can follow its last word), which
/// means `find.text` cannot match the title on its own.
Finder findPostTitle(String title) => find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      widget.textSpan is TextSpan &&
      (widget.textSpan! as TextSpan).text == title,
  description: 'post title "$title"',
);
