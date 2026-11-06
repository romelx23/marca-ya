import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

export const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/login', name: 'login', component: () => import('@/views/LoginView.vue') },
    {
      path: '/',
      component: () => import('@/layouts/AppLayout.vue'),
      meta: { requiresAuth: true },
      children: [
        { path: '', redirect: { name: 'employees' } },
        { path: 'employees', name: 'employees', component: () => import('@/views/EmployeesView.vue') },
        { path: 'attendance', name: 'attendance', component: () => import('@/views/AttendanceView.vue') },
      ],
    },
    { path: '/:pathMatch(.*)*', redirect: '/' },
  ],
})

router.beforeEach(async (to) => {
  const auth = useAuthStore()
  await auth.restore()
  if (to.meta.requiresAuth && !auth.employee) return { name: 'login' }
  // Este panel es solo para RRHH y administradores.
  if (to.meta.requiresAuth && !auth.isHr) {
    auth.logout()
    return { name: 'login', query: { denied: '1' } }
  }
  if (to.name === 'login' && auth.employee && auth.isHr) return { name: 'employees' }
})
