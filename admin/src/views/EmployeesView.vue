<script setup lang="ts">
import { Plus } from 'lucide-vue-next'
import { onMounted, ref } from 'vue'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { api, ApiError } from '@/lib/api'
import { initials } from '@/lib/attendance'
import type { Employee, Role } from '@/stores/auth'

const ROLE_LABEL: Record<Role, string> = {
  employee: 'Empleado',
  manager: 'Jefe',
  hr: 'RRHH',
  admin: 'Admin',
}

const employees = ref<Employee[]>([])
const loading = ref(true)
const loadError = ref('')

const showForm = ref(false)
const saving = ref(false)
const formError = ref('')
const form = ref({ fullName: '', email: '', password: '', documentId: '', role: 'employee' as Role })

async function load() {
  loading.value = true
  loadError.value = ''
  try {
    employees.value = await api<Employee[]>('/employees')
  } catch (e) {
    loadError.value = e instanceof ApiError ? e.message : 'Error inesperado'
  } finally {
    loading.value = false
  }
}

async function create() {
  saving.value = true
  formError.value = ''
  try {
    const { documentId, ...rest } = form.value
    const created = await api<Employee>('/employees', {
      method: 'POST',
      body: { ...rest, ...(documentId.trim() ? { documentId: documentId.trim() } : {}) },
    })
    employees.value = [...employees.value, created].sort((a, b) => a.fullName.localeCompare(b.fullName))
    form.value = { fullName: '', email: '', password: '', documentId: '', role: 'employee' }
    showForm.value = false
  } catch (e) {
    formError.value = e instanceof ApiError ? e.message : 'Error inesperado'
  } finally {
    saving.value = false
  }
}

async function toggleActive(e: Employee) {
  try {
    const updated = await api<Employee>(`/employees/${e.id}`, { method: 'PATCH', body: { active: !e.active } })
    Object.assign(e, updated)
  } catch (err) {
    loadError.value = err instanceof ApiError ? err.message : 'Error inesperado'
  }
}

onMounted(load)
</script>

<template>
  <div class="mx-auto max-w-5xl space-y-6">
    <div class="flex items-center justify-between">
      <div>
        <h2 class="text-2xl font-bold tracking-tight">Empleados</h2>
        <p class="text-sm text-muted-foreground">{{ employees.length }} registrados</p>
      </div>
      <Button @click="showForm = !showForm"><Plus /> Nuevo empleado</Button>
    </div>

    <Card v-if="showForm" v-motion :initial="{ opacity: 0, y: -12 }" :enter="{ opacity: 1, y: 0 }">
      <CardHeader><CardTitle>Nuevo empleado</CardTitle></CardHeader>
      <CardContent>
        <form class="grid gap-4 sm:grid-cols-2" @submit.prevent="create">
          <div class="space-y-2">
            <Label for="fullName">Nombre completo</Label>
            <Input id="fullName" v-model="form.fullName" required minlength="2" />
          </div>
          <div class="space-y-2">
            <Label for="documentId">DNI (opcional)</Label>
            <Input id="documentId" v-model="form.documentId" />
          </div>
          <div class="space-y-2">
            <Label for="newEmail">Correo</Label>
            <Input id="newEmail" v-model="form.email" type="email" required />
          </div>
          <div class="space-y-2">
            <Label for="newPassword">Clave inicial (mín. 8)</Label>
            <Input id="newPassword" v-model="form.password" type="password" required minlength="8" autocomplete="new-password" />
          </div>
          <div class="space-y-2">
            <Label for="role">Rol</Label>
            <select
              id="role"
              v-model="form.role"
              class="h-9 w-full rounded-md border border-input bg-transparent px-3 text-sm"
            >
              <option v-for="(label, value) in ROLE_LABEL" :key="value" :value="value" class="bg-card">{{ label }}</option>
            </select>
          </div>
          <div class="flex items-end justify-end gap-2 sm:col-span-2">
            <p v-if="formError" role="alert" class="mr-auto text-sm text-destructive">{{ formError }}</p>
            <Button type="button" variant="ghost" @click="showForm = false">Cancelar</Button>
            <Button type="submit" :disabled="saving">Crear</Button>
          </div>
        </form>
      </CardContent>
    </Card>

    <p v-if="loadError" role="alert" class="text-sm text-destructive">{{ loadError }}</p>

    <Card>
      <CardContent class="p-0">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Nombre</TableHead>
              <TableHead>Correo</TableHead>
              <TableHead>Rol</TableHead>
              <TableHead>Estado</TableHead>
              <TableHead class="text-right">Acciones</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            <TableRow v-if="loading">
              <TableCell colspan="5" class="py-8 text-center text-muted-foreground">Cargando…</TableCell>
            </TableRow>
            <TableRow
              v-for="(e, i) in employees"
              :key="e.id"
              v-motion
              :initial="{ opacity: 0, x: -12 }"
              :enter="{ opacity: 1, x: 0, transition: { delay: Math.min(i, 10) * 40 } }"
            >
              <TableCell class="font-medium">
                <span class="flex items-center gap-3">
                  <span class="avatar-chip flex size-8 items-center justify-center rounded-full text-xs font-bold text-background">
                    {{ initials(e.fullName) }}
                  </span>
                  {{ e.fullName }}
                </span>
              </TableCell>
              <TableCell class="text-muted-foreground">{{ e.email }}</TableCell>
              <TableCell><Badge variant="secondary">{{ ROLE_LABEL[e.role] }}</Badge></TableCell>
              <TableCell>
                <Badge :variant="e.active ? 'default' : 'outline'">{{ e.active ? 'Activo' : 'Inactivo' }}</Badge>
              </TableCell>
              <TableCell class="text-right">
                <Button variant="ghost" size="sm" @click="toggleActive(e)">
                  {{ e.active ? 'Desactivar' : 'Activar' }}
                </Button>
              </TableCell>
            </TableRow>
          </TableBody>
        </Table>
      </CardContent>
    </Card>
  </div>
</template>
