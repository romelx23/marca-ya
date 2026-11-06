import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import { api, ApiError, configureApi } from '@/lib/api'

export type Role = 'employee' | 'manager' | 'hr' | 'admin'

export interface Employee {
  id: string
  email: string
  fullName: string
  documentId: string | null
  role: Role
  active: boolean
  createdAt: string
}

const TOKEN_KEY = 'marcaya.token'

export const useAuthStore = defineStore('auth', () => {
  const token = ref<string | null>(localStorage.getItem(TOKEN_KEY))
  const employee = ref<Employee | null>(null)

  const isHr = computed(() => employee.value?.role === 'hr' || employee.value?.role === 'admin')

  function clear() {
    token.value = null
    employee.value = null
    localStorage.removeItem(TOKEN_KEY)
  }

  configureApi({ getToken: () => token.value, onUnauthorized: clear })

  async function login(email: string, password: string) {
    const res = await api<{ accessToken: string; employee: Employee }>('/auth/login', {
      method: 'POST',
      body: { email: email.trim(), password },
    })
    token.value = res.accessToken
    employee.value = res.employee
    localStorage.setItem(TOKEN_KEY, res.accessToken)
  }

  /** Recupera al empleado de un token guardado; sin red conserva el token. */
  async function restore() {
    if (!token.value || employee.value) return
    try {
      employee.value = await api<Employee>('/auth/me')
    } catch (e) {
      if (!(e instanceof ApiError) || e.status === 401) clear()
    }
  }

  return { token, employee, isHr, login, restore, logout: clear }
})
