import 'package:flutter/material.dart';

/// Explains why a pending post cannot be liked or commented on yet.
Future<void> showPendingPostDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.schedule_rounded),
      title: const Text('This post is still pending'),
      content: const Text(
        "It's waiting for an admin's approval. Likes and comments open once "
        "it's approved.",
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
