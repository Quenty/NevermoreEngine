import { BaseObject } from '@quenty/baseobject';
import { ChatTagData } from '../Data/ChatTagDataUtils';
import { Observable } from '@quenty/rx';

interface HasChatTagsBase extends BaseObject {
  GetLastChatTags(): ChatTagData[] | undefined;
  ObserveLastChatTags(): Observable<ChatTagData[] | undefined>;
}

interface HasChatTagsBaseConstructor {
  readonly ClassName: 'HasChatTagsBase';
  new (player: Player): HasChatTagsBase;
}

export const HasChatTagsBase: HasChatTagsBaseConstructor;
