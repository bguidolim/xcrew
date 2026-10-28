import type { On } from 'claude-code'
import { REPAIRABLE_TOOL_NAMES, parseTool } from './tools'

const MACRO_PLUGIN_KILLED = 'produced malformed response'

/**
 * When an Xcode MCP build fails because macOS killed a macro plugin at launch, runs
 * `xcrew repair-macros` and retries the call once, so Claude only sees the outcome. The classic
 * PostToolUseFailure hook stays as the fallback for sessions where mods don't run.
 */
export function registerRepair(on: On): void {
  on('tool.call', { tool: REPAIRABLE_TOOL_NAMES }, async ($, e, next) => {
    const first = await next(e)
    if (first.isError !== true || !first.text?.includes(MACRO_PLUGIN_KILLED)) {
      return first
    }
    // A repair that can't run leaves the original failure for Claude, and the classic hook.
    const stdout = await $.process
      .run([`${$.plugin.root}/bin/xcrew`, 'repair-macros'], { timeoutMs: 120_000 })
      .then(output => output.stdout, () => '')
    const repaired = [...stdout.matchAll(/^repaired: (.+)$/gm)].map(match => match[1])
    if (repaired.length === 0) return first

    $.ui.toast(`xcrew repaired ${repaired.join(', ')} and retried ${parseTool(e.tool)?.tool ?? e.tool}`)
    return next(e)
  })
}
