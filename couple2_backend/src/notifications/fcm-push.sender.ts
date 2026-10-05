import { Logger } from '@nestjs/common';
import * as admin from 'firebase-admin';
import { ensureFirebase } from '../firebase/firebase-admin';
import { PushMessage, PushSender, PushSendResult } from './push-sender';

const MULTICAST_LIMIT = 500;

export class FcmPushSender implements PushSender {
  private readonly logger = new Logger(FcmPushSender.name);

  constructor(
    private readonly sendMulticast: (
      message: admin.messaging.MulticastMessage,
    ) => Promise<admin.messaging.BatchResponse> = (message) => {
      ensureFirebase();
      return admin.messaging().sendEachForMulticast(message);
    },
  ) {}

  async send(message: PushMessage): Promise<PushSendResult[]> {
    const results: PushSendResult[] = [];
    for (
      let offset = 0;
      offset < message.tokens.length;
      offset += MULTICAST_LIMIT
    ) {
      const tokens = message.tokens.slice(offset, offset + MULTICAST_LIMIT);
      const response = await this.sendMulticast({
        tokens,
        notification: {
          title: message.notification.title,
          body: message.notification.body,
        },
        data: {
          type: message.data.type,
          route: message.data.route,
        },
        android: {
          priority: 'high',
          collapseKey: message.collapseKey,
          notification: {
            tag: message.collapseKey,
            channelId: 'couple_activity',
          },
        },
        apns: {
          headers: {
            'apns-collapse-id': message.collapseKey,
            'apns-priority': '10',
          },
          payload: {
            aps: {
              threadId: message.collapseKey,
              sound: 'default',
            },
          },
        },
      });

      response.responses.forEach((item, index) => {
        const token = tokens[index];
        if (!item.success) {
          this.logger.warn(
            `FCM rejected token …${token.slice(-6)} code=${item.error?.code ?? 'unknown'}`,
          );
        }
        results.push({
          token,
          success: item.success,
          errorCode: item.error?.code,
        });
      });
    }
    return results;
  }
}
