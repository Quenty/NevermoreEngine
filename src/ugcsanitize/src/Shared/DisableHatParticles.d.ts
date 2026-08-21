import { BaseObject } from '@quenty/baseobject';

interface DisableHatParticles extends BaseObject {
  Destroy(): void;
}

interface DisableHatParticlesConstructor {
  readonly ClassName: 'DisableHatParticles';
  new (character: Model): DisableHatParticles;
}

export const DisableHatParticles: DisableHatParticlesConstructor;
