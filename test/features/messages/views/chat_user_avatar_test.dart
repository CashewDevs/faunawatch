import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/features/messages/models/chat_user.dart';
import 'package:faunawatch/features/messages/views/widgets/chat_user_avatar.dart';

void main() {
  Future<void> showAvatar(WidgetTester tester, ChatUser user) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ChatUserAvatar(user: user)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('displays a preset avatar cropped to a circle', (tester) async {
    await showAvatar(
      tester,
      const ChatUser(id: 'b', name: 'Bob', avatarAsset: AppAssets.avatarBunny),
    );
    final photo = tester.widget<Image>(find.byType(Image));
    expect((photo.image as AssetImage).assetName, AppAssets.avatarBunny);
    expect(photo.fit, BoxFit.cover);
    expect(find.byType(ClipOval), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsNothing);
  });
  testWidgets('uses a person icon when no avatar is set', (tester) async {
    await showAvatar(tester, const ChatUser(id: 'b', name: 'Bob'));
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
  });
  testWidgets('falls back to the person icon when an uploaded avatar fails', (
    tester,
  ) async {
    await showAvatar(
      tester,
      const ChatUser(
        id: 'b',
        name: 'Bob',
        avatarUrl: 'https://chat-tests.invalid/avatar',
      ),
    );
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
