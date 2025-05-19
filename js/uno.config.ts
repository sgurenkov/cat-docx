import { defineConfig, presetAttributify, presetUno } from 'unocss'

export default defineConfig({
  presets: [
    presetAttributify({ /* preset options */}),
    presetUno(),
  ],
  shortcuts: {
    "btn": "bg-sky-800 text-white font-bold rounded-md border-none cursor-pointer py-2 px-3 hover:bg-sky-600 hover:shadow inline-block font-mono text-md text-center",
  }
})
