module.exports = {
  root: true,
  ignorePatterns: [".eslintrc.cjs", "scripts/**/*.ts"],
  env: {
    node: true,
    es2021: true,
    jest: true,
  },
  parser: "@typescript-eslint/parser",
  parserOptions: {
    project: ["./tsconfig.json"],
    tsconfigRootDir: __dirname,
  },
  plugins: ["@typescript-eslint", "import"],
  extends: [
    "eslint:recommended",
    "plugin:@typescript-eslint/recommended",
    "plugin:import/recommended",
    "plugin:import/typescript",
    "prettier",
  ],
  rules: {
    "import/order": [
      "error",
      {
        "newlines-between": "always",
        "alphabetize": { "order": "asc", "caseInsensitive": true },
        "groups": [["builtin", "external"], ["internal"], ["parent", "sibling", "index"]],
      },
    ],
    "@typescript-eslint/no-misused-promises": [
      "error",
      {
        "checksVoidReturn": false,
      },
    ],
    "@typescript-eslint/no-unused-vars": [
      "error",
      {
        "argsIgnorePattern": "^_",
        "varsIgnorePattern": "^_",
      },
    ],
    "import/no-named-as-default-member": "off",
    "import/no-named-as-default": "off",
  },
  settings: {
    "import/resolver": {
      typescript: {
        project: "./tsconfig.json",
      },
      node: {
        extensions: [".js", ".ts"],
      },
    },
  },
};

