/** `m:ss`, as a stopwatch reads: 72 000 ms is `1:12`. */
export function stopwatch(ms: number): string {
  const seconds = Math.round(ms / 1000)
  return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`
}

export function average(values: readonly number[]): number {
  return values.reduce((sum, value) => sum + value, 0) / values.length
}
