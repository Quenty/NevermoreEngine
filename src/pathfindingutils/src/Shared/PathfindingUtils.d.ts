import { Maid } from '@quenty/maid';
import { Promise } from '@quenty/promise';

export namespace PathfindingUtils {
  function promiseComputeAsync(
    path: Path,
    start: Vector3,
    finish: Vector3
  ): Promise<Path>;
  function promiseCheckOcclusion(
    path: Path,
    startIndex: number
  ): Promise<number>;
  function visualizePath(path: Path): Maid;
}
