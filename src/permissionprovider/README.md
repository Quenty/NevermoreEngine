## Permission Provider
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

Utility permission provider system for Roblox

<div align="center"><a href="https://quenty.github.io/NevermoreEngine/api/PermissionService">View docs →</a></div>

## Installation
```
npm install @quenty/permissionprovider --save
```

## Permission designs
This permissions system originally supported the following scenarios:

1. Any game has a default admin scheme based upon who can edit the game
2. Can override this configuration (although in practice this isn't required)

## New permission features
The following features need to be added.

1. Extensibility: Ability to add / modify default behavior via chain-of-command.
2. Data-store based: Ability to modify based upon a datastore using admin commands, et cetera.

## Role based permission support
Permissions right now are global per a game. We need configurable, sharable, editable non-global permissions. This will require the following support.

1. Permission serialization - Can save permissions to the datastore
2. Permission provisioning per a state

The goal is to use this package as a backend for permissioning such that this package can understand and provide permissions that work out of the default. Permissioning model should act like Discord roles, where tagging is separated out from the actual permissions associated with a role.

This will require a roles package separate from this permission system. This can probably be done in separate packages `roles` and `role-permissions` which may not be open source available. Then, UI can be done in `role-permission-ui` and be generalized and reused. This will also likely not be open source

We may leverage a role-provisioning system to handle permissions. We should build this role system and then assign permissions against the roles at this permission provider layer.