<script setup lang="ts">
import { Moon, Sun } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { theme, toggleTheme } from '@/lib/theme'
</script>

<template>
  <Button variant="ghost" size="icon" aria-label="Cambiar tema" title="Cambiar tema" @click="toggleTheme">
    <Sun v-if="theme === 'dark'" />
    <Moon v-else />
  </Button>
</template>
