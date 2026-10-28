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

/** A project root holding these files; the engine beneath answers the mod's file checks. */
function projectWith(on: On, files: string[]): void {
  on('session.root', () => ({ value: '/work/App' }))
  on('fs.exists', (_, e) => ({ value: files.some(file => e.path === `/work/App/${file}`) }))
}

test('in a generated project XcodeWrite is refused under either registration, with the alternative named', async ($, on) => {
  projectWith(on, ['Project.swift'])
  on('tool.call', () => ({ result: {} }))
  for (const tool of ['mcp__xcode__XcodeWrite', 'mcp__plugin_xcrew_xcode__XcodeWrite']) {
    const ran = await $.tool.call({ tool, filePath: 'App/New.swift', content: '' })
    expect(ran.deny).toContain('Write tool')
  }
})

test('an XcodeGen project counts as generated too', async ($, on) => {
  projectWith(on, ['project.yml'])
  on('tool.call', () => ({ result: {} }))
  const ran = await $.tool.call({ tool: 'mcp__xcode__XcodeWrite', filePath: 'a', content: '' })
  expect(ran.deny).toBeDefined()
})

test('in a classic Xcode project XcodeWrite works, since it is how a file joins its target there', async ($, on) => {
  projectWith(on, ['App.xcodeproj'])
  on('tool.call', () => ({ result: { ok: true } }))
  const ran = await $.tool.call({ tool: 'mcp__xcode__XcodeWrite', filePath: 'a', content: '' })
  expect(ran.deny).toBeUndefined()
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

// MARK: Long runs

test('a run of a minute or more sends a notification with its outcome', async ($, on) => {
  const clock = mock.clock(on)
  mock.store(on)
  const notifications: string[] = []
  on('ui.toast', () => ({ value: undefined }))
  on('ui.status', () => ({ value: undefined }))
  on('ui.notify', (_, e) => {
    notifications.push(e.text)
    return { value: { isSent: true, channel: 'terminal' } }
  })
  on('tool.call', async () => {
    await clock.advance(61_000)
    return { result: {}, text: '{"counts":{"failed":0,"passed":5,"total":5}}' }
  })

  await $.tool.call({ tool: 'mcp__xcode__RunAllTests' })

  expect(notifications).toEqual(['✓ RunAllTests · 1:01 · 5 passed'])
})

test('a shorter run does not notify', async ($, on) => {
  const clock = mock.clock(on)
  mock.store(on)
  const notifications: string[] = []
  on('ui.toast', () => ({ value: undefined }))
  on('ui.status', () => ({ value: undefined }))
  on('ui.notify', (_, e) => {
    notifications.push(e.text)
    return { value: { isSent: true, channel: 'terminal' } }
  })
  on('tool.call', async () => {
    await clock.advance(59_000)
    return { result: {}, text: 'ok' }
  })

  await $.tool.call({ tool: 'mcp__xcode__BuildProject' })

  expect(notifications).toEqual([])
})

test('a notification that cannot be sent never affects the run', async ($, on) => {
  const clock = mock.clock(on)
  mock.store(on)
  on('ui.toast', () => ({ value: undefined }))
  on('ui.status', () => ({ value: undefined }))
  on('ui.notify', () => {
    throw new Error('no channel')
  })
  on('tool.call', async () => {
    await clock.advance(90_000)
    return { result: {}, text: 'Build succeeded' }
  })

  const ran = await $.tool.call({ tool: 'mcp__xcode__BuildProject' })

  expect(ran.text).toBe('Build succeeded')
})

// MARK: What's building

import * as captured from './fixtures'

/** Answers each call with the next captured result, and records the status line. */
function serve(on: On, results: Record<string, { isError: boolean; text: string }>, clock: { advance: (ms: number) => Promise<void> }) {
  const statuses: (string | undefined)[] = []
  on('ui.status', (_, e) => {
    statuses.push(e.text)
    return { value: undefined }
  })
  on('ui.toast', () => ({ value: undefined }))
  on('tool.call', async (_, e) => {
    const answer = results[e.tool.split('__').pop() ?? '']
    if (/build|test/i.test(e.tool)) await clock.advance(3_000)
    return { result: {}, text: answer?.text ?? 'ok', ...(answer?.isError ? { isError: true } : {}) }
  })
  return statuses
}

test('the status line names the scheme and simulator MobileBuildMCP will use', async ($, on) => {
  const clock = mock.clock(on)
  mock.store(on)
  const statuses = serve(on, { session_show_defaults: captured.mobileSessionDefaults }, clock)

  await $.tool.call({ tool: 'mcp__plugin_xcrew_MobileBuildMCP__session_show_defaults' })
  await $.tool.call({ tool: 'mcp__plugin_xcrew_MobileBuildMCP__test_sim' })

  expect(statuses).toContain('test_sim · MacroProbe-Package on iPhone 16 · 0:03')
})

test('switching profiles changes what the status line names', async ($, on) => {
  const clock = mock.clock(on)
  mock.store(on)
  const statuses = serve(on, { session_show_defaults: captured.mobileSessionDefaults, session_use_defaults_profile: captured.mobileProfileSwitched }, clock)

  await $.tool.call({ tool: 'mcp__MobileBuildMCP__session_show_defaults' })
  await $.tool.call({ tool: 'mcp__MobileBuildMCP__session_use_defaults_profile', profile: 'unit' })
  await $.tool.call({ tool: 'mcp__MobileBuildMCP__build_sim' })

  expect(statuses).toContain('build_sim · iPhone 12 · 0:03')
})

test('the status line names the scheme and destination the Xcode MCP has active', async ($, on) => {
  const clock = mock.clock(on)
  mock.store(on)
  const statuses = serve(on, { XcodeOpenWorkspace: captured.xcodeWorkspaceOpened }, clock)

  await $.tool.call({ tool: 'mcp__xcode__XcodeOpenWorkspace', path: '/Users/dev/MacroProbe' })
  await $.tool.call({ tool: 'mcp__xcode__BuildProject' })

  expect(statuses).toContain('BuildProject · MacroProbe-Package on My Mac · 0:03')
})

test('with nothing learned yet, the status line stays as it was', async ($, on) => {
  const clock = mock.clock(on)
  mock.store(on)
  const statuses = serve(on, {}, clock)
  await $.tool.call({ tool: 'mcp__MobileBuildMCP__build_sim' })
  expect(statuses).toContain('build_sim running · 0:03')
})
