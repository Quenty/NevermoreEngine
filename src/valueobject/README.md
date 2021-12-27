## ValueObject
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

To work like value objects in Roblox and track a single item with .Changed events. The motivation here is to keep it simple to work with an encapsulated value. Instead of exposing an `IPropertyChanged` interface like C# might do, we instead expose objects with .Changed that are encapsulated within the object in question.

<div align="center"><a href="https://quenty.github.io/NevermoreEngine/api/ValueObject">View docs →</a></div>

## Installation
```
npm install @quenty/valueobject --save
```

## Features

* Battle tested
* Can take in a default value
* Automatically fires with a maid that exists for the lifetime of the value