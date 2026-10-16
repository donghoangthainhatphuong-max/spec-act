import js from '@eslint/js';
import pluginVue from 'eslint-plugin-vue';
import globals from 'globals';

export default [
  { ignores: ['dist', 'node_modules', 'public', 'coverage', 'flutter', '.ua'] },
  js.configs.recommended,
  ...pluginVue.configs['flat/essential'],
  {
    languageOptions: { ecmaVersion: 2023, sourceType: 'module', globals: { ...globals.browser, ...globals.node } },
    rules: {
      'no-unused-vars': ['warn', { argsIgnorePattern: '^_', varsIgnorePattern: '^_', caughtErrors: 'none' }],
      'vue/multi-word-component-names': 'off',
      'no-empty': ['warn', { allowEmptyCatch: true }],
    },
  },
  { files: ['tests/**'], languageOptions: { globals: { ...globals.vitest } } },
];
