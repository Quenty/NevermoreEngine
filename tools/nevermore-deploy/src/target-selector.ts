/**
 * The separator between a target name and a place name inside it. Spelled out
 * rather than a bare dot so a selector reads as a path into the config —
 * `integration.places.hub` is literally `targets.integration.places[name=hub]`.
 */
const PLACES_SEGMENT = '.places.';

/**
 * A target, optionally narrowed to one place inside it.
 *
 * Selectors exist because a watch dispatch has to name a single place in one
 * string: a GitHub `workflow_dispatch` input is a string, and the workflow
 * hands it straight back to `nevermore deploy run`. Splitting it into two flags
 * would mean the dispatcher and the workflow have to agree on argument shape
 * instead of just passing a token through.
 */
export interface TargetSelector {
  targetName: string;
  /** Absent when the selector names the whole target. */
  placeName?: string;
}

/**
 * Parse `integration` or `integration.places.hub`.
 *
 * The target name is everything before the first `.places.`, so a target whose
 * own name contains a dot still parses. Throws on a selector with an empty half,
 * which is almost always a shell or workflow-input mistake rather than intent.
 */
export function parseTargetSelector(selector: string): TargetSelector {
  const separatorIndex = selector.indexOf(PLACES_SEGMENT);
  if (separatorIndex === -1) {
    if (selector === '') {
      throw new Error('Target selector is empty');
    }
    return { targetName: selector };
  }

  const targetName = selector.slice(0, separatorIndex);
  const placeName = selector.slice(separatorIndex + PLACES_SEGMENT.length);

  if (targetName === '' || placeName === '') {
    throw new Error(
      `Invalid target selector "${selector}" — expected ` +
        `"<target>" or "<target>${PLACES_SEGMENT}<place>".`
    );
  }

  return { targetName, placeName };
}

/** Inverse of {@link parseTargetSelector}. */
export function formatTargetSelector(selector: TargetSelector): string {
  return selector.placeName == null
    ? selector.targetName
    : `${selector.targetName}${PLACES_SEGMENT}${selector.placeName}`;
}
