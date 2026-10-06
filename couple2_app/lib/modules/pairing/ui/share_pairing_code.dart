import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/domain.dart';

enum PairingShareResult { opened, copied }

Future<PairingShareResult> sharePairingCode(String code) async {
  final text = pairingShareText(code);
  final uri = Uri.https('wa.me', '/', {'text': text});
  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened) return PairingShareResult.opened;
  } catch (_) {
    // Fall through to the clipboard. Web and desktop can block the share tab.
  }
  await Clipboard.setData(ClipboardData(text: text));
  return PairingShareResult.copied;
}
