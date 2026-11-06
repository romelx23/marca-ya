import { ref } from 'vue'

export type Theme = 'dark' | 'light'

const KEY = 'marcaya.theme'

/** Lo guardado; si no hay nada, el tema del sistema; y si no se puede saber, oscuro (el principal del diseño). */
export function initialTheme(): Theme {
  const saved = localStorage.getItem(KEY)
  if (saved === 'dark' || saved === 'light') return saved
  const prefersLight = typeof matchMedia === 'function' && matchMedia('(prefers-color-scheme: light)').matches
  return prefersLight ? 'light' : 'dark'
}

export const theme = ref<Theme>(initialTheme())

function apply(t: Theme) {
  document.documentElement.classList.toggle('dark', t === 'dark')
}

export function initTheme() {
  apply(theme.value)
}

export function toggleTheme() {
  theme.value = theme.value === 'dark' ? 'light' : 'dark'
  localStorage.setItem(KEY, theme.value)
  apply(theme.value)
}
