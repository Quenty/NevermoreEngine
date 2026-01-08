import { Promise } from '@quenty/promise';

export namespace PolicyServiceUtils {
  function promisePolicyInfoForPlayer(player: Player): Promise<PolicyInfo>;
  function canReferenceTwitter(policyInfo: PolicyInfo): boolean;
  function canReferenceTwitch(policyInfo: PolicyInfo): boolean;
  function canReferenceDiscord(policyInfo: PolicyInfo): boolean;
  function canReferenceFacebook(policyInfo: PolicyInfo): boolean;
  function canReferenceYouTube(policyInfo: PolicyInfo): boolean;
  function canReferenceSocialMedia(
    policyInfo: PolicyInfo,
    socialInfoName: string
  ): boolean;
}
