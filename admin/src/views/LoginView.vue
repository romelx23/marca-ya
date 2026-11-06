<script setup lang="ts">
import { Fingerprint, Loader2 } from 'lucide-vue-next'
import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import ThemeToggle from '@/components/ThemeToggle.vue'
import { Button } from '@/components/ui/button'
import { Card, CardContent } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { ApiError } from '@/lib/api'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()
const router = useRouter()
const route = useRoute()

const email = ref('')
const password = ref('')
const loading = ref(false)
const error = ref(route.query.denied ? 'Esta cuenta no tiene acceso al panel de RRHH' : '')
const shaking = ref(false)

function fail(message: string) {
  error.value = message
  shaking.value = false
  // Reinicia la animación aunque el error se repita.
  requestAnimationFrame(() => (shaking.value = true))
}

async function submit() {
  if (loading.value) return
  if (!email.value.trim() || !password.value) return fail('Ingresa tu correo y clave')
  loading.value = true
  error.value = ''
  try {
    await auth.login(email.value, password.value)
    if (!auth.isHr) {
      auth.logout()
      return fail('Esta cuenta no tiene acceso al panel de RRHH')
    }
    await router.replace({ name: 'employees' })
  } catch (e) {
    fail(e instanceof ApiError ? e.message : 'Error inesperado')
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <main class="relative flex min-h-screen items-center justify-center p-6">
    <div class="absolute right-4 top-4"><ThemeToggle /></div>
    <div class="w-full max-w-sm space-y-8">
      <div class="space-y-3 text-center">
        <div
          v-motion
          :initial="{ scale: 0, rotate: -20, opacity: 0 }"
          :enter="{ scale: 1, rotate: 0, opacity: 1, transition: { type: 'spring', stiffness: 260, damping: 14 } }"
          class="brand-mark mx-auto flex size-16 items-center justify-center rounded-2xl"
        >
          <Fingerprint class="size-9 text-background" />
        </div>
        <h1
          v-motion
          :initial="{ opacity: 0, y: 16 }"
          :enter="{ opacity: 1, y: 0, transition: { delay: 150 } }"
          class="text-3xl font-bold tracking-tight"
        >
          MarcaYa
        </h1>
        <p
          v-motion
          :initial="{ opacity: 0 }"
          :enter="{ opacity: 1, transition: { delay: 250 } }"
          class="text-sm text-muted-foreground"
        >
          Panel de Recursos Humanos
        </p>
      </div>

      <Card
        v-motion
        :initial="{ opacity: 0, y: 24 }"
        :enter="{ opacity: 1, y: 0, transition: { delay: 350 } }"
        :class="{ 'animate-shake': shaking }"
        @animationend="shaking = false"
      >
        <CardContent>
          <form class="space-y-4" @submit.prevent="submit">
            <div class="space-y-2">
              <Label for="email">Correo</Label>
              <Input id="email" v-model="email" type="email" autocomplete="username" />
            </div>
            <div class="space-y-2">
              <Label for="password">Clave</Label>
              <Input id="password" v-model="password" type="password" autocomplete="current-password" />
            </div>
            <p v-if="error" role="alert" class="text-sm text-destructive">{{ error }}</p>
            <Button type="submit" class="w-full" :disabled="loading">
              <Loader2 v-if="loading" class="animate-spin" />
              <span v-else>Ingresar</span>
            </Button>
          </form>
        </CardContent>
      </Card>
    </div>
  </main>
</template>
