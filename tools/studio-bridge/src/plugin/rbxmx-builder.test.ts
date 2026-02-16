import { describe, it, expect } from 'vitest';
import { buildRbxmx } from './rbxmx-builder.js';

describe('buildRbxmx', () => {
  it('generates valid rbxmx XML structure', () => {
    const xml = buildRbxmx({ name: 'TestPlugin', source: 'print("hello")' });

    expect(xml).toContain('<roblox version="4">');
    expect(xml).toContain('<Item class="Script" referent="0">');
    expect(xml).toContain('<string name="Name">TestPlugin</string>');
    expect(xml).toContain('<ProtectedString name="Source"><![CDATA[print("hello")]]></ProtectedString>');
    expect(xml).toContain('</roblox>');
  });

  it('uses the given name', () => {
    const xml = buildRbxmx({ name: 'StudioBridgePlugin', source: '' });
    expect(xml).toContain('<string name="Name">StudioBridgePlugin</string>');
  });

  it('handles empty source', () => {
    const xml = buildRbxmx({ name: 'Empty', source: '' });
    expect(xml).toContain('<![CDATA[]]>');
  });

  it('escapes CDATA end sequence ]]> in source', () => {
    const xml = buildRbxmx({
      name: 'Test',
      source: 'local x = "]]>"',
    });

    // The literal ]]> should NOT appear inside a CDATA section
    // Instead it should be split: ]]]]><![CDATA[>
    expect(xml).not.toContain('<![CDATA[local x = "]]>');
    expect(xml).toContain(']]]]><![CDATA[>');
  });

  it('handles multiple ]]> sequences', () => {
    const xml = buildRbxmx({
      name: 'Test',
      source: ']]> and ]]> again',
    });

    // Count occurrences of the escaped sequence
    const matches = xml.match(/\]\]\]\]><!\[CDATA\[>/g);
    expect(matches).toHaveLength(2);
  });

  it('preserves multiline source correctly', () => {
    const source = [
      'local x = 1',
      'local y = 2',
      'print(x + y)',
    ].join('\n');

    const xml = buildRbxmx({ name: 'Test', source });
    expect(xml).toContain('local x = 1\nlocal y = 2\nprint(x + y)');
  });
});
