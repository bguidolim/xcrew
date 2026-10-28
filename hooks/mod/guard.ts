import type { On } from 'claude-code'
import { PROJECT_REWRITER_NAMES } from './tools'

const REASON =
  'xcrew: XcodeWrite re-saves the whole Xcode project file, rewriting far more than the file you meant. ' +
  'Create the file with the Write tool instead; projects with synchronized folders or generated projects pick it up.'

/** Refuses the Xcode MCP's file writer, whichever server registration it comes from. */
export function registerGuard(on: On): void {
  on('tool.call', { tool: PROJECT_REWRITER_NAMES }, () => ({ deny: REASON }))
}
