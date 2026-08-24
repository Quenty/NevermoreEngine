import { Maid } from '@quenty/maid';

export namespace ParticleEmitterUtils {
  function scaleSize(adornee: Instance, scale: number): void;
  function playFromTemplate(template: Instance, attachment: Attachment): Maid;
  function getParticleEmitters(adornee: Instance): ParticleEmitter[];
}
