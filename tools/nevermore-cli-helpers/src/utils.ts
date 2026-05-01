export { VersionChecker } from './version-checker.js';

export {
  getRobloxCookieAsync,
  createPlaceInUniverseAsync,
  tryRenamePlaceAsync,
  validateCookieAsync,
} from './auth/cookie/index.js';
export type {
  RenamePlaceResult,
  CookieValidationResult,
} from './auth/cookie/index.js';
export {
  COOKIE_NAME,
  parseStudioCookieValue,
} from './auth/cookie/cookie-parser.js';

export {
  getApiKeyAsync,
  loadStoredApiKeyAsync,
  saveApiKeyAsync,
  clearApiKeyAsync,
  validateApiKeyAsync,
  printApiKeySetupHelp,
} from './auth/open-cloud/credential-store.js';
export type { CredentialArgs } from './auth/open-cloud/credential-store.js';
