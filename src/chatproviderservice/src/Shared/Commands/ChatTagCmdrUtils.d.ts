import { Cmdr, CmdrClient } from '@quenty/cmdrservice';
import { ChatProviderService } from '../../Server/ChatProviderService';
import { ChatProviderServiceClient } from '../../Client/ChatProviderServiceClient';

export namespace ChatTagCmdrUtils {
  function registerChatTagKeys(
    cmdr: Cmdr | CmdrClient,
    chatProviderService: ChatProviderService | ChatProviderServiceClient
  ): void;
}
