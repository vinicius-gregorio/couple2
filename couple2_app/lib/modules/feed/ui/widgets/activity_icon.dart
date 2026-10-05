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
    default:
      return Icons.notifications_none;
  }
}
