import { Promise } from '@quenty/promise';

export namespace VoiceChatUtils {
  function promiseIsVoiceEnabledForPlayer(player: Player): Promise<boolean>;
  function promiseIsVoiceEnabledForUserId(userId: number): Promise<boolean>;
}
