<script setup lang="ts">
import { MapPin, RefreshCw } from 'lucide-vue-next'
import { computed, onMounted, ref, watch } from 'vue'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { api, ApiError } from '@/lib/api'
import { formatDuration, formatTime, initials, limaDate, mapUrl, summarize, type AttendanceEvent } from '@/lib/attendance'

const date = ref(limaDate())
const events = ref<AttendanceEvent[]>([])
const loading = ref(true)
const error = ref('')
const now = ref(new Date())

const rows = computed(() => summarize(events.value, now.value))
const present = computed(() => rows.value.length)
const inside = computed(() => rows.value.filter((r) => r.open).length)

async function load() {
  loading.value = true
  error.value = ''
  try {
    events.value = await api<AttendanceEvent[]>(`/attendance?from=${date.value}&to=${date.value}`)
    now.value = new Date()
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Error inesperado'
  } finally {
    loading.value = false
  }
}

watch(date, (d) => {
  if (d) load()
})
onMounted(load)
</script>

<template>
  <div class="mx-auto max-w-5xl space-y-6">
    <div class="flex flex-wrap items-end justify-between gap-4">
      <div>
        <h2 class="text-2xl font-bold tracking-tight">Asistencia</h2>
        <p class="text-sm text-muted-foreground">
          {{ present }} con marcación · {{ inside }} dentro ahora
        </p>
      </div>
      <div class="flex items-end gap-2">
        <div class="space-y-2">
          <Label for="date">Día</Label>
          <Input id="date" v-model="date" type="date" :max="limaDate()" />
        </div>
        <Button variant="outline" size="icon" aria-label="Actualizar" :disabled="loading" @click="load">
          <RefreshCw :class="{ 'animate-spin': loading }" />
        </Button>
      </div>
    </div>

    <p v-if="error" role="alert" class="text-sm text-destructive">{{ error }}</p>

    <Card>
      <CardContent class="p-0">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Empleado</TableHead>
              <TableHead>Entrada</TableHead>
              <TableHead>Salida</TableHead>
              <TableHead>Horas</TableHead>
              <TableHead>Estado</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            <TableRow v-if="loading">
              <TableCell colspan="5" class="py-8 text-center text-muted-foreground">Cargando…</TableCell>
            </TableRow>
            <TableRow v-else-if="!rows.length && !error">
              <TableCell colspan="5" class="py-8 text-center text-muted-foreground">
                Sin marcaciones este día
              </TableCell>
            </TableRow>
            <TableRow
              v-for="(r, i) in rows"
              :key="r.employeeId"
              v-motion
              :initial="{ opacity: 0, x: -12 }"
              :enter="{ opacity: 1, x: 0, transition: { delay: Math.min(i, 10) * 40 } }"
            >
              <TableCell class="font-medium">
                <span class="flex items-center gap-3">
                  <span class="avatar-chip flex size-8 items-center justify-center rounded-full text-xs font-bold text-background">
                    {{ initials(r.name) }}
                  </span>
                  {{ r.name }}
                </span>
              </TableCell>
              <TableCell>
                {{ r.firstIn ? formatTime(r.firstIn) : '—' }}
                <a
                  v-if="mapUrl(r.firstInEvent)"
                  :href="mapUrl(r.firstInEvent)!"
                  target="_blank"
                  rel="noopener"
                  class="ml-1 inline-flex align-middle text-muted-foreground hover:text-foreground"
                  title="Ver ubicación de la entrada"
                >
                  <MapPin class="size-3.5" />
                </a>
              </TableCell>
              <TableCell>{{ r.lastOut ? formatTime(r.lastOut) : '—' }}</TableCell>
              <TableCell>{{ formatDuration(r.workedSeconds) }}</TableCell>
              <TableCell>
                <Badge :variant="r.open ? 'default' : 'secondary'">{{ r.open ? 'Dentro' : 'Salió' }}</Badge>
              </TableCell>
            </TableRow>
          </TableBody>
        </Table>
      </CardContent>
    </Card>
  </div>
</template>
