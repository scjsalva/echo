/** When you're back, e.g. "Tue 25 Nov, 16:00". */
export const backAt = (iso: string) =>
  new Date(iso).toLocaleString('en-GB', { weekday: 'short', day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }).replace(',', '')
