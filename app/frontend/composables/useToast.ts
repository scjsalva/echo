import { ref } from 'vue'

const message = ref<string | null>(null)
let timer: ReturnType<typeof setTimeout> | undefined

export function useToast() {
  function show(text: string) {
    message.value = text
    clearTimeout(timer)
    timer = setTimeout(() => (message.value = null), 2400)
  }
  return { message, show }
}
