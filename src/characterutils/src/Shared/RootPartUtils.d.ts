import { Promise } from '@quenty/promise';

export namespace RootPartUtils {
  function promiseRootPart(humanoid: Humanoid): Promise<BasePart>;
  function getRootPart(character: Model): BasePart | undefined;
}
