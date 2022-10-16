---
sidebar_position: 1
---

# What is Nevermore?

Nevermore is a ModuleScript loader for Roblox, and loads modules by name. Nevermore is designed to make code more portable. Nevermore comes with a variety of utility libraries. These libraries are used on both the client and server and are useful for a variety of things. These libraries are separated into packages that can be consumed individually using npm.

Nevermore follows both functional and OOP programming paradigms. However, many modules return classes, and may require more advance Lua knowledge to use.

# Getting Started with Nevermore

Getting started with Nevermore is not easy. 

## Installing Nevermore

1. Install [aftman](https://github.com/LPGhatguy/aftman)
2. Install [npm](https://nodejs.org/en/download/)

## Install using npm
Nevermore is designed to use [npm](https://www.npmjs.com/) to manage packages. You can install a package like this.

```
npm install @quenty/maid
```

Each package is designed to be synced into Roblox using [rojo](https://rojo.space/).

:::warning
Right now you need a special version of Rojo to sync in the npm dependencies properly!
:::

## Custom version of rojo. Why?

We have a custom version of rojo to support syncing in symlinks for development, mesh parts. As for today, you should not need this version of rojo
unless you are trying to sync in symlinked versions of this repo.

## Sample project

See `games/integration` for a sample setup project.