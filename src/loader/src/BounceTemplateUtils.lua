---
-- @module BounceTemplateUtils
-- @author Quenty

local BounceTemplate = script.Parent.BounceTemplate

local BounceTemplateUtils = {}

function BounceTemplateUtils.create(target)
    assert(typeof(target) == "Instance", "Bad target")

    local copy = BounceTemplate:Clone()
    copy.Name = target.Name

    if target:GetAttribute("BounceTarget") then
        copy:SetAttribute(target:GetAttribute("BounceTarget"))
    else
        copy:SetAttribute("BounceTarget", target)
    end

    return copy
end

return BounceTemplateUtils