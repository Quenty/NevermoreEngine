import { Maid } from '@quenty/maid';
import { Promise } from '@quenty/promise';

export namespace LinkUtils {
  function createLink(
    linkName: string,
    from: Instance,
    to: Instance
  ): ObjectValue;
  function getAllLinkValues(linkName: string, from: Instance): ObjectValue[];
  function setSingleLinkValue(
    linkName: string,
    from: Instance,
    to: Instance
  ): ObjectValue | undefined;
  function getAllLinks(linkName: string, from: Instance): ObjectValue[];
  function getLinkValue(
    linkName: string,
    from: Instance
  ): ObjectValue | undefined;
  function promiseLinkValue(
    maid: Maid,
    linkName: string,
    from: Instance
  ): Promise<Instance>;
}
