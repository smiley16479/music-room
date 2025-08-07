/** @type {import('tailwindcss').Config} */
export default {
    content: [
        "./src/**/*.{html,js,svelte,ts}",
    ],
    theme: {
        extend: {
            colors: {
                primary: {
                    DEFAULT: '#33ea42ff', // purple-600
                    dark: '#7e22ce',    // purple-700
                },
                secondary: {
                    DEFAULT: '#6366f1', // indigo-500
                    dark: '#4f46e5',    // indigo-600
                }
            } 
        },
    },
    plugins: [],
}