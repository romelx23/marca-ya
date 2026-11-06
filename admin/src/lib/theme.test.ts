import { beforeEach, describe, expect, it } from 'vitest'
import { initialTheme, theme, toggleTheme } from './theme'

describe('theme', () => {
  beforeEach(() => {
    localStorage.clear()
    document.documentElement.classList.add('dark')
    theme.value = 'dark'
  })

  it('sin preferencia guardada usa oscuro', () => {
    expect(initialTheme()).toBe('dark')
  })

  it('respeta lo guardado', () => {
    localStorage.setItem('marcaya.theme', 'light')
    expect(initialTheme()).toBe('light')
  })

  it('toggleTheme alterna, guarda y cambia la clase del documento', () => {
    toggleTheme()
    expect(theme.value).toBe('light')
    expect(localStorage.getItem('marcaya.theme')).toBe('light')
    expect(document.documentElement.classList.contains('dark')).toBe(false)

    toggleTheme()
    expect(theme.value).toBe('dark')
    expect(document.documentElement.classList.contains('dark')).toBe(true)
  })
})
