import { Logger } from '@nestjs/common';
import { PushMessage, PushSender, PushSendResult } from './push-sender';

/**
 * Dev default. Does not touch Firebase. List routes keep working with no
 * service account; the push is only a log line.
 */
export class LogPushSender implements PushSender {
  private readonly logger = new Logger(LogPushSender.name);

  send(message: PushMessage): Promise<PushSendResult[]> {
    const suffixes = message.tokens.map((token) => token.slice(-6));
    this.logger.log(
      `PUSH_DRIVER=log type=${message.data.type} route=${message.data.route} collapseKey=${message.collapseKey} tokens=${message.tokens.length} tokenSuffixes=${suffixes.join(',')} title=${JSON.stringify(message.notification.title)} body=${JSON.stringify(message.notification.body)}`,
    );
    return Promise.resolve(
      message.tokens.map((token) => ({ token, success: true })),
    );
  }
}
