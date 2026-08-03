module.exports = {
  parser: '@typescript-eslint/parser',
  extends: [
    'plugin:@typescript-eslint/recommended',
  ],
  parserOptions: {
    ecmaVersion: 2022,
    sourceType: 'module',
  },
  rules: {
    '@typescript-eslint/no-explicit-any': 'off',
    // The codebase marks deliberate discards with a leading underscore. Only
    // argsIgnorePattern was set, which covers function parameters alone — so
    // destructured discards (toSafeUser stripping passwordHash/otp/refreshToken)
    // and caught-but-unused errors were still reported, training people to scroll
    // past warnings. All three positions now honour the same convention.
    '@typescript-eslint/no-unused-vars': [
      'warn',
      {
        argsIgnorePattern: '^_',
        varsIgnorePattern: '^_',
        caughtErrorsIgnorePattern: '^_',
      },
    ],
  },
};
