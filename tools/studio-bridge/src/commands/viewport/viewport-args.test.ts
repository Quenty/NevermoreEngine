import { describe, it, expect } from 'vitest';
import { parseRegion, toViewportReadOptions } from './viewport-args.js';

describe('parseRegion', () => {
  it('reads x,y,width,height', () => {
    expect(parseRegion('10, 20,640,360')).toEqual([10, 20, 640, 360]);
  });

  it.each(['10,20,640', '0,0,0,10', 'a,b,c,d', '-1,0,10,10'])(
    'rejects %s',
    (value) => {
      expect(() => parseRegion(value)).toThrow("Can't read --region");
    }
  );
});

describe('toViewportReadOptions', () => {
  it('leaves out what was not given', () => {
    expect(toViewportReadOptions({})).toEqual({});
  });

  it('passes region and scale through', () => {
    expect(toViewportReadOptions({ region: '0,0,10,10', scale: 0.5 })).toEqual({
      region: [0, 0, 10, 10],
      scale: 0.5,
    });
  });

  it('rejects a scale above 1', () => {
    expect(() => toViewportReadOptions({ scale: 2 })).toThrow('--scale');
  });
});
