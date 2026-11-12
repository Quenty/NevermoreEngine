import { describe, it, expect } from 'vitest';
import type { BridgeSession } from '../../bridge/index.js';
import {
  parseRegion,
  resolveCaptureSource,
  toViewportReadOptions,
} from './viewport-args.js';

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

describe('resolveCaptureSource', () => {
  function session(context: string, state: string): BridgeSession {
    return {
      context,
      info: { sessionId: `${context}-1`, state },
    } as unknown as BridgeSession;
  }

  it('captures Edit through CaptureService', () => {
    expect(resolveCaptureSource(session('edit', 'Edit'))).toBe(
      'captureService'
    );
  });

  it('captures a playtest server through Studio MCP, since CaptureService refuses a server', () => {
    expect(resolveCaptureSource(session('server', 'Play'))).toBe('studioMcp');
  });

  it('captures a playtest client through Studio MCP, since a client cannot read back its captures', () => {
    expect(resolveCaptureSource(session('client', 'Play'))).toBe('studioMcp');
  });

  it('refuses a Run-mode playtest, which has no client to render it', () => {
    expect(() => resolveCaptureSource(session('server', 'Run'))).toThrow(
      'Run-mode'
    );
  });
});
