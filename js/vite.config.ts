import { defineConfig } from "vite";
import UnoCSS from "unocss/vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  publicDir: "./public/",
  base: "",
  plugins: [UnoCSS(), react()],
  server: {
    port: 3000,
  },
  build: {
    target: "esnext",
    outDir: "../docs",
  },
});
