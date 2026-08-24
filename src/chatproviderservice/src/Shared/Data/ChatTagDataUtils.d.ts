import { LocalizedTextData } from '@quenty/localizedtextutils';

export interface ChatTagData {
  TagText: string;
  TagPriority: number;
  UserDisabled?: boolean;
  TagLocalizedText?: LocalizedTextData;
  TagColor: Color3;
}

export namespace ChatTagDataUtils {
  function createChatTagData(data: ChatTagData): ChatTagData;
  function isChatTagDataList(value: unknown): value is ChatTagData[];
  function isChatTagData(value: unknown): value is ChatTagData;
}
