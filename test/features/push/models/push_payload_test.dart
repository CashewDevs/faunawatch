import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/notifications/models/notification_item.dart';
import 'package:faunawatch/features/push/models/push_payload.dart';

void main() {
  group('PushPayload', () {
    test('ignores messages without a notification id', () {
      expect(PushPayload.fromData({'type': 'chat_message'}), isNull);
      expect(PushPayload.fromData({'notification_id': ''}), isNull);
    });

    test('treats empty strings as missing', () {
      final payload = PushPayload.fromData({
        'notification_id': 'n1',
        'type': 'chat_message',
        'report_id': '',
        'thread_id': 't1',
      })!;
      expect(payload.reportId, isNull);
      expect(payload.threadId, 't1');
    });

    test('uses the in-app mapping for targets', () {
      PushPayload p(String type, {String report = 'r1'}) =>
          PushPayload.fromData({
            'notification_id': 'n1',
            'type': type,
            'report_id': report,
          })!;
      expect(p('report_status').target, const ReportTarget('r1'));
      expect(p('report_like').target, const ReportTarget('r1'));
      expect(
        p('report_comment').target,
        const ReportTarget('r1', showComments: true),
      );
      expect(p('chat_message', report: '').target, const MessagesTarget());
      expect(p('nearby_alert').target, isNull);
      expect(p('some_future_type').target, isNull);
      expect(p('report_status', report: '').target, isNull);
    });
  });
}
