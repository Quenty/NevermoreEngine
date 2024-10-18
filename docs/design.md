---
title: Design
sidebar_position: 4
---

# Nevermore design principles

Nevermore consists of a few hundred packages in a [mono-repo](https://en.wikipedia.org/wiki/Monorepo). These packages are [semantically versioned](https://semver.org/) such that long-term maintaince can be done. Nevermore it trying to provide utility modules, and is not a framework.

* **Lego blocks** - Nevermore provides utility modules that can combined in a variety of ways
* **Not a framework** - Nevermore works in a variety of other architectures
* **Versioned** - Nevermore should be versioned. Nevermore should not break games when changes are made.
* **Fast development** - Nevermore should accelerate game development
* **Only the dependencies you need** - Nevermore tries to include only the dependencies you need
* **Battle tested** - Code in Nevermore should generally be used in games
* **Works in plugins** - Code should be usable in plugins too


## Testing ideas
Nevermore has three testing strategies

1. **Unit tests** - Used sparingly for core libraries that don't depend on Roblox. These files are .spec.lua files. See [testez](https://roblox.github.io/testez/) for details.
3. **Battle-testing** - Run code in production under a high variety of conditions.

## Package types
There are different types of packages in Nevermore. It's useful to reason about a package

### Utility libraries
Library packages tend to be packages that export one or multiple libraries. These are usually pure utility functions. Here are some sample library packages:

* [Table](/api/Table)
* [Math](/api/Math)
* [RandomUtils](/api/RandomUtils)
* [Set](/api/Set)
* [Elo](/api/EloUtils)

### Object utility libraries
These are very similiar to libraries but they tend to export an object, and some supporting objects. These objects are concepts that are useful to learn, and generally exist outside of Roblox (although they may not). These are fundamental building blocks and patterns in Roblox.

* [Octree](/api/Octree)
* [Maid](/api/Maid)
* [Rx](/api/Rx)
* [Promise](/api/Promise)
* [Binder](/api/Binder)
* [Queue](/api/Queue)

### Integration services
There services are primary about providing a contract between two services.

* [GameConfigService](/api/GameConfigService)
* [CameraStackService](/api/CameraStackService)
* [PlayerDataStoreService](/api/PlayerDataStoreService)



## Design criteria

Nevermore has been evolving for a long time. As Roblox has improved its platform capabilities, parts of Nevermore have become unneeded, while new parts are necessary to keep
things working. Nevermore is a repository of useful generalized modules that can be used to make games quicker. Note these modules while opinionated to some level, try to not be
opinionated about...

1. Your games architecture
2. Consumption of code (plugin, game, et cetera)

Code is designed to be copied and pasted as needed, but first and foremost, is designed to empower James's (Quenty's) workflow. For this reason, while Nevermore tries its best to be useful
to as wide of an audience as possible, in many ways document and design notes are lacking because this is not its first purpose.


## Loading system

Nevermore's loading system has changed over time, but is generally responsible for loading many modules.
