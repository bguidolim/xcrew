import { expect, mock, test } from 'claude-code/testing'
import * as captured from './fixtures'
import { resultBundleOf, sourceLocationOf, withLocations } from './locations'
import { callTool, runCommand } from './testing'

test('a failing test\'s details give the file and line it failed at; a crash\'s give none', () => {
  expect(sourceLocationOf(captured.xcresultFailureDetails)).toBe('/Users/dev/App/Tests/FormatterTests.swift:7')
  expect(sourceLocationOf(captured.xcresultCrashDetails)).toBeUndefined()
  expect(sourceLocationOf('not json')).toBeUndefined()
})

test('the result bundle is found from the paths the result lists', () => {
  expect(resultBundleOf(captured.mobileTestsFailedUnlocated.text, '/Users/dev')).toBe(
    '/Users/dev/Library/Developer/MobileBuildMCP/workspaces/sample-0000/result-bundles/test_sim_1.xcresult',
  )
  expect(resultBundleOf(captured.mobileBuildFailed.text, '/Users/dev')).toBeUndefined()
})

test('each failure gets its location on the next line, as MobileBuildMCP writes it for compile errors', () => {
  const located = withLocations(captured.mobileTestsFailedUnlocated.text, new Map([['FormatterTests/test_symbol', '/Users/dev/App/Tests/FormatterTests.swift:7']]))
  expect(located).toContain('  ✗ FormatterTests / test_symbol(): failed - deliberate failure\n    /Users/dev/App/Tests/FormatterTests.swift:7\n')
})

test('a failing run reaches Claude and the pane with where each test failed, read from the result bundle', async ($, on) => {
  mock.clock(on)
  mock.store(on)
  mock.env(on, { HOME: '/Users/dev' })
  const runs: (readonly string[])[] = []
  on('session.surfaces', () => ({ value: [] }))
  on('ui.status', () => ({ value: undefined }))
  on('ui.toast', () => ({ value: undefined }))
  on('ui.open', () => ({ value: { isPlaced: true } }))
  on('command.register', (_, e) => ({ value: { command: e.name } }))
  on('process.run', (_, e) => {
    runs.push(e.argv)
    const stdout = e.argv.includes('test-details') ? captured.xcresultFailureDetails : ''
    return { value: { exitCode: 0, stdout, stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
  })
  on('tool.call', () => ({ result: {}, text: captured.mobileTestsFailedUnlocated.text, isError: true }))

  const ran = await callTool($, 'mcp__MobileBuildMCP__test_sim')

  expect(runs).toContainEqual([
    'xcrun', 'xcresulttool', 'get', 'test-results', 'test-details', '--test-id', 'FormatterTests/test_symbol()',
    '--path', '/Users/dev/Library/Developer/MobileBuildMCP/workspaces/sample-0000/result-bundles/test_sim_1.xcresult', '--compact',
  ])
  expect(ran.result).toContain('failed - deliberate failure\n    /Users/dev/App/Tests/FormatterTests.swift:7')
  expect((await runCommand($, 'xcrew', 'failures')).text).toBe('1 failure from test_sim, in the pane.')
})

test('a failure MobileBuildMCP already located is not looked up again', async ($, on) => {
  mock.clock(on)
  mock.store(on)
  mock.env(on, { HOME: '/Users/dev' })
  const runs: (readonly string[])[] = []
  on('session.surfaces', () => ({ value: [] }))
  on('ui.status', () => ({ value: undefined }))
  on('ui.toast', () => ({ value: undefined }))
  on('process.run', (_, e) => {
    runs.push(e.argv)
    return { value: { exitCode: 0, stdout: '', stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
  })
  on('tool.call', () => ({ result: {}, text: captured.mobileTestsFailed.text, isError: true }))

  await callTool($, 'mcp__MobileBuildMCP__test_sim')

  expect(runs.filter(argv => argv.includes('xcresulttool'))).toEqual([])
})
