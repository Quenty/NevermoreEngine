import { Promise } from '@quenty/promise';
import { Observable } from '@quenty/rx';
import { ServiceBag } from '@quenty/servicebag';

export interface UserInfoService {
  Init(serviceBag: ServiceBag): void;
  PromiseUserInfo(userId: number): Promise<UserInfo>;
  ObserveUserInfo(userId: number): Observable<UserInfo>;
  PromiseDisplayName(userId: number): Promise<string>;
  PromiseUsername(userId: number): Promise<string>;
  ObserveDisplayName(userId: number): Observable<UserInfo>;
  Destroy(): void;
}
