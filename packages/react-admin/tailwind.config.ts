import type { Config } from 'tailwindcss'

const config: Config = {
  darkMode: 'class',
  content: ['./app/**/*.{ts,tsx}', './components/**/*.{ts,tsx}', './lib/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        background: '#121212',
        foreground: '#FFFFFF',
        primary: {
          DEFAULT: '#7C3AED',
          light: '#A855F7',
          foreground: '#FFFFFF',
        },
        accent: '#FF3D8E',
        secondary: '#1B9CFC',
        verification: '#F1C40F',
        success: '#10B981',
        warning: '#F59E0B',
        destructive: {
          DEFAULT: '#EF4444',
          foreground: '#FFFFFF',
        },
        muted: {
          DEFAULT: '#1E1E1E',
          foreground: '#A1A1AA',
        },
        border: '#2A2A2A',
        card: '#1A1A1A',
      },
      fontFamily: {
        sans: ['Inter', 'sans-serif'],
      },
    },
  },
  plugins: [require('tailwindcss-animate')],
}
export default config
