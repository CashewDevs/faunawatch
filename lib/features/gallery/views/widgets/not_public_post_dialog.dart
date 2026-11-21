import 'package:flutter/material.dart';
import 'package:faunawatch/features/report_detail/models/own_report.dart';

/// Explains why a post that is not public (pending or declined) cannot be
/// liked or commented on.
Future<void> showNotPublicPostDialog(
  BuildContext context,
  ReportStatus status,
) {
  final declined = status == ReportStatus.declined;
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(declined ? Icons.block_rounded : Icons.schedule_rounded),
      title: Text(
        declined ? 'This post was declined' : 'This post is still pending',
      ),
      content: Text(
        declined
            ? "An admin didn't approve it, so only you can see it. Likes and "
                  'comments are closed.'
            : "It's waiting for an admin's approval. Likes and comments open "
                  "once it's approved.",
        textAlign: TextAlign.center,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
