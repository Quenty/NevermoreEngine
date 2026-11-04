const LIST_KEYS = ['tools', 'prompts', 'resources', 'resourceTemplates'];

export function repairListResult<T>(result: T): T {
  if (!result || typeof result !== 'object') {
    return result;
  }
  const record = result as Record<string, unknown>;
  if (record.resultType === undefined) {
    return result;
  }
  if (!LIST_KEYS.some((key) => Array.isArray(record[key]))) {
    return result;
  }
  if (record.ttlMs !== undefined && record.cacheScope !== undefined) {
    return result;
  }

  return {
    ...record,
    ttlMs: record.ttlMs ?? 0,
    cacheScope: record.cacheScope ?? 'private',
  } as T;
}
