import type { On } from 'claude-code'
import { average, stopwatch } from './format'
import { kindOf, parseTool } from './tools'

/** How many earlier runs of each tool the average covers. */
const HISTORY = 10
const historyKey = (tool: string) => `durations.${tool}`

/** Bookkeeping is best-effort: a clock, store or display failure must never fail a build. */
async function quietly<T>(work: () => Promise<T> | T): Promise<T | undefined> {
  try {
    return await work()
  } catch {
    return undefined
  }
}

/**
 * Times builds, test runs and app runs: a status line counts while one runs, and a toast reports
 * the result and how it compares with the last runs of the same tool.
 */
export function registerTiming(on: On): void {
  on('tool.call', async ($, e, next) => {
    const parsed = parseTool(e.tool)
    if (!parsed || !kindOf(parsed)) return next(e)
    const name = parsed.tool

    const started = await quietly(() => $.clock.now())
    const ticker = started === undefined ? undefined : await quietly(() =>
      $.clock.every(1000, async () => {
        const now = await quietly(() => $.clock.now())
        if (now !== undefined) await quietly(() => $.ui.status(`xcrew: ${name} running · ${stopwatch(now - started)}`))
      }),
    )

    const result = await next(e)

    ticker?.cancel()
    await quietly(() => $.ui.status(undefined))
    const ended = await quietly(() => $.clock.now())
    if (started === undefined || ended === undefined) return result

    const elapsed = ended - started
    const earlier = ((await quietly(() => $.store.get(historyKey(name)))) as number[] | undefined) ?? []
    await quietly(() => $.store.set(historyKey(name), [...earlier, elapsed].slice(-HISTORY)))
    const mark = result.isError === true || result.deny !== undefined ? '✗' : '✓'
    const comparison = earlier.length > 0 ? ` (avg ${stopwatch(average(earlier))})` : ''
    await quietly(() => $.ui.toast(`${mark} ${name} · ${stopwatch(elapsed)}${comparison}`))
    return result
  })
}
