--[=[
	Manages tinting a target instance and its tagged descendants.
	Changing part colors is done on the client to allow modifying the tint locally. Useful for hiding latency (i.e. in a placement system), as we can preview a change before the server replicates it to us.

	@client
	@class TintControllerClient
]=]

local require = require(script.Parent.loader).load(script)

local CollectionService = game:GetService("CollectionService")

local AttributeValue = require("AttributeValue")
local BaseObject = require("BaseObject")
local Maid = require("Maid")
local Rx = require("Rx")
local RxAttributeUtils = require("RxAttributeUtils")
local TintableInstanceUtils = require("TintableInstanceUtils")
local TintControllerConstants = require("TintControllerConstants")
local TintControllerUtils = require("TintControllerUtils")

local TintControllerClient = setmetatable({}, BaseObject)
TintControllerClient.ClassName = "TintControllerClient"
TintControllerClient.__index = TintControllerClient

--[=[
	Construct a new controller.
	This tints a parent instance and all of its tagged descendants based on a Color3 attribute.

	@param adornee Instance
	@return TintControllerClient
]=]
function TintControllerClient.new(adornee: Instance)
	local self = setmetatable(BaseObject.new(adornee), TintControllerClient)

	self._color = AttributeValue.new(adornee, TintControllerConstants.ATTRIBUTE_NAME, nil)

	local instanceMaid = Maid.new()
	self._maid:GiveTask(instanceMaid)

	local function handleInstance(instance: Instance)
		if self:_canTint(instance) then
			instanceMaid[instance] = self:_setupInstance(instance)
		end
	end
	local function handleRemoving(instance: Instance)
		instanceMaid[instance] = nil
	end

	handleInstance(adornee)
	for _, v in adornee:GetDescendants() do
		handleInstance(v)
	end
	self._maid:GiveTask(adornee.DescendantAdded:Connect(handleInstance))
	self._maid:GiveTask(adornee.DescendantRemoving:Connect(handleRemoving))

	return self
end

--[=[
	Sets the tint of this controller, and all of its tagged tintable descendants.

	@param tint any
]=]
function TintControllerClient:SetTint(tint: any)
	TintControllerUtils.setTint(self._obj, tint)
end

function TintControllerClient:_observeTintColor3()
	-- Cache the value.
	-- :GetPropertyChangedSignal() is expensive and returns a new signal each call.
	-- This method also calls :GetAttribute() for each sub, which is very slow!
	return RxAttributeUtils.observeAttribute(self._obj, TintControllerConstants.ATTRIBUTE_NAME, nil):Pipe({
		Rx.cache(),
	})
end

function TintControllerClient:_setupInstance(instance: Instance)
	return self:_observeTintColor3():Subscribe(function(color: Color3?)
		-- Check as we may not always have a tint color; in that case we'll want to leave the defaults.
		if color then
			TintableInstanceUtils.setTint(instance, color)
		end
	end)
end

function TintControllerClient:_canTint(instance: Instance)
	-- We can't use use the util here, as we have the extra constraint of requiring the instance to be tagged.
	-- Other modules may want to tag instances without worrying about the binders.
	return CollectionService:HasTag(instance, TintControllerConstants.TAG_NAME) and TintableInstanceUtils.isTintable(instance)
end

return TintControllerClient
