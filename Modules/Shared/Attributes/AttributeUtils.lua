---
-- @module AttributeUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local RunService = game:GetService("RunService")

local Maid = require("Maid")

local AttributeUtils = {}

function AttributeUtils.bindToBinder(inst, attributeName, binder)
	assert(binder)
	assert(typeof(inst) == "Instance")
	assert(type(attributeName) == "string")

	local maid = Maid.new()

	local function syncAttribute()
		if inst:GetAttribute(attributeName) then
			if RunService:IsClient() then
				binder:BindClient(inst)
			else
				binder:Bind(inst)
			end
		else
			binder:Unbind(inst)
		end
	end
	maid:GiveTask(inst:GetAttributeChangedSignal(attributeName):Connect(syncAttribute))

	local function syncBoundClass()
		if binder:Get(inst) then
			inst:SetAttribute(attributeName, true)
		else
			inst:SetAttribute(attributeName, false)
		end
	end
	maid:GiveTask(binder:ObserveInstance(inst, syncBoundClass))

	if binder:Get(inst) or inst:GetAttribute(attributeName) then
		inst:SetAttribute(attributeName, true)
		if RunService:IsClient() then
			binder:BindClient(inst)
		else
			binder:Bind(inst)
		end
	else
		inst:SetAttribute(attributeName, false)
		-- no need to bind
	end

	-- Depopuplate the attribute on exit
	maid:GiveTask(function()
		-- Force all cleaning first
		maid:DoCleaning()

		-- Cleanup
		inst:SetAttribute(attributeName, nil)
	end)

	return maid
end

return AttributeUtils