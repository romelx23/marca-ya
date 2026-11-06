<script setup lang="ts">
import { CalendarCheck, Fingerprint, LogOut, Users } from 'lucide-vue-next'
import { useRouter } from 'vue-router'
import ThemeToggle from '@/components/ThemeToggle.vue'
import { Button } from '@/components/ui/button'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()
const router = useRouter()

async function logout() {
  auth.logout()
  await router.replace({ name: 'login' })
}
</script>

<template>
  <div class="flex min-h-screen">
    <aside class="hidden w-60 flex-col border-r border-sidebar-border bg-sidebar p-4 md:flex">
      <div class="mb-8 flex items-center gap-2 px-2">
        <div class="brand-mark flex size-8 items-center justify-center rounded-lg">
          <Fingerprint class="size-5 text-background" />
        </div>
        <span class="text-lg font-bold">MarcaYa</span>
      </div>
      <nav class="space-y-1">
        <RouterLink
          :to="{ name: 'employees' }"
          class="flex items-center gap-2 rounded-lg px-3 py-2 text-sm text-sidebar-foreground transition-colors hover:bg-sidebar-accent"
          active-class="nav-active font-medium"
        >
          <Users class="size-4" /> Empleados
        </RouterLink>
        <RouterLink
          :to="{ name: 'attendance' }"
          class="flex items-center gap-2 rounded-lg px-3 py-2 text-sm text-sidebar-foreground transition-colors hover:bg-sidebar-accent"
          active-class="nav-active font-medium"
        >
          <CalendarCheck class="size-4" /> Asistencia
        </RouterLink>
      </nav>
    </aside>

    <div class="flex min-w-0 flex-1 flex-col">
      <header class="flex items-center justify-between border-b border-border px-6 py-3">
        <div class="text-sm text-muted-foreground">
          Hola, <span class="font-medium text-foreground">{{ auth.employee?.fullName }}</span>
        </div>
        <div class="flex items-center gap-1">
          <ThemeToggle />
          <Button variant="ghost" size="sm" @click="logout"><LogOut /> Salir</Button>
        </div>
      </header>
      <main class="flex-1 p-6">
        <RouterView />
      </main>
    </div>
  </div>
</template>
