import { ServiceBag } from '@quenty/servicebag';
import { HasChatTagsBase } from '../../Shared/Binders/HasChatTagsBase';
import { Binder } from '@quenty/binder';
import { ChatTag } from './ChatTag';
import { ChatTagData } from '../../Shared/Data/ChatTagDataUtils';
import { PlayerBinder } from '@quenty/playerbinder';

interface HasChatTags extends HasChatTagsBase {
  GetChatTagBinder(): Binder<ChatTag>;
  AddChatTag(chatTagData: ChatTagData): Folder;
  GetChatTagByKey(chatTagKey: string): ChatTagData | undefined;
  ClearTags(): void;
}

interface HasChatTagsConstructor {
  readonly ClassName: 'HasChatTags';
  new (player: Player, serviceBag: ServiceBag): HasChatTags;
}

export const HasChatTags: PlayerBinder<HasChatTags>;
