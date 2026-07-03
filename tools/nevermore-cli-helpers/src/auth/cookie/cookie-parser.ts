export const COOKIE_NAME = '.ROBLOSECURITY';

/**
 * Parse a Studio cookie value that may be in COOK::<cookie> format.
 * Matches Mantle's parse_roblox_studio_cookie.
 */
export function parseStudioCookieValue(value: string): string | undefined {
  for (const item of value.split(',')) {
    const parts = item.split('::');
    if (parts.length === 2 && parts[0] === 'COOK') {
      const cookie = parts[1];
      if (cookie.startsWith('<') && cookie.endsWith('>')) {
        return cookie.slice(1, -1);
      }
    }
  }
  return undefined;
}
