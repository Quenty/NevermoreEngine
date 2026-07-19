import { Brio } from '@quenty/brio';
import { Observable } from '@quenty/rx';

export namespace RxToolUtils {
  function observeEquippedHumanoidBro(tool: Tool): Observable<Brio<Humanoid>>;
}
