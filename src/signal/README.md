## Signal
A simple signal implementation for Roblox

This allows us to pass Lua objects around through a signal without reserialization. It wraps a Roblox bindable event, and reproduces Roblox's signal behavior.

## Features

* Supports Roblox's deferred event mode
* Allows you to pass metatables and other data without reserialization
* Light-weight
* Maintains stack traces
