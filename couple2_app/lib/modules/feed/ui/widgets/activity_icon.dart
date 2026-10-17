import 'package:flutter/material.dart';

const _activityIcons = <String, IconData>{
  'LIST_CREATED': Icons.playlist_add,
  'LIST_ITEM_ADDED': Icons.add_task,
  'LIST_ITEM_COMPLETED': Icons.check_circle_outline,
  'COUPLE_DATE_UPCOMING': Icons.cake_outlined,
  'COUPLE_UPDATED': Icons.favorite_outline,
  'QUESTION_ANSWERED': Icons.question_answer_outlined,
  'QUESTION_UNLOCKED': Icons.lock_open,
  'MOOD_SHARED': Icons.sentiment_satisfied_alt_outlined,
  'NUDGE_SENT': Icons.favorite_border,
  'DATE_PLAN_PROPOSED': Icons.event_outlined,
  'DATE_PLAN_COUNTERED': Icons.event_outlined,
  'DATE_PLAN_ACCEPTED': Icons.event_available_outlined,
  'DATE_PLAN_DONE': Icons.event_available_outlined,
  'DATE_PLAN_DECLINED': Icons.event_busy_outlined,
  'DATE_PLAN_CANCELLED': Icons.event_busy_outlined,
};

IconData activityIcon(String type) {
  return _activityIcons[type] ?? Icons.notifications_none;
}
