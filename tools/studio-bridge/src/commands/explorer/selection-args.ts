/**
 * Instance selection args shared by `explorer find` and `explorer sample`, so
 * both pick out instances the same way. Studio side, both match through the
 * `instance-selection` library.
 */

import { arg, type ArgDefinition } from '../framework/arg-builder.js';
import type { InstanceSelection } from '../../server/web-socket-protocol.js';

export type { InstanceSelection };

export interface SelectionArgs {
  names?: string[];
  exact?: boolean;
  class?: string;
  tag?: string;
  root?: string;
}

export const selectionArgs: Record<keyof SelectionArgs, ArgDefinition> = {
  names: arg.positional({
    description:
      'Text in the instance name (case-insensitive). Give several to match any of them',
    required: false,
    array: true,
  }),
  exact: arg.flag({
    description: 'Match the whole name instead of part of it',
  }),
  class: arg.option({
    description: 'Only instances of this class or a subclass (IsA)',
  }),
  tag: arg.option({
    description: 'Only instances with this CollectionService tag',
  }),
  root: arg.option({
    description:
      'Dot-separated path to search under (default: the whole DataModel)',
  }),
};

/** Turns the parsed args into the selection the plugin takes. */
export function toInstanceSelection(args: SelectionArgs): InstanceSelection {
  return {
    root: args.root,
    names: args.names?.length ? args.names : undefined,
    exactName: args.exact,
    className: args.class,
    tag: args.tag,
  };
}

/**
 * Folds the single `name` older callers pass into `names`, so everything
 * downstream reads one field.
 */
export function normalizeSelection(
  selection: InstanceSelection
): InstanceSelection {
  const { name, ...rest } = selection;
  const names = [...(rest.names ?? []), ...(name ? [name] : [])];
  return { ...rest, names: names.length > 0 ? names : undefined };
}

/**
 * Normalizes the selection and throws unless it names something to match on.
 */
export function assertHasCriteria(
  selection: InstanceSelection,
  verb: string
): InstanceSelection {
  const normalized = normalizeSelection(selection);
  if (!normalized.names?.length && !normalized.className && !normalized.tag) {
    throw new Error(`Give a name, --class or --tag to ${verb}`);
  }
  return normalized;
}
