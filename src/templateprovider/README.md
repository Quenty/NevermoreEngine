## TemplateProvider
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

Base of a template retrieval system

<div align="center"><a href="https://quenty.github.io/NevermoreEngine/api/TemplateProvider">View docs →</a></div>

## Installation
```
npm install @quenty/templateprovider --save
```

## Usage
Usage is designed to be simple.

### `TemplateProvider.new(container, replicationParent)`

If `replicationParent` is given then contents loaded from the cloud will be replicated to the replicationParent when on the server.

### `TemplateProvider:Init()`

Initializes the template provider, downloading components and other things needed

### `TemplateProvider:Clone(templateName)`

### `TemplateProvider:Get(templateName)`

### `TemplateProvider:AddContainer(container)`

### `TemplateProvider:RemoveContainer(container)`

### `TemplateProvider:IsAvailable(templateName)`

### `TemplateProvider:GetAll()`

### `TemplateProvider:GetContainers()`

