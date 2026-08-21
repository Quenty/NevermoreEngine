export namespace TextChannelUtils {
  function getDefaultTextChannel(): TextChannel | undefined;
  function getTextChannel(channelName: string): TextChannel | undefined;
  function getTextChannels(): Instance | undefined;
}
