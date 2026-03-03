export { VersionChecker } from './version-checker.js';

export {
  getRobloxCookieAsync,
  createPlaceInUniverseAsync,
  tryRenamePlaceAsync,
} from './auth/roblox-auth/index.js';
export type { RenamePlaceResult } from './auth/roblox-auth/index.js';
export { COOKIE_NAME, parseStudioCookieValue } from './auth/roblox-auth/cookie-parser.js';
