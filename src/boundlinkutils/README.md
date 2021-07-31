## BoundLinkUtils
<div align="center">
  <a href="http://quenty.github.io/api/">
    <img src="https://img.shields.io/badge/docs-website-green.svg" alt="Documentation" />
  </a>
  <a href="https://discord.gg/mhtGUS8">
    <img src="https://img.shields.io/badge/discord-nevermore-blue.svg" alt="Discord" />
  </a>
  <a href="https://github.com/Quenty/NevermoreEngine/actions">
    <img src="https://github.com/Quenty/NevermoreEngine/actions/workflows/build.yml/badge.svg" alt="Build and release status" />
  </a>
</div>

Utility functions involving binders and links

## Installation
```
npm install @quenty/boundlinkutils --save
```

## Usage
Usage is designed to be simple.

## BoundLinkCollection API

### `BoundLinkCollection.new(binder, linkName, parent)`
Constructs a new version of the collection

### `BoundLinkCollection:GetClasses()`
Gets all the classes

### `BoundLinkCollection:HasClass(class)`
Returns whether or not the class is in the collection

### `BoundLinkCollection:TrackParent(parent)`
Tracks parent in collection

### `BoundLinkCollection:Destroy()`
Cleans up collection

## promiseBoundLinkedClass API

### `promiseBoundLinkedClass(binder, objValue)`

```lua
local promiseBoundLinkedClass = require("promiseBoundLinkedClass")

promiseBoundLinkedClass(myBinder, myObjectValue):Then(function(boundClass)
    print(boundClass)
end)
```

## BoundLinkUtils API

### `BoundLinkUtils.getLinkClass(binder, linkName, from)`
Returns the linked class

### `BoundLinkUtils.getLinkClasses(binder, linkName, from)`
Returns a link of linked classes

### `BoundLinkUtils.getClassesForLinkValues(binders, linkName, from)`
Returns all classes for all binders, in a list

### `BoundLinkUtils.callMethodOnLinkedClasses(binders, linkName, from, methodName, args)`
Calls a method for each linked class for each binder, given the method name and args

## Changelog

### 1.0.3
- Added linting via selene and fixed code to respect linting

### 1.0.0
Initial release

## 0.0.1
- Remove duplicate HasClass implementation

## 0.0.0
- Initial commit
- Add documentation