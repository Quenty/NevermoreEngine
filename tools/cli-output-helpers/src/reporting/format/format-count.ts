export function formatCount(
  count: number,
  singular: string,
  plural: string
): string {
  return `${count.toLocaleString('en-US')} ${count === 1 ? singular : plural}`;
}
