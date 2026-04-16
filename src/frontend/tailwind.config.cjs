/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{html,js,svelte,ts}'],
  theme: {
    extend: {
      colors: {
        finance: {
          50: '#f8fafc',
          100: '#f1f5f9',
          200: '#e2e8f0',
          600: '#0284c7',
          700: '#0369a1',
          800: '#0f172a',
          900: '#020617'
        }
      },
      fontFamily: {
        sans: ['Inter', 'ui-sans-serif', 'system-ui', 'sans-serif']
      },
      boxShadow: {
        finance: '0 10px 30px -12px rgba(2, 6, 23, 0.45)'
      }
    },
  },
  plugins: [],
}
