import { Brio } from '@quenty/brio';
import { Observable } from '@quenty/rx';

export namespace RxRootPartUtils {
  function observeHumanoidRootPartBrio(
    character: Model
  ): Observable<Brio<BasePart>>;
  function observeHumanoidRootPartBrioFromHumanoid(
    humanoid: Humanoid
  ): Observable<Brio<BasePart>>;
}
