import { ServiceBag } from '@quenty/servicebag';
import { ChatTagBase } from '../../Shared/Binders/ChatTagBase';
import { Binder } from '@quenty/binder';

interface ChatTagClient extends ChatTagBase {}

interface ChatTagClientConstructor {
  readonly ClassName: 'ChatTagClient';
  new (folder: Folder, serviceBag: ServiceBag): ChatTagClient;
}

export const ChatTagClient: Binder<ChatTagClient>;
