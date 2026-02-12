import { ServiceBag } from '@quenty/servicebag';
import { Binder } from '@quenty/binder';
import { HasChatTagsBase } from '../../Shared/Binders/HasChatTagsBase';
import { ChatTagClient } from './ChatTagClient';

interface HasChatTagsClient extends HasChatTagsBase {
  GetChatTagBinder(): Binder<ChatTagClient>;
  GetAsRichText(): string | undefined;
}

interface HasChatTagsClientConstructor {
  readonly ClassName: 'HasChatTagsClient';
  new (player: Player, serviceBag: ServiceBag): HasChatTagsClient;
}

export const HasChatTagsClient: Binder<HasChatTagsClient>;
