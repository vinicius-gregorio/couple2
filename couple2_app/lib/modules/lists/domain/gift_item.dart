import 'package:intl/intl.dart';

const giftOccasions = <String, String>{
  'BIRTHDAY': 'Aniversário',
  'ANNIVERSARY': 'Namoro',
  'CHRISTMAS': 'Natal',
  'VALENTINES': 'Dia dos namorados',
  'OTHER': 'Outra',
};

class GiftDraft {
  const GiftDraft({this.metadata, this.error});

  final Map<String, dynamic>? metadata;
  final String? error;

  bool get isValid => error == null;
}

String formatGiftPrice(num price) {
  return NumberFormat.simpleCurrency(
    locale: 'pt_BR',
    name: 'BRL',
  ).format(price);
}

String? giftOccasionLabel(Object? value) {
  if (value is! String) return null;
  return giftOccasions[value];
}

/// Builds optional GIFT_IDEAS metadata. An empty draft is valid and has no map.
GiftDraft buildGiftItemMetadata({
  required String priceText,
  required String urlText,
  required String? occasion,
  required bool bought,
}) {
  final metadata = <String, dynamic>{};

  final priceRaw = priceText.trim();
  if (priceRaw.isNotEmpty) {
    final price = double.tryParse(priceRaw.replaceAll(',', '.'));
    if (price == null || price < 0) {
      return const GiftDraft(
        error: 'Preço precisa ser um número maior ou igual a zero',
      );
    }
    metadata['price'] = price;
    metadata['currency'] = 'BRL';
  }

  final url = urlText.trim();
  if (url.isNotEmpty) {
    final parsed = Uri.tryParse(url);
    if (parsed == null ||
        (parsed.scheme != 'http' && parsed.scheme != 'https')) {
      return const GiftDraft(
        error: 'O link precisa começar com http:// ou https://',
      );
    }
    metadata['url'] = url;
  }

  if (occasion != null && occasion.isNotEmpty) {
    metadata['occasion'] = occasion;
  }
  if (bought) {
    metadata['status'] = 'BOUGHT';
  }

  if (metadata.isEmpty) return const GiftDraft();
  return GiftDraft(metadata: metadata);
}

bool isHttpGiftUrl(Object? value) {
  if (value is! String) return false;
  final parsed = Uri.tryParse(value);
  return parsed != null &&
      (parsed.scheme == 'http' || parsed.scheme == 'https');
}
