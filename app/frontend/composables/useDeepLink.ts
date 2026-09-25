import { onMounted } from 'vue'

/**
 * Opens whatever a link points at (e.g. /agents?agent=… from a notification),
 * then tidies the address bar so a reload doesn't open it again.
 */
export function useDeepLink(handle: (params: URLSearchParams) => void) {
  onMounted(() => {
    const params = new URLSearchParams(location.search)
    if (![...params.keys()].length) return

    handle(params)
    history.replaceState(null, '', location.pathname)
  })
}
