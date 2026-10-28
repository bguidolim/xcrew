import type { On } from 'claude-code'
import { average, stopwatch } from './format'
import { summarize } from './results'
import { kindOf, parseTool } from './tools'

/** How many earlier runs of each tool the average covers. */
const HISTORY = 10
const historyKey = (tool: string) => `durations.${tool}`
/** Runs at least this long also send a notification. */
const LONG_RUN_MS = 60_000

/** Bookkeeping is best-effort: a clock, store or display failure must never fail a build. */
async function quietly<T>(work: () => Promise<T> | T): Promise<T | undefined> {
  try {
    return await work()
  } catch {
    return undefined
  }
}

/**
 * Times builds, test runs and app runs: a status line counts while one runs, a toast reports the
 * result and how it compares with the last runs of the same tool, and a long run also notifies.
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
        if (now !== undefined) await quietly(() => $.ui.status(`${name} running · ${stopwatch(now - started)}`))
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
    const outcome = result.deny !== undefined ? { ok: false } : summarize(name, { isError: result.isError === true, text: result.text ?? '' })
    const comparison = earlier.length > 0 ? ` (avg ${stopwatch(average(earlier))})` : ''
    const detail = outcome.detail ? ` · ${outcome.detail}` : ''
    const summary = `${outcome.ok ? '✓' : '✗'} ${name} · ${stopwatch(elapsed)}${comparison}${detail}`
    await quietly(() => $.ui.toast(summary))
    // Long enough that the person has likely looked away; their notification settings decide how it arrives.
    if (elapsed >= LONG_RUN_MS) await quietly(() => $.ui.notify(summary))
    return result
  })
}
