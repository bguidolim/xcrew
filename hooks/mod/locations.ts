import type { EngineInterface } from 'claude-code'

/**
 * Where each failing test failed. Run on parallel simulator clones, xcodebuild logs a failing test
 * without its file and line, so MobileBuildMCP's result lacks them; the run's result bundle has
 * them, one `xcresulttool` lookup per test (about 0.04 s and 2 KB each).
 */

/** At most this many failures are looked up: past it, the first ones are enough to start from. */
const MOST_LOOKUPS = 10

/** `✗ Suite / test(): message`, as MobileBuildMCP lists a failing test. */
const FAILURE = /^\s*✗ (.+?) \/ (\S+?): /

/** The first source location in `xcresulttool get test-results test-details` output, as `path:line`. */
export function sourceLocationOf(details: string): string | undefined {
  let json: unknown
  try {
    json = JSON.parse(details)
  } catch {
    return undefined
  }
  const stack: unknown[] = [json]
  while (stack.length > 0) {
    const node = stack.shift()
    if (Array.isArray(node)) stack.push(...node)
    else if (node && typeof node === 'object') {
      const location = (node as { sourceLocation?: { filePath?: string; lineNumber?: number } }).sourceLocation
      if (location?.filePath && location.lineNumber !== undefined) return `${location.filePath}:${location.lineNumber}`
      stack.push(...Object.values(node))
    }
  }
  return undefined
}

/** The run's `.xcresult`, from the workspace folder and bundle path its result lists. */
export function resultBundleOf(text: string, home: string): string | undefined {
  const folder = /└── (~?\/\S+\/)\s*$/m.exec(text)?.[1]
  const bundle = /(result-bundles\/\S+\.xcresult) — Result Bundle/.exec(text)?.[1]
  if (!folder || !bundle) return undefined
  return `${folder.replace(/^~/, home)}${bundle}`
}

/** A test as `Suite/test`: MobileBuildMCP lists one failure both with and without the `()`. */
function key(suite: string, test: string): string {
  return `${suite}/${test.replace(/\(\)$/, '')}`
}

/** The failing tests with no location on any of their lines. */
function unlocated(text: string): string[] {
  const lines = text.split('\n')
  const listed = new Set<string>()
  const located = new Set<string>()
  lines.forEach((line, index) => {
    const failure = FAILURE.exec(line)
    if (!failure) return
    const test = key(failure[1] ?? '', failure[2] ?? '')
    listed.add(test)
    if (/^\s+\/\S+:\d+\s*$/.test(lines[index + 1] ?? '')) located.add(test)
  })
  return [...listed].filter(test => !located.has(test))
}

/** Writes each found location on the line after its failure. */
export function withLocations(text: string, locations: ReadonlyMap<string, string>): string {
  return text
    .split('\n')
    .flatMap(line => {
      const failure = FAILURE.exec(line)
      const location = failure ? locations.get(key(failure[1] ?? '', failure[2] ?? '')) : undefined
      return location ? [line, `    ${location}`] : [line]
    })
    .join('\n')
}

/** The failing run's text with where each failure happened, or the text as it was when none is found. */
export async function locateFailures($: EngineInterface, text: string): Promise<string> {
  const tests = unlocated(text).slice(0, MOST_LOOKUPS)
  const home = tests.length > 0 ? await $.env.get('HOME') : undefined
  const bundle = home ? resultBundleOf(text, home) : undefined
  if (!bundle) return text
  const found = new Map<string, string>()
  for (const test of tests) {
    const ran = await $.process
      // The result bundle names a test with its `()`.
      .run(['xcrun', 'xcresulttool', 'get', 'test-results', 'test-details', '--test-id', `${test}()`, '--path', bundle, '--compact'], { timeoutMs: 15_000 })
      .catch(() => undefined)
    const location = ran ? sourceLocationOf(ran.stdout) : undefined
    if (location) found.set(test, location)
  }
  return found.size > 0 ? withLocations(text, found) : text
}
