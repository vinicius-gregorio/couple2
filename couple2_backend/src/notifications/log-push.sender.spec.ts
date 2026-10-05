import * as admin from 'firebase-admin';
import { LogPushSender } from './log-push.sender';

describe('LogPushSender', () => {
  it('records the push in the log and does not initialize Firebase', async () => {
    const sender = new LogPushSender();
    const results = await sender.send({
      tokens: ['device-token-aaaa'],
      notification: { title: 'Nova lista', body: 'Bia criou "Compras"' },
      data: { type: 'LIST_CREATED', route: '/lists/list-1' },
      collapseKey: 'PartnerList:list-1',
    });

    expect(results).toEqual([{ token: 'device-token-aaaa', success: true }]);
    expect(admin.apps.length).toBe(0);
  });
});
