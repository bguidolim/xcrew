import { expect, mock, test } from 'claude-code/testing'
import type { On } from 'claude-code'

const MALFORMED =
  "External macro implementation type 'MockableMacros.MockableMacro' could not be found; plugin for module 'MockableMacros' produced malformed response"

type Seen = { toasts: string[]; statuses: (string | undefined)[]; runs: (readonly string[])[] }

/** Records what the mod shows and runs; `repairOutput` is what `xcrew repair-macros` prints. */
function watch(on: On, repairOutput = ''): Seen {
  const seen: Seen = { toasts: [], statuses: [], runs: [] }
  mock.store(on)
  on('ui.toast', (_, e) => {
    seen.toasts.push(e.text)
    return { value: undefined }
  })
  on('ui.status', (_, e) => {
    seen.statuses.push(e.text)
    return { value: undefined }
  })
  on('process.run', (_, e) => {
    seen.runs.push(e.argv)
    return {
      value: { exitCode: 0, stdout: repairOutput, stderr: '', isStdoutTruncated: false, isStderrTruncated: false },
    }
  })
  return seen
}

// MARK: The project-file guard

test('XcodeWrite is refused under either registration, with the alternative named', async ($, on) => {
  on('tool.call', () => ({ result: {} }))
  for (const tool of ['mcp__xcode__XcodeWrite', 'mcp__plugin_xcrew_xcode__XcodeWrite']) {
    const ran = await $.tool.call({ tool, filePath: 'App/New.swift', content: '' })
    expect(ran.deny).toContain('Write tool')
  }
})

test('other Xcode file tools pass', async ($, on) => {
  on('tool.call', () => ({ result: { ok: true } }))
  const ran = await $.tool.call({ tool: 'mcp__xcode__XcodeUpdate', filePath: 'a', oldString: 'x', newString: 'y' })
  expect(ran.isError).toBeUndefined()
})

// MARK: Macro-plugin repair

test('a build killed by a dead macro plugin is repaired and retried once', async ($, on) => {
  mock.clock(on)
  const seen = watch(on, 'repaired: Debug-iphonesimulator/MockableMacros\n')
  let calls = 0
  on('tool.call', () => {
    calls += 1
    return calls === 1 ? { result: {}, isError: true, text: MALFORMED } : { result: { ok: true }, text: 'Build succeeded' }
  })

  const ran = await $.tool.call({ tool: 'mcp__plugin_xcrew_xcode__BuildProject' })

  expect(calls).toBe(2)
  expect(ran.isError).toBeUndefined()
  expect(seen.runs).toHaveLength(1)
  expect(seen.runs[0][0]).toMatch(/\/bin\/xcrew$/)
  expect(seen.runs[0].slice(1)).toEqual(['repair-macros'])
  expect(seen.toasts).toContain('repaired Debug-iphonesimulator/MockableMacros and retried BuildProject')
})

test('when nothing was repaired, the failure stands and the build is not retried', async ($, on) => {
  mock.clock(on)
  const seen = watch(on, 'all 4 macro plugins answer\n')
  let calls = 0
  on('tool.call', () => {
    calls += 1
    return { result: {}, isError: true, text: MALFORMED }
  })

  const ran = await $.tool.call({ tool: 'mcp__xcode__BuildProject' })

  expect(calls).toBe(1)
  expect(ran.isError).toBe(true)
  expect(seen.runs).toHaveLength(1)
})

test('other build failures do not run the repair', async ($, on) => {
  mock.clock(on)
  const seen = watch(on)
  on('tool.call', () => ({ result: {}, isError: true, text: "error: cannot find 'foo' in scope" }))
  await $.tool.call({ tool: 'mcp__xcode__BuildProject' })
  expect(seen.runs).toHaveLength(0)
})

// MARK: Build and test timing

test('a build shows its elapsed time while it runs and a toast when it ends', async ($, on) => {
  const clock = mock.clock(on)
  const seen = watch(on)
  on('tool.call', async () => {
    await clock.advance(3_000)
    expect(seen.statuses.at(-1)).toBe('build_sim running · 0:03')
    await clock.advance(69_000)
    return { result: {}, text: 'Build succeeded' }
  })

  await $.tool.call({ tool: 'mcp__plugin_xcrew_MobileBuildMCP__build_sim' })

  expect(seen.statuses.at(-1)).toBeUndefined()
  expect(seen.toasts).toEqual(['✓ build_sim · 1:12'])
})

test('a failed test run says so', async ($, on) => {
  mock.clock(on)
  const seen = watch(on)
  on('tool.call', () => ({ result: {}, isError: true, text: '2 tests failed' }))
  await $.tool.call({ tool: 'mcp__MobileBuildMCP__test_sim' })
  expect(seen.toasts).toEqual(['✗ test_sim · 0:00'])
})

test('later runs compare with the average of earlier ones', async ($, on) => {
  const clock = mock.clock(on)
  const seen = watch(on)
  const durations = [60_000, 80_000, 90_000]
  on('tool.call', async () => {
    await clock.advance(durations.shift() ?? 0)
    return { result: {}, text: 'ok' }
  })

  for (let run = 0; run < 3; run += 1) {
    await $.tool.call({ tool: 'mcp__xcode__BuildProject' })
  }

  expect(seen.toasts).toEqual(['✓ BuildProject · 1:00', '✓ BuildProject · 1:20 (avg 1:00)', '✓ BuildProject · 1:30 (avg 1:10)'])
})

test('tools that neither build, test nor run are not timed', async ($, on) => {
  mock.clock(on)
  const seen = watch(on)
  on('tool.call', () => ({ result: {}, text: 'contents' }))
  await $.tool.call({ tool: 'mcp__xcode__XcodeRead', filePath: 'a' })
  await $.tool.call({ tool: 'mcp__MobileBuildMCP__list_schemes' })
  await $.tool.call({ tool: 'Bash', command: 'ls' })
  expect(seen.toasts).toEqual([])
  expect(seen.statuses).toEqual([])
})

test('timing that fails never blocks the build', async ($, on) => {
  // No clock or store beneath: every bookkeeping call fails.
  let calls = 0
  on('tool.call', () => {
    calls += 1
    return { result: {}, text: 'Build succeeded' }
  })
  const ran = await $.tool.call({ tool: 'mcp__xcode__BuildProject' })
  expect(calls).toBe(1)
  expect(ran.text).toBe('Build succeeded')
})

test('a repair that cannot run leaves the original failure', async ($, on) => {
  mock.clock(on)
  mock.store(on)
  on('process.run', () => {
    throw new Error('xcrew not built')
  })
  let calls = 0
  on('tool.call', () => {
    calls += 1
    return { result: {}, isError: true, text: MALFORMED }
  })
  const ran = await $.tool.call({ tool: 'mcp__xcode__BuildProject' })
  expect(calls).toBe(1)
  expect(ran.text).toBe(MALFORMED)
})
