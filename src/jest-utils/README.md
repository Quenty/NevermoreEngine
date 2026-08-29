## JestUtils

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

Jest testing utilities for Nevermore packages

<div align="center"><a href="https://quenty.github.io/NevermoreEngine/api/JestUtils">View docs →</a></div>

## Installation

```
npm install @quenty/jestutils --save
```

## Usage

`JestUtils.afterThis` queues a maid task next to the code that needs undoing. The queue unwinds in
reverse once the current test finishes, pass or fail, so teardown mirrors setup.

```lua
local Jest = require("Jest")
local JestUtils = require("JestUtils")

local expect = Jest.Globals.expect
local it = Jest.Globals.it

it("reads back what it wrote", function()
	local store = DataStore.new()
	JestUtils.afterThis(store)

	local handle = store:GetHandle()
	JestUtils.afterThis(handle)

	expect(handle:Read()).toEqual(nil)
end)
```

Anything a [Maid](https://quenty.github.io/NevermoreEngine/api/Maid) accepts works: a function, an
`Instance`, an `RBXScriptConnection`, a thread, or a table with a `Destroy` method.

It returns a function that unqueues the task again, which is itself a maid task. An object that
cleans up on its own can hand that back to its own maid so it is never destroyed twice:

```lua
local maid = Maid.new()
maid:GiveTask(JestUtils.afterThis(maid))
```
