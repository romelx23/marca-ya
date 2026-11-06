import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { ApiError } from '@/lib/api'
import { useAuthStore } from './auth'

const ana = { id: '1', email: 'ana@test.local', fullName: 'Ana Ruiz', documentId: null, role: 'hr', active: true, createdAt: '' }

function mockFetch(status: number, body: unknown) {
  const fn = vi.fn().mockResolvedValue({ ok: status < 400, status, json: async () => body })
  vi.stubGlobal('fetch', fn)
  return fn
}

describe('auth store', () => {
  beforeEach(() => {
    localStorage.clear()
    setActivePinia(createPinia())
  })

  it('login guarda el token y el empleado', async () => {
    mockFetch(200, { accessToken: 'tok', employee: ana })
    const auth = useAuthStore()
    await auth.login(' ana@test.local ', 'clave')
    expect(auth.token).toBe('tok')
    expect(auth.isHr).toBe(true)
    expect(localStorage.getItem('marcaya.token')).toBe('tok')
  })

  it('login fallido lanza ApiError y no guarda nada', async () => {
    mockFetch(401, { message: 'Credenciales inválidas' })
    const auth = useAuthStore()
    await expect(auth.login('a@b.c', 'mala')).rejects.toMatchObject({ status: 401, message: 'Credenciales inválidas' })
    expect(auth.token).toBeNull()
  })

  it('restore con token rechazado cierra la sesión', async () => {
    localStorage.setItem('marcaya.token', 'viejo')
    mockFetch(401, { message: 'Unauthorized' })
    setActivePinia(createPinia())
    const auth = useAuthStore()
    await auth.restore()
    expect(auth.token).toBeNull()
    expect(localStorage.getItem('marcaya.token')).toBeNull()
  })

  it('restore sin red conserva el token', async () => {
    localStorage.setItem('marcaya.token', 'vigente')
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new TypeError('network')))
    setActivePinia(createPinia())
    const auth = useAuthStore()
    await auth.restore()
    expect(auth.token).toBe('vigente')
    expect(ApiError).toBeDefined()
  })
})
