import { expect, test } from 'claude-code/testing'
import { kindOf, parseTool } from './tools'

const kind = (name: string) => {
  const tool = parseTool(name)
  return tool ? kindOf(tool) : 'not an Xcode tool'
}

test('build, test and run tools are classified under either registration', () => {
  const cases: [string, string | undefined][] = [
    ['mcp__xcode__BuildProject', 'build'],
    ['mcp__plugin_xcrew_MobileBuildMCP__build_sim', 'build'],
    ['mcp__MobileBuildMCP__build_run_sim', 'build'],
    ['mcp__MobileBuildMCP__build_device', 'build'],
    ['mcp__MobileBuildMCP__clean', 'build'],
    ['mcp__xcode__RunAllTests', 'test'],
    ['mcp__xcode__RunSomeTests', 'test'],
    ['mcp__MobileBuildMCP__test_sim', 'test'],
    ['mcp__xcode__RunProject', 'run'],
    ['mcp__MobileBuildMCP__launch_app_sim', 'run'],
    ['mcp__xcode__DeviceInteractionInstallAndRun', 'run'],
  ]
  for (const [name, expected] of cases) expect([name, kind(name)]).toEqual([name, expected])
})

test('tools that only read or inspect are not timed', () => {
  for (const name of [
    'mcp__xcode__GetTestList',
    'mcp__xcode__GetBuildLog',
    'mcp__xcode__XcodeRead',
    'mcp__xcode__RenderPreview',
    'mcp__MobileBuildMCP__list_schemes',
    'mcp__MobileBuildMCP__show_build_settings',
    'mcp__MobileBuildMCP__screenshot',
  ]) {
    expect([name, kind(name)]).toEqual([name, undefined])
  }
})

test('other servers are not Xcode tools', () => {
  expect(kind('mcp__plugin_other_xcode__BuildProject')).toBe('not an Xcode tool')
  expect(kind('Bash')).toBe('not an Xcode tool')
})
