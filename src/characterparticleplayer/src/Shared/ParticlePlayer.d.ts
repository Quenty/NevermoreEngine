interface ParticlePlayer {
  PlayLevelUpEffect(humanoid: Humanoid): boolean;
}

interface ParticlePlayerConstructor {
  readonly ClassName: 'ParticlePlayer';
  new (): ParticlePlayer;
}

export const ParticlePlayer: ParticlePlayerConstructor;
