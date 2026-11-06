<script setup lang="ts"></script>

<template>
  <RouterView v-slot="{ Component }">
    <Transition
      mode="out-in"
      enter-active-class="transition duration-300 ease-out"
      enter-from-class="opacity-0 translate-y-2"
      leave-active-class="transition duration-150 ease-in"
      leave-to-class="opacity-0"
    >
      <component :is="Component" />
    </Transition>
  </RouterView>
</template>
