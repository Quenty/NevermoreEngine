-- Descriptors
project = 'Nevermore Reference'
description = 'Nevemore Roblux Lua Libraries'
title = 'Nevermore Reference'
full_description = [[
Nevermore is a ModuleScript loader for Roblox, and loads modules by name. Nevermore is designed to make code more portable. Nevermore comes with a variety of utility libraries. These libraries are used on both the client and server and are useful for a variety of things. 
]]

file = {'../Modules/Events', '../App', '../Modules/Character', '../Modules/DataStore', '../Modules/Camera', '../Modules/Utility'}
--format = 'markdown'
examples = 'Examples'

-- Style options
use_markdown_titles = true
no_summary = false
no_space_before_args = true
not_luadoc=true

-- Output
dir = 'api'

-- Custom template
template ='Style'


new_type("constructor", "Constructor")
new_type("signal", "Events", false, "Params")

