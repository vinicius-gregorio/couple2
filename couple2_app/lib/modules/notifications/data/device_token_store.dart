/// SharedPreferences key for the FCM token registered with `POST /devices`.
/// Logout reads it and calls `DELETE /devices/:token` before `prefs.clear()`.
const devicePushTokenKey = 'device_push_token';
