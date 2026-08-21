import { BaseObject } from '@quenty/baseobject';
import { Promise } from '@quenty/promise';
import { Observable } from '@quenty/rx';

interface UserInfoAggregator extends BaseObject {
  PromiseUserInfo(userId: number): Promise<UserInfo>;
  PromiseDisplayName(userId: number): Promise<string>;
  PromiseUsername(userId: number): Promise<string>;
  PromiseHasVerifiedBadge(userId: number): Promise<boolean>;
  ObserveUserInfo(userId: number): Observable<UserInfo>;
  ObserveDisplayName(userId: number): Observable<string>;
  ObserveUsername(userId: number): Observable<string>;
  ObserveHasVerifiedBadge(userId: number): Observable<boolean>;
}

interface UserInfoAggregatorConstructor {
  readonly ClassName: 'UserInfoAggregator';
  new (): UserInfoAggregator;
}

export const UserInfoAggregator: UserInfoAggregatorConstructor;
