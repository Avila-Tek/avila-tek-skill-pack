---
name: dependency-upgrade
description: Automatically upgrades dependencies of any project that belongs to the JavaScript/Node.js ecosystem and has a package.json. Use when the user asks to upgrade the dependencies of a specific project.
---
When upgrading a project's dependencies:

1. Look up and list every `package.json` file you can find in the repository (showing the directory each of them belong to)
2. Run `ncu -u` for each `package.json` found
    2.1. Show the user a list of the dependencies found in the file
    2.2. Check if all the dependencies are anchored. All of them MUST be anchored
      2.2.1. If a dependency is not anchored, do it
    2.3. Ask the user if they want to skip any dependencies
    2.4. Ask the user if they want to use any specific version of a package
    2.5. Ask the user if they want to upgrade the dependencies listed as "overrides". If not, don't upgrade those
3. Remove `node_modules` and `package-lock.json`
4. Run `npm i` in the root directory
5. Run `npm audit` in the root directory to check if there’s any warnings
    5.1. If it throws a critical warning, find a solution to it and ask the user if they want to implement it
6. Run `npm run build` in the root directory to check if all apps and packages work properly
7. Show the user a summary of what you did

You must let the user know what you're doing on each step listed above.

If you find any error or warning, or you just want to let the user know something important, show it with this format:

### ❌ ERROR: Error message here

### ⚠️ WARNING: Warning message here

### ℹ️ INFO: Informative message here