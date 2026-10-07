import { afterEach } from 'vitest'

// Pages keep their filters in the address bar, so each test starts from a clean one.
afterEach(() => history.replaceState(null, '', '/'))
