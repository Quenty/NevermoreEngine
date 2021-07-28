## RandomUtils
<div align="center">
  <a href="http://quenty.github.io/api/">
    <img src="https://img.shields.io/badge/docs-website-green.svg" alt="Documentation" />
  </a>
  <a href="https://discord.gg/mhtGUS8">
    <img src="https://img.shields.io/badge/discord-nevermore-blue.svg" alt="Discord" />
  </a>
  <a href="https://github.com/Quenty/NevermoreEngine/actions">
    <img src="https://github.com/Quenty/NevermoreEngine/workflows/lint/badge.svg" alt="Actions Status" />
  </a>
</div>

Utility functions to make working with random numbers easier

## Installation
```
npm install @quenty/randomutils --save
```

## Usage
Usage is pretty simple! Just load up the library.

### Choice
Choose one from the list

```lua
local options = { "apples", "oranges", "bananas" }
print(RandomUtils.choice(options)) --> "apples"
```

Additionally, a random object can be passed into this to always get the same result:

```lua
local options = { "apples", "oranges", "bananas" }
local random = Random.new()

print(RandomUtils.choice(options, random)) --> "apples"
```

### Shuffled copy
Creates a copy of the table, but shuffled using fisher-yates shuffle

```lua
local options = { "apples", "oranges", "bananas" }
local random = Random.new()

print(RandomUtils.shuffledCopy(options)) --> shuffled copy of table
print(RandomUtils.shuffledCopy(options, random)) --> deterministic shuffled copy of table
```



### Inlined shuffle
Shuffled using fisher-yates shuffle

```lua
local options = { "apples", "oranges", "bananas" }
local random = Random.new()

RandomUtils.shuffle(options, random)
print(options) --> deterministic shuffled copy of table

RandomUtils.shuffle(options)
print(options) --> shuffled table
```

### Weighted choice
```lua
local options = { "apples", "oranges", "bananas" }
local weights = { 10,       1,         2 }
local random = Random.new()

-- Use our own random object
print(RandomUtils.weightedChoice(options, weights, random)) --> most likely "apples"

-- Use the system random generator
print(RandomUtils.weightedChoice(options, weights)) --> most likely "apples"
```

## Changelog

### 1.0.0
Initial release

### 0.0.1
Added documentation

### 0.0.0
Initial commit