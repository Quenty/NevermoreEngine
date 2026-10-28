import { describe, it, expect } from 'vitest';
import { parseBoolSetting } from './studio-settings.js';

describe('parseBoolSetting', () => {
  const xml = `<Item class="UserSettings"><Properties>
    <bool name="LoadAllBuiltinPluginsInRunModes">true</bool>
    <bool name="LoadUserPluginsInRunModes">false</bool>
  </Properties></Item>`;

  it('reads the named setting, not one whose name contains it', () => {
    expect(parseBoolSetting(xml, 'LoadUserPluginsInRunModes')).toBe(false);
    expect(parseBoolSetting(xml, 'LoadAllBuiltinPluginsInRunModes')).toBe(true);
  });

  it('is undefined for a setting the file does not have', () => {
    expect(parseBoolSetting(xml, 'Missing')).toBeUndefined();
  });
});
