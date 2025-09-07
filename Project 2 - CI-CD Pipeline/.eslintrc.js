// .eslintrc.js — ESLint configuration file for Node.js project to  define rules, environments, and parser settings that ESLint uses to analyze your code for errors, enforce coding standards, and improve consistency across your project

module.exports = {
  // Define environments to enable global variables
  env: {
    node: true,        // Enables Node.js globals (e.g., process, __dirname)
    commonjs: true,    // Enables CommonJS globals (e.g., require, module.exports)
    es2021: true,      // Enables ES2021 syntax
    jest: true,        // Enables Jest testing globals (e.g., describe, test)
  },

  // Extend Airbnb's base style guide (no React rules)
  extends: 'airbnb-base',

  // Override settings for specific files
  overrides: [
    {
      files: ['.eslintrc.{js,cjs}'], // Target ESLint config files
      env: {
        node: true,
      },
      parserOptions: {
        sourceType: 'script', // Treat as script (not module)
      },
    },
  ],

  // Parser options for modern JavaScript
  parserOptions: {
    ecmaVersion: 'latest', // Use latest ECMAScript version
  },

  // Custom rule adjustments
  rules: {
    'no-console': 'off', // Allow console.log (useful for debugging)
    'import/extensions': ['error', 'ignorePackages'], // Enforce file extensions for imports
  },
};
