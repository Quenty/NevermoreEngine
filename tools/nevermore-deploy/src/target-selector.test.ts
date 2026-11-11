import { describe, it, expect } from 'vitest';
import {
  formatTargetSelector,
  parseTargetSelector,
} from './target-selector.js';

describe('parseTargetSelector', () => {
  it('treats a bare name as the whole target', () => {
    expect(parseTargetSelector('integration')).toEqual({
      targetName: 'integration',
    });
  });

  it('splits a target and place', () => {
    expect(parseTargetSelector('integration.places.hub')).toEqual({
      targetName: 'integration',
      placeName: 'hub',
    });
  });

  it('splits on the first .places. so a dotted target name survives', () => {
    expect(parseTargetSelector('prod.us.places.hub')).toEqual({
      targetName: 'prod.us',
      placeName: 'hub',
    });
  });

  it('keeps a place name containing dots intact', () => {
    expect(parseTargetSelector('integration.places.hub.v2')).toEqual({
      targetName: 'integration',
      placeName: 'hub.v2',
    });
  });

  it('rejects an empty selector', () => {
    expect(() => parseTargetSelector('')).toThrowError(/empty/);
  });

  it('rejects a selector missing the place half', () => {
    expect(() => parseTargetSelector('integration.places.')).toThrowError(
      /Invalid target selector/
    );
  });

  it('rejects a selector missing the target half', () => {
    expect(() => parseTargetSelector('.places.hub')).toThrowError(
      /Invalid target selector/
    );
  });
});

describe('formatTargetSelector', () => {
  it('round-trips a target and place', () => {
    const selector = 'integration.places.hub';
    expect(formatTargetSelector(parseTargetSelector(selector))).toBe(selector);
  });

  it('omits the places segment when there is no place', () => {
    expect(formatTargetSelector({ targetName: 'integration' })).toBe(
      'integration'
    );
  });
});
