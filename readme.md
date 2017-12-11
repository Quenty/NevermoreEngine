<h1 align="center">Nevermore</h1>
<div align="center">
	<a href="http://quenty.github.io/api/">
		<img src="https://img.shields.io/badge/docs-website-green.svg" alt="Documentation" />
	</a>
	<a href="https://discord.gg/mhtGUS8">
		<img src="https://img.shields.io/badge/discord-nevermore-blue.svg" alt="Discord" />
	</a>
</div>

<div align="center">
	ModuleScript loader with reusable and easy unified server-client modules for faster game development on Roblox
</div>

<div>&nbsp;</div>

## About
Nevermore is a ModuleScript loader for Roblox, and loads modules by name. Nevermore is designed to make code more portable. Nevermore comes with a variety of utility libraries. These libraries are used on both the client and server and are useful for a variety of things. 

Nevermore follows both functional and OOP programming paradigms. However, many modules return classes, and may require more advance Lua knowledge to use. 

## Get Nevermore
To install Nevermore, paste the following code into your command bar in Roblox Studio!

```lua
local h = game:GetService("HttpService") local e = h.HttpEnabled h.HttpEnabled = true loadstring(h:GetAsync("https://raw.githubusercontent.com/Quenty/NevermoreEngine/version2/Install.lua"))() h.HttpEnabled = e
```

## Documentation
See [quenty.github.io/api/](http://quenty.github.io/api/) for API documentation.

## Usage
See [quenty.github.io/api/](http://quenty.github.io/api/topics/usage.md.html) for examples and usage documentation.

## Community

* [Discord](https://discord.gg/mhtGUS8)