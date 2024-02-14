## Loader
<div align="center">
  <a href="http://quenty.github.io/NevermoreEngine/">
    <img src="https://github.com/Quenty/NevermoreEngine/actions/workflows/docs.yml/badge.svg" alt="Documentation status" />
  </a>
  <a href="https://discord.gg/mhtGUS8">
    <img src="https://img.shields.io/discord/385151591524597761?color=5865F2&label=discord&logo=discord&logoColor=white" alt="Discord" />
  </a>
  <a href="https://github.com/Quenty/NevermoreEngine/actions">
    <img src="https://github.com/Quenty/NevermoreEngine/actions/workflows/build.yml/badge.svg" alt="Build and release status" />
  </a>
</div>

A simple module loader for Roblox

## Installation
```
npm install @quenty/loader --save
```

<div align="center"><a href="https://quenty.github.io/NevermoreEngine/api/Loader">View docs →</a></div>

## Installation with NPM

Install via NPM like this:
```
npm install @quenty/loader --save
```

## New features and requirements

1. Convert between NPM and Wally format
	1. Replicate/build out correct models
	2. Preserve single script instance for debugging
	3. Create bounces 
2. Convert between Wally format and Nevermore original format
3. Understand object values at the NPM level -> Wally format

## Bootstrapping

```lua
local LoaderUtils = require(ServerScriptService.Modules:FindFirstChild("LoaderUtils", true))
LoaderUtils.toWallyFormat(ServerScriptService.Modules, {
	Client = ReplicatedStorage;
	Shared = ReplicatedStorage;
	Server = ServerScriptService;
})
```

## Algorithm
We assume is a folder is a package if it contains a "dependencies" folder.
For a given package folder, all packages underneath it shall have...

1. Access to every other package that is not in the dependencies folder
2. Access to every package in the dependency folder at the 1st level of recursion
3. Access to every package in the dependency folder at each ancestor level at the 1st level of recursion
4. Access to every sibling package (this is because we expect to be installed at a uniform level)



-------

- A module will be defined by a module script
- A junction will be defined by a place with a "Dependencies" folder and will have access to its dependency folder, and all ancestors, but not siblings
- A junction will give all modules underneath it access 

- Modules expect external dependencies to be at script.Parent
- Modules will be split between client/server/shared based upon their parent
- Dependencies will be any modules up to the root 
- For conflicts, the first copy available will be used (Start at a tree, go up one node, and look all the way down for a copy)
- Modules will prefer to be parented directly, at a top level, without a bouncer
	- However, if a requirement is needed at a separate version, the module will be parented to its own folder, and a bounce script will point to it.
	- All required modules that it may need will point back to this module.

1. Discover junctions and
2. If there are no conflicts, then just link the shared modules for the server to consume, and we're done.
3. If there are conflicts, than we need to build 2 trees for each conflict.
	1. Identify junction 

```
		A
	B		C
Maid1	Other	Maid2
```
