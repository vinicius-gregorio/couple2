import { listEmitsActivity } from './list-activity';

describe('list activity privacy', () => {
  it('emits for the shared list types and never for gift or private lists', () => {
    expect(listEmitsActivity('SHOPPING_CART')).toBe(true);
    expect(listEmitsActivity('MOVIES')).toBe(true);
    expect(listEmitsActivity('GIFT_IDEAS')).toBe(false);
    expect(listEmitsActivity('GIFTS')).toBe(false);
    expect(listEmitsActivity('GIFT')).toBe(false);
    expect(listEmitsActivity('PRIVATE')).toBe(false);
  });
});
