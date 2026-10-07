import { ref, watch, type Ref } from 'vue'

// The parameters pages keep in the address bar, so a deep link's tidy-up leaves them alone.
export const urlStateKeys = new Set<string>()

function write(name: string, value: string | null) {
  const params = new URLSearchParams(location.search)
  if (value === null) params.delete(name)
  else params.set(name, value)
  const query = params.toString()
  history.replaceState(history.state, '', `${location.pathname}${query ? `?${query}` : ''}${location.hash}`)
}

/**
 * A page's filter, kept in the address bar (e.g. ?tab=team), so a reload, a
 * bookmark or a shared link shows the same view. Left out while it's the default.
 */
export function useUrlParam<T extends string>(name: string, fallback: T, allowed?: readonly T[]): Ref<T> {
  urlStateKeys.add(name)
  const given = new URLSearchParams(location.search).get(name) as T | null
  const value = ref((given !== null && (!allowed || allowed.includes(given)) ? given : fallback) as T) as Ref<T>
  watch(value, (v) => write(name, v === fallback ? null : v))
  return value
}

/**
 * A list of choices in the address bar, comma separated (e.g. ?status=Ready,Doing).
 * An empty one is kept as ?status= when the default isn't empty, so "none" survives a reload.
 */
export function useUrlList(name: string, fallback: string[] = []): Ref<string[]> {
  urlStateKeys.add(name)
  const given = new URLSearchParams(location.search).get(name)
  const value = ref(given === null ? fallback : given.split(',').filter(Boolean))
  const same = (a: string[], b: string[]) => a.length === b.length && a.every((v, i) => v === b[i])
  watch(value, (v) => write(name, same(v, fallback) ? null : v.join(',')), { deep: true })
  return value
}
