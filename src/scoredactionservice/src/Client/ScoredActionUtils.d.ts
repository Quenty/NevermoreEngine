import { Maid } from '@quenty/maid';
import { ScoredAction } from './ScoredAction';

export namespace ScoredActionUtils {
  function connectToPreferred(
    scoredAction: ScoredAction,
    callback: (maid: Maid) => void
  ): Maid;
}
