Nevermore loads modules by name and handles repliction of packages. This has several advantages.

* No more `script.Parent.Parent`

!!! warning
	Modules will not load on the client unless Nevermore is loaded on the server first.

## Modules in Roblox
Modules are of class `ModulesScript` and are stored in the `ServerScriptService.Modules`. 

* Modules are loaded by name, case sensitive
* Modules with the word "Server" (case insensitive) in them at any point will not be replicated to the client
* Folders are used purely for organization and do not affect loading
* Children underneath a module that are not a module will be replicated relatively to their parent

!!! note
	Nevermore expects modules in `ServerScriptService.Modules`

## Best practices

* Modules should not load on yield
* Modules should not hold state
* Document using Nevermore's specified style


## Replication
