import type { Config } from 'tailwindcss';

const config: Config = {
  darkMode: ['class'],
  content: [
    './app/**/*.{ts,tsx}',
    './components/**/*.{ts,tsx}',
    './lib/**/*.{ts,tsx}',
    './hooks/**/*.{ts,tsx}',
    './providers/**/*.{ts,tsx}',
  ],
  theme: {
    extend: {
      colors: {
        background: '#121212',
        foreground: '#FFFFFF',
        border: '#2A2A2A',
        card: '#1A1A1A',
        muted: {
          DEFAULT: '#1E1E1E',
          foreground: '#A1A1AA',
        },
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
      },
      fontFamily: {
        sans: ['Inter', 'sans-serif'],
      },
      boxShadow: {
        soft: '0 10px 30px rgba(0, 0, 0, 0.25)',
      },
    },
  },
  plugins: [require('tailwindcss-animate')],
};

export default config;
