import { AttributeValue } from '@quenty/attributeutils';
import { BaseObject } from '@quenty/baseobject';
import { Observable } from '@quenty/rx';
import { ChatTagData } from '../Data/ChatTagDataUtils';

interface ChatTagBase extends BaseObject {
  UserDisabled: AttributeValue<boolean>;
  ChatTagKey: AttributeValue<string>;
  ObserveChatTagData(): Observable<ChatTagData>;
}

interface ChatTagBaseConstructor {
  readonly ClassName: 'ChatTagBase';
  new (obj: Folder): ChatTagBase;
}

export const ChatTagBase: ChatTagBaseConstructor;
