---
title: Intro
sidebar_position: 1
---

# Getting started with Nevermore

Here are some quick links to get started with Nevermore:

* [Installation guide](/docs/install)
* [API docs](/api/AccelTween)

Nevermore is a portable ModuleScript loader for Roblox, as well as the name for the collection of utility libraries that come with it. These libraries are separated into packages that can be consumed individually using npm.


## Why should I use Nevermore?

Nevermore provides a variety of easy-to-use utility modules that provide a shared language to build a game with. This includes both conceptual modules, as well as modules for common things you may find difficult to program in a game. Nevermore will not make a game for you, but it can provide or deeply accelerate the creation of a game on Roblox, allowing you to focus on important parts of making a game, such as game design, progression, user experience, and more.

## Nevermore has significant packages that have had cultural impact
Nevermore has had significant cultural impact. There are some packages this repository is known for containing, and have had significant cultural impact on Roblox.

* [Maid](/api/Maid) - Utility object to clean up connections
* [Rx](/api/Rx) - Reactive programming implementation
* [Binder](/api/Binder) - Bind Roblox objects and instances
* [Spring](/api/Spring) and [AccelTween](/api/AccelTween) - Animation objects
* [Signal](/api/Signal) - Signal implementation
* [Promise](/api/Promise) - Promise implementation on Roblox
* [Octree](/api/Octree) - Spatial data structure that helps with performance
* [Blend](/api/Blend) - Declarative UI framework that makes animations and state-management easy
* [DataStore](/api/DataStore) - Battle-tested datastore wrapper
* [Camera](/api/CameraStackService) - Layered camera system that interops with Roblox's cameras

## Nevermore can by used in many cases
While Nevermore was originally designed to make games, in general Nevermore is now a collection of utility libraries that can be used in the following. These use cases have been carefully battle tested. Nevermore is in many top games, gamejams, plugins, and other components across Roblox.

* **Top Games** - Both built originally with Nevermore, or games that use other systems and frameworks but may want to include Nevermore
* **Plugins** - Roblox Studio plugins that want to use UI, techniques, and other approaches.
* **Stand alone models** - Models that need to operate but still may want to consume dependencies.

To learn more about the design philosophy of Nevermore see the [Design](/docs/design) guide.

## Why NPM or a package manager at all?
NPM is a package manager originally intended for JavaScript and node. The alternative option is Wally, Roblox's packages or another package manager. NPM was selected after careful consideration. NPM works best for now, because it has a significant amount of CI/CD pipeline support for monorepos. It works well with the existing Roblox Typescript community, and it was easy to refactor. A package manager is very important because it allows us to consume code without breaking things. This allows for code reuse.

There is no silver bullet for code reuse, but it is better to pay for the cost of code-reuse through the complexity of a package manager, than it is to pay for the cost of maintaining multiple codebases. Nevermore's code-reuse strategy allows for us to invest deeper in marginal systems and bring up the quality of all games at once.

NPM helps deduplicate dependencies and handle conflicts with dependencies.

## Why a mono repo?
A mono-repo is a repository with many packages in it. Nevermore is a mono-repo.