import { listEmitsActivity } from './list-activity';

describe('list activity privacy', () => {
  it('emits for shared lists and never for a private gift list', () => {
    expect(listEmitsActivity({ visibility: 'SHARED' })).toBe(true);
    expect(listEmitsActivity({ visibility: 'PRIVATE_FROM_PARTNER' })).toBe(
      false,
    );
    expect(listEmitsActivity({})).toBe(true);
  });
});
