import { Promise } from '@quenty/promise';
import { Observable } from '@quenty/rx';

export interface TextFilterServiceClient {
  PromiseNonChatStringForUser(
    text: string,
    fromUserId: number
  ): Promise<string>;
  PromiseNonChatStringForBroadcast(
    text: string,
    fromUserId: number
  ): Promise<string>;
  PromisePreviewNonChatStringForBroadcast(text: string): Promise<string>;
  ObservePreviewNonChatStringForBroadcast(text: string): Observable<string>;
}
