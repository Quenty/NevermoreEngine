---
title: Install
sidebar_position: 2
---

import TOCInline from '@theme/TOCInline';

# Installing Nevermore
Installing Nevermore is easy. Once you have Nevermore set up for your project, it's easy to install new packages that are compatible with Nevermore. Generally installing Nevermore can be daunting since it involves a few new pieces of technology. However, this technology is here for a reason, and in general, this installation can be streamlined.

Nevermore should be installable within 2-3 minutes if you follow this guide.

## Available installation methods
<TOCInline
  toc={toc.filter((node) => node.level <= 3)}
/>


## Fast track: Installing via NPM and the Nevermore CLI
If you want to just try out Nevermore, making a new templated game can be the easiest way to do this. For this reason, there is now a Nevermore CLI that can be used. A CLI stands for command line interface. 

* Install [Node.js](https://nodejs.org/en/download/) v14+ on your computer.
* Install [rojo](https://rojo.space/docs/v7/getting-started/installation/) v7+ on your computer.

We can then use the npm command line to generate a working directory. 

1. Open a terminal, like Command Prompt, Powershell, or [Windows Terminal](https://www.microsoft.com/en-us/p/windows-terminal/9n0dx20hk701) (recommended). 
2. Change directory to the location you would like to initialize and create files. You can do this by typing `mkdir MyGame` and then `cd MyGame`. You can use `dir` or `ls` to list out the current directory.
2. Run the command `npx nevermore init` to generate a new game. 
3. Run the command `npm install @quenty/maid` or whatever package you want.

:::tip
You can globally install the nevermore CLI by running the following command in the terminal.
```bash
npm install -g @quenty/nevermore-cli
```
:::

This will install the current version of Maid and all dependencies into the `node_modules` folder. To upgrade you will want to run `npm upgrade` You should ignore the `node_modules` folder in your source control system.

### What is NPM and why are we using it?
[npm](https://www.npmjs.com/) is a package manager. Nevermore uses npm to manage package versions and install transient dependencies. A transient dependency is a dependency of a dependency (for example, [Blend](/api/Blend) depends upon [Maid](/api/Maid).

### How do I install additional packages?
The default installation comes with very few packages. This is normal. You can see which packages are installed by looking at the `package.json` file in a text editor. To install additional packages, simply run the following command in a terminal

```bash
npm install @quenty/servicebag
```

This will install the packages into the `node_modules` folder.

### What is package-lock.json?
When you run `npm install` you end up with a `package-lock.json`. You should commit this to source control. See [NPM's documentation](https://docs.npmjs.com/cli/v6/configuring-npm/package-locks) for details.

## Installing via NPM into an existing game via Rojo

Nevermore is designed to work with games with existing architecture. If you're using Knit, a multi-script architecture, a custom framework or a single-script architecture, Nevermore provides a lot of utility modules that are useful in any of these scenarios. Nevermore's latest version also supports multiple copies of Nevermore running at once as long as bootstrapping is carefully managed. This can allow you to develop your game in an isolated way, or introduce Nevermore dependencies slowly as you need them.

 If you want to install this into an existing game follow these instructions.

Ensure that you have [Node.js](https://nodejs.org/en/download/) v14+ installed on your computer.

Ensure that you have [rojo](https://rojo.space/docs/v7/getting-started/installation/) v7+ installed on your computer.

1. Run `npm init` to create a `package.json`
1. Install `npm install @quenty/loader`
2. Sync in the `node_modules` folder using Rojo. A common file format is something like this:

This is a rojo `project.json` file:
```json
{
  "name": "GameName",
  "globIgnorePaths": [ "**/.package-lock.json" ],
  "tree": {
    "$className": "DataModel",
    "ServerScriptService": {
      "integration": {
        "$path": "node_modules"
      }
    }
  }
}
```

You can put the `node_modules` folder whereever you want, but the recommended location is `ServerScriptService`. 

In your main script you will need to "bootstrap" the components such that `script.Parent.loader` is defined. To do this the following snippet will work.

```lua
local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService.Path.To.NodeModules:FindFirstChild("LoaderUtils", true).Parent
local packages = require(loader).bootstrapGame(ServerScriptService.Path.To.NodeModules)
```

This will create the following components which you can rename if you want.

1. ReplicatedStorage.Packages
2. ReplicatedStorage.SharedPackages
3. ServerScriptService.Packages

From here, every exported package will exist in the packages folder root, with only modules needed to be replicated.

## Manually installing via NPM for a stand-alone module.
If you want to use Nevermore for more stand-alone or reusable scenarios (where you can't assume that a packages folder will be reused, you can manually bootstrap the components using the loader system.

Ensure that you have [Node.js](https://nodejs.org/en/download/) v14+ installed on your computer.

Ensure that you have [rojo](https://rojo.space/docs/v7/getting-started/installation/) v7+ installed on your computer.

1. Run `npm init`
2. Run `npm install @quenty/loader` and whatever packages you want.

In your bootstrapping code you can write something like this for your server code. 

Notice we manually transform and parent our returned loader components. this allows us to bootstrap the
components. We then parent the client component into ReplicatedFirst with dependencies.

```lua
--[[
	@class ServerMain
]]
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local client, server, shared = require(script:FindFirstChild("LoaderUtils", true)).toWallyFormat(script.src, false)

server.Name = "_SoftShutdownServerPackages"
server.Parent = script

client.Name = "_SoftShutdownClientPackages"
client.Parent = ReplicatedFirst

shared.Name = "_SoftShutdownSharedPackages"
shared.Parent = ReplicatedFirst

local clientScript = script.ClientScript
clientScript.Name = "QuentySoftShutdownClientScript"
clientScript:Clone().Parent = ReplicatedFirst

local serviceBag = require(server.ServiceBag).new()
serviceBag:GetService(require(server.SoftShutdownService))

serviceBag:Init()
serviceBag:Start()
```

The client code is as follows.

```lua
--[[
	@class ClientMain
]]

local ReplicatedFirst = game:GetService("ReplicatedFirst")

local packages = ReplicatedFirst:WaitForChild("_SoftShutdownClientPackages")

local SoftShutdownServiceClient = require(packages.SoftShutdownServiceClient)
local serviceBag = require(packages.ServiceBag).new()

serviceBag:GetService(SoftShutdownServiceClient)

serviceBag:Init()
serviceBag:Start()
```

## Manually installing with NPM for Plugins
Ensure that you have [Node.js](https://nodejs.org/en/download/) v14+ installed on your computer.

Ensure that you have [rojo](https://rojo.space/docs/v7/getting-started/installation/) v7+ installed on your computer.
