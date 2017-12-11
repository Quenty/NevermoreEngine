# Adding modules
Much of Nevermore's value is being able to reuse code and using it to load your own modules.

## Modules in Roblox
Modules are of class `ModulesScript` and are stored in the `ServerScriptService.Nevermore`. 

* Modules are loaded by name, case sensitive
* Modules with the word "Server" (case insensitive) in them at any point will not be replicated to the client
* Folders are used purely for organization and do not affect loading
* Children underneath a module that are not a module will be replicated relatively to their parent

## Best practices

* Modules should not load on yield
* Modules should not hold state
* Document using Nevermore's specified style

