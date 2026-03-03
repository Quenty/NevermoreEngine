/**
 * Path resolution and configuration constants for running Roblox Studio
 * under Wine on Linux.
 */

import * as path from 'path';
import * as os from 'os';

export interface LinuxStudioConfig {
  /** Root directory of the Studio installation */
  studioDir: string;
  /** Wine prefix (usually ~/.wine) */
  winePrefix: string;
  /** X11 display number (e.g. ":99") */
  display: string;
  /** Path to the RobloxStudioBeta.exe within studioDir */
  studioExe: string;
  /** Path to ClientSettings/ClientAppSettings.json */
  clientSettingsPath: string;
  /** Path to the shaders directory */
  shadersDir: string;
  /** Path to the Plugins folder */
  pluginsDir: string;
  /** Path to write-cred.exe (compiled credential writer) */
  writeCredExe: string;
}

/**
 * Resolve all Linux/Wine paths from environment variables and defaults.
 */
export function resolveLinuxConfig(): LinuxStudioConfig {
  const studioDir =
    process.env.STUDIO_DIR ||
    path.join(os.homedir(), 'roblox-studio');

  const winePrefix =
    process.env.WINEPREFIX ||
    path.join(os.homedir(), '.wine');

  const display = process.env.DISPLAY || ':99';

  return {
    studioDir,
    winePrefix,
    display,
    studioExe: path.join(studioDir, 'RobloxStudioBeta.exe'),
    clientSettingsPath: path.join(
      studioDir,
      'ClientSettings',
      'ClientAppSettings.json'
    ),
    shadersDir: path.join(studioDir, 'shaders'),
    pluginsDir: path.join(studioDir, 'Plugins'),
    writeCredExe: path.join(studioDir, 'write-cred.exe'),
  };
}

/** CDN base URL for Roblox Studio downloads */
export const ROBLOX_CDN_BASE = 'https://setup.rbxcdn.com';

/** Roblox API base for user info */
export const ROBLOX_USERS_API = 'https://users.roblox.com';

/**
 * Package-to-directory mapping extracted from the Studio installer's
 * .rdata section. Each key is a zip filename; value is the subdirectory
 * within studioDir to extract into.
 */
export const STUDIO_PACKAGES: Record<string, string> = {
  'ApplicationConfig.zip': 'ApplicationConfig/',
  'redist.zip': '',
  'RobloxStudio.zip': '',
  'Libraries.zip': '',
  'content-avatar.zip': 'content/avatar/',
  'content-configs.zip': 'content/configs/',
  'content-fonts.zip': 'content/fonts/',
  'content-sky.zip': 'content/sky/',
  'content-sounds.zip': 'content/sounds/',
  'content-textures2.zip': 'content/textures/',
  'content-studio_svg_textures.zip': 'content/studio_svg_textures/',
  'content-models.zip': 'content/models/',
  'content-textures3.zip': 'PlatformContent/pc/textures/',
  'content-terrain.zip': 'PlatformContent/pc/terrain/',
  'content-platform-fonts.zip': 'PlatformContent/pc/fonts/',
  'content-platform-dictionaries.zip':
    'PlatformContent/pc/shared_compression_dictionaries/',
  'content-qt_translations.zip': 'content/qt_translations/',
  'content-api-docs.zip': 'content/api_docs/',
  'extracontent-scripts.zip': 'ExtraContent/scripts/',
  'extracontent-luapackages.zip': 'ExtraContent/LuaPackages/',
  'extracontent-translations.zip': 'ExtraContent/translations/',
  'extracontent-models.zip': 'ExtraContent/models/',
  'extracontent-textures.zip': 'ExtraContent/textures/',
  'studiocontent-models.zip': 'StudioContent/models/',
  'studiocontent-textures.zip': 'StudioContent/textures/',
  'shaders.zip': 'shaders/',
  'BuiltInPlugins.zip': 'BuiltInPlugins/',
  'BuiltInStandalonePlugins.zip': 'BuiltInStandalonePlugins/',
  'LibrariesQt5.zip': '',
  'Plugins.zip': 'Plugins/',
  'StudioFonts.zip': 'StudioFonts/',
  'ssl.zip': 'ssl/',
  'WebView2.zip': '',
  'WebView2RuntimeInstaller.zip': 'WebView2RuntimeInstaller/',
};
