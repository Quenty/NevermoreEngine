export { VersionChecker } from './version-checker.js';

export {
  getRobloxCookieAsync,
  createPlaceInUniverseAsync,
  tryRenamePlaceAsync,
  validateCookieAsync,
} from './auth/roblox-auth/index.js';
export type { RenamePlaceResult, CookieValidationResult } from './auth/roblox-auth/index.js';
export { COOKIE_NAME, parseStudioCookieValue } from './auth/roblox-auth/cookie-parser.js';

export {
  getApiKeyAsync,
  loadStoredApiKeyAsync,
  saveApiKeyAsync,
  clearApiKeyAsync,
  validateApiKeyAsync,
  printApiKeySetupHelp,
} from './auth/credential-store.js';
export type { CredentialArgs } from './auth/credential-store.js';
