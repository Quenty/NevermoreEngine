--!strict
--[=[
	Shared structural types for the RoguePropertyService package.

	The RoguePropertyDefinition / RoguePropertyTableDefinition classes require the
	helper and util modules in this package, so those helpers cannot import the
	definition classes back without forming a require cycle (and the classes are also
	still nonstrict, exporting no type of their own). This module names the slice of the
	definition surface those helpers use, so they share one type instead of each
	redeclaring it or falling back to `any`. Tighten here once the definition classes
	export real types.

	@class RoguePropertyTypes
]=]

local RoguePropertyTypes = {}

-- The definition surface the array/cache/util helpers touch. `self`, the serviceBag, and
-- the minted property are `any` because their concrete types would re-form the require
-- cycle described above; the named methods/returns are what the helpers actually rely on.
export type RoguePropertyDefinition = {
	Get: (self: any, serviceBag: any, adornee: Instance) -> any,
	GetValueType: (self: any) -> string,
	GetName: (self: any) -> string,
	GetDefaultValue: (self: any) -> any,
	GetEncodedDefaultValue: (self: any) -> any,
}

return RoguePropertyTypes
