import 'package:faunawatch/core/widgets/local_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loads the path the way the current platform supports', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LocalImage(
          'photo.jpg',
          width: 40,
          semanticLabel: 'Photo',
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, kIsWeb ? isA<NetworkImage>() : isA<FileImage>());
    expect(image.width, 40);
    expect(image.semanticLabel, 'Photo');
    expect(tester.takeException(), isNull);
  });
}
