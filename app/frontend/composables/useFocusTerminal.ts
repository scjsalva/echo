import { request } from '@/lib/api'
import { useToast } from './useToast'

/** Brings the Terminal or iTerm2 tab a session runs in to the front. */
export function useFocusTerminal() {
  const toast = useToast()

  return async function focusTerminal(agentId: string) {
    try {
      await request('POST', `/api/agents/${agentId}/focus`)
    } catch (error) {
      toast.show(error instanceof Error ? error.message : "Couldn't bring the terminal forward")
    }
  }
}
