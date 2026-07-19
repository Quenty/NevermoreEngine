export namespace PlayerSettingsUtils {
  function create(): Folder;
  function getAttributeName(settingName: string): string;
  function getSettingName(attributeName: string): string;
  function isSettingAttribute(attributeName: string): boolean;
  function encodeForNetwork(settingValue: unknown): string;
  function decodeForNetwork(settingValue: string): unknown;
  function encodeForAttribute(settingValue: unknown): unknown;
  function decodeForAttribute(settingValue: unknown): unknown;
}
