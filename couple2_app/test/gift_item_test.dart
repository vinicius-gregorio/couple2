import 'package:couple2_app/modules/lists/domain/gift_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats BRL and builds optional gift metadata', () {
    final price = formatGiftPrice(12.5);
    expect(price.contains('12,50'), isTrue);
    expect(price.contains(r'R$'), isTrue);

    final draft = buildGiftItemMetadata(
      priceText: '10,5',
      urlText: 'https://example.com/item',
      occasion: 'BIRTHDAY',
      bought: true,
    );
    expect(draft.isValid, isTrue);
    expect(draft.metadata, {
      'price': 10.5,
      'currency': 'BRL',
      'url': 'https://example.com/item',
      'occasion': 'BIRTHDAY',
      'status': 'BOUGHT',
    });
  });

  test('rejects a negative price and a non-http link', () {
    expect(
      buildGiftItemMetadata(
        priceText: '-1',
        urlText: '',
        occasion: null,
        bought: false,
      ).isValid,
      isFalse,
    );
    expect(
      buildGiftItemMetadata(
        priceText: '',
        urlText: 'javascript:alert(1)',
        occasion: null,
        bought: false,
      ).isValid,
      isFalse,
    );
    expect(isHttpGiftUrl('javascript:alert(1)'), isFalse);
    expect(giftOccasionLabel('CHRISTMAS'), 'Natal');
  });
}
