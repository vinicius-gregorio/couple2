import 'package:flutter/material.dart';

IconData activityIcon(String type) {
  switch (type) {
    case 'LIST_CREATED':
      return Icons.playlist_add;
    case 'LIST_ITEM_ADDED':
      return Icons.add_task;
    case 'LIST_ITEM_COMPLETED':
      return Icons.check_circle_outline;
    case 'COUPLE_DATE_UPCOMING':
      return Icons.cake_outlined;
    case 'COUPLE_UPDATED':
      return Icons.favorite_outline;
    case 'QUESTION_ANSWERED':
      return Icons.question_answer_outlined;
    case 'QUESTION_UNLOCKED':
      return Icons.lock_open;
    case 'MOOD_SHARED':
      return Icons.sentiment_satisfied_alt_outlined;
    case 'NUDGE_SENT':
      return Icons.favorite_border;
    default:
      return Icons.notifications_none;
  }
}
