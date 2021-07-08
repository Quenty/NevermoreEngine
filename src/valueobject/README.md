## ValueObject

To work like value objects in Roblox and track a single item with .Changed events. The motivation here is to keep it simple to work with an encapsulated value. Instead of exposing an `IPropertyChanged` interface like C# might do, we instead expose objects with .Changed that are encapsulated within the object in question.

## Features

* Battle tested
* Can take in a default value
* Automatically fires with a maid that exists for the lifetime of the value