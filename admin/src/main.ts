import { MotionPlugin } from '@vueuse/motion'
import { createPinia } from 'pinia'
import { createApp } from 'vue'
import './style.css'
import App from './App.vue'
import { initTheme } from './lib/theme'
import { router } from './router'

initTheme()
createApp(App).use(createPinia()).use(MotionPlugin).use(router).mount('#app')
