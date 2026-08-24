import { Promise } from '@quenty/promise';

export namespace TextFilterUtils {
  function promiseNonChatStringForBroadcast(
    text: string,
    fromUserId: number,
    textFilterContent: Enum.TextFilterContext
  ): Promise<string>;
  function promiseLegacyChatFilter(
    playerFrom: Player,
    text: string
  ): Promise<string>;
  function promiseNonChatStringForUserAsync(
    text: string,
    fromUserId: number,
    toUserId: number,
    textFilterContext: Enum.TextFilterContext
  ): Promise<string>;
  function getNonChatStringForBroadcastAsync(
    text: string,
    fromUserId: number,
    textFilterContent: Enum.TextFilterContext
  ): LuaTuple<[result: string, err?: string]>;
  function getNonChatStringForUserAsync(
    text: string,
    fromUserId: number,
    toUserId: number,
    textFilterContext: Enum.TextFilterContext
  ): LuaTuple<[result: string, err?: string]>;
  function hasNonFilteredText(text: string): boolean;
  function getProportionFiltered(text: string): number;
  function countFilteredCharacters(
    text: string
  ): LuaTuple<[filtered: number, unfiltered: number, whitespace: number]>;
  function addBackInNewLinesAndWhitespace(
    text: string,
    filteredText: string
  ): string;
}
