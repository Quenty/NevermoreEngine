import { Observable, Operator, Rx } from '@quenty/rx';
import { BasicPane } from './BasicPane';
import { Maid } from '@quenty/maid';
import { Brio } from '@quenty/brio';

export namespace BasicPaneUtils {
  function observeVisible(basicPane: BasicPane): Observable<boolean>;
  function whenVisibleBrio(
    createBasicPane: (maid: Maid) => BasicPane
  ): Operator<boolean, Brio<GuiBase>>;
  function observePercentVisible(basicPane: BasicPane): Observable<number>;
  const toTransparency: typeof Rx.map<number, number>;
  function observeShow(basicPane: BasicPane): Observable<boolean>;
}
