export namespace String {
  function trim(str: string, pattern?: string): string;
  function toCamelCase(str: string): string;
  function uppercaseFirstLetter(str: string): string;
  function toLowerCamelCase(str: string): string;
  function toPrivateCase(str: string): string;
  function trimFront(str: string, pattern?: string): string;
  function checkNumOfCharacterInString(str: string, char: string): number;
  function isEmptyOrWhitespaceOrNil(str: string | undefined): str is string;
  function isWhitespace(str: string): boolean;
  function elipseLimit(str: string, characterLimit: number): string;
  function removePrefix(str: string, prefix: string): string;
  function removePostFix(str: string, postfix: string): string;
  function endsWith(str: string, postfix: string): boolean;
  function startsWith(str: string, prefix: string): boolean;
  function addCommas(number: string | number, seperator: string): string;
}
