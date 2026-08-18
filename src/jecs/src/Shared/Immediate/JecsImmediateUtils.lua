--!nonstrict

-- For specifically integrating with an ImmediateUtils Scheduler.
local require = require(script.Parent.loader).load(script)

local JecsImmediateCoreComponents = require("JecsImmediateCoreComponents")
local Jecst = require("Jecst")

local JecsImmediateUtils = {}

-- A component dictionary is a dictionary of component ids that also registers them to a JECS world (side effects).
export type JecsComponentDictionary = { [string]: Jecst.Id<any> } & typeof(JecsImmediateCoreComponents({} :: Jecst.World))

-- A component info table is a table (commonly returned by modules) containing a common function to apply and return a component dictionary.
-- You would make your own modules that expose this as a function, like SomeProjectHere._applyAndReturnComponentDictionary
-- Within it, you'd define what components (what data shapes) you'd like to use with jecs state.
-- The components would be registered as valid Jecs components during runtime,
-- but here we can also expose the returned components statically.
export type JecsComponentDictionaryInjector = (world: Jecst.World) -> JecsComponentDictionary

return JecsImmediateUtils
