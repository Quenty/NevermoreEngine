--[=[
	@class RoguePropertyModifierUtils
]=]

local require = require(script.Parent.loader).load(script)

local LinkUtils = require("LinkUtils")
local RoguePropertyModifierConstants = require("RoguePropertyModifierConstants")
local RxLinkUtils = require("RxLinkUtils")

local RoguePropertyModifierUtils = {}

function RoguePropertyModifierUtils.createSourceLink(modifier, source)
	return LinkUtils.createLink(RoguePropertyModifierConstants.PROPERTY_SOURCE_LINK_NAME, modifier, source)
end

function RoguePropertyModifierUtils.observeSourceLinksBrio(modifier)
	return RxLinkUtils.observeValidLinksBrio(RoguePropertyModifierConstants.PROPERTY_SOURCE_LINK_NAME, modifier)
end

function RoguePropertyModifierUtils.getSourceFromModifier(modifier)
	return LinkUtils.getLinkValue(RoguePropertyModifierConstants.PROPERTY_SOURCE_LINK_NAME, modifier)
end

return RoguePropertyModifierUtils