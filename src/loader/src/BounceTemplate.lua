--- Bounces the current named script to the expected version of this module
-- @module BounceTemplate
-- @author Quenty

local function waitForAttribute(instance, attributeName)
    assert(typeof(instance) == "Instance", "Bad instance")
    assert(type(attributeName) == "string", "Bad attributeName")

    local value = instance:GetAttribute(attributeName)
    if value then
        return value
    else
        local bindable = Instance.new("BindableEvent")

        instance:GetAttributeChangedSignal(attributeName):Connect(function()
            value = instance:GetAttribute(attributeName)
            if value then
                bindable:Fire()
            end
        end)

        bindable:Wait()
        bindable:Destroy()

        assert(value, "Somehow got here without a value")
        return value
    end
end

local target = waitForAttribute(script, "BounceTarget")
assert(typeof(target) == "Instance", "Bad target")

return require(target)