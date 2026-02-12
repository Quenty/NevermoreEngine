import { Brio } from '@quenty/brio';
import { Observable } from '@quenty/rx';

export namespace RxLinkUtils {
  function observeValidLinksBrio(
    linkName: string,
    parent: Instance
  ): Observable<Brio<ObjectValue>>;
  function observeLinkValueBrio(
    linkName: string,
    parent: Instance
  ): Observable<Instance | undefined>;
  function observeValidityBrio(
    linkName: string,
    link: Instance
  ): Observable<[link: Instance, instance: Instance]>;
}
