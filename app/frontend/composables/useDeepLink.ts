import { onMounted } from 'vue'
import { urlStateKeys } from './useUrlState'

/**
 * Opens whatever a link points at (e.g. /agents?agent=… from a notification),
 * then tidies the address bar so a reload doesn't open it again. A page's
 * filters stay (see useUrlState).
 */
export function useDeepLink(handle: (params: URLSearchParams) => void) {
  onMounted(() => {
    const params = new URLSearchParams(location.search)
    if (![...params.keys()].length) return

    handle(params)
    const kept = new URLSearchParams([...params].filter(([key]) => urlStateKeys.has(key)))
    const query = kept.toString()
    history.replaceState(null, '', `${location.pathname}${query ? `?${query}` : ''}${location.hash}`)
  })
}
