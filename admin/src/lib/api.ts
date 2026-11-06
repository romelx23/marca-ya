export const API_URL: string = import.meta.env.VITE_API_URL ?? 'http://localhost:3000'

export class ApiError extends Error {
  status: number

  constructor(status: number, message: string) {
    super(message)
    this.status = status
  }
}

let tokenProvider: () => string | null = () => null
let onUnauthorized: () => void = () => {}

/** El store de auth registra aquí cómo leer el token y qué hacer ante un 401. */
export function configureApi(opts: { getToken: () => string | null; onUnauthorized: () => void }) {
  tokenProvider = opts.getToken
  onUnauthorized = opts.onUnauthorized
}

export async function api<T>(path: string, init: { method?: string; body?: unknown } = {}): Promise<T> {
  const token = tokenProvider()
  let res: Response
  try {
    res = await fetch(`${API_URL}${path}`, {
      method: init.method ?? 'GET',
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: init.body === undefined ? undefined : JSON.stringify(init.body),
    })
  } catch {
    throw new ApiError(0, 'No se pudo conectar con el servidor')
  }

  const data = res.status === 204 ? null : await res.json().catch(() => null)
  if (res.ok) return data as T

  // Un 401 con sesión abierta significa token vencido; el 401 del login es "credenciales inválidas".
  if (res.status === 401 && token) onUnauthorized()
  const m = data?.message
  throw new ApiError(res.status, Array.isArray(m) ? m.join('\n') : (m ?? `Error ${res.status}`))
}
