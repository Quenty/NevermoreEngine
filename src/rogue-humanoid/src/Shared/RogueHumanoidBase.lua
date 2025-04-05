--[=[
	@class RogueHumanoidBase
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local AttributeUtils = require("AttributeUtils")
local BaseObject = require("BaseObject")
local CharacterUtils = require("CharacterUtils")
local RogueHumanoidProperties = require("RogueHumanoidProperties")
local Rx = require("Rx")
local RxRootPartUtils = require("RxRootPartUtils")
local ValueObject = require("ValueObject")

local GROWTH_VALUE_NAMES = {
	"HeadScale";
	"BodyDepthScale";
	"BodyHeightScale";
	"BodyWidthScale";
}

type ScaleState = {
	scale: number,
	maxSize: number,
	minSize: number,
}

local RogueHumanoidBase = setmetatable({}, BaseObject)
RogueHumanoidBase.ClassName = "RogueHumanoidBase"
RogueHumanoidBase.__index = RogueHumanoidBase

function RogueHumanoidBase.new(humanoid, serviceBag)
	local self = setmetatable(BaseObject.new(humanoid), RogueHumanoidBase)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._properties = RogueHumanoidProperties:GetPropertyTable(self._serviceBag, self._obj)
	self._scaleState = self._maid:Add(ValueObject.fromObservable(Rx.combineLatest({
		scale = self._properties.Scale:Observe(),
		maxSize = self._properties.ScaleMax:Observe(),
		minSize = self._properties.ScaleMin:Observe(),
	})))

	if CharacterUtils.getPlayerFromCharacter(self._obj) == Players.LocalPlayer then
		self._maid:GiveTask(self._properties.WalkSpeed:Observe():Subscribe(function(walkSpeed)
			self._obj.WalkSpeed = walkSpeed
		end))
		self._maid:GiveTask(self._properties.CharacterUseJumpPower:Observe():Subscribe(function(useJumpPower)
			self._obj.UseJumpPower = useJumpPower
		end))
		self._maid:GiveTask(self._properties.JumpPower:Observe():Subscribe(function(jumpPower)
			self._obj.JumpPower = jumpPower
		end))
		self._maid:GiveTask(self._properties.JumpHeight:Observe():Subscribe(function(jumpHeight)
			self._obj.JumpHeight = jumpHeight
		end))

		if RunService:IsClient() then
			self:_setupIgnoreCFrameChangesOnScaleChange()
		end
	end

	self._maid:GiveTask(self._properties.MaxHealth:Observe():Subscribe(function(maxHealth)
		local newMaxHealth = math.max(maxHealth, 1)
		local currentMaxHealth = self._obj.MaxHealth

		if currentMaxHealth < newMaxHealth then
			-- ensure we gain the same health as our max health
			local gained = newMaxHealth - currentMaxHealth
			self._obj.MaxHealth = newMaxHealth
			self._obj.Health = self._obj.Health + gained
		else
			-- Losses do not prevent this
			self._obj.MaxHealth = newMaxHealth
			self._obj.Health = math.max(self._obj.Health, newMaxHealth)
		end
	end))

	self:_setupScaling()

	return self
end

function RogueHumanoidBase:_setupScaling()
	self._maid:GiveTask(self._scaleState
		:Observe()
		:Pipe({
			Rx.where(function(state)
				return state ~= nil
			end),
		})
		:Subscribe(function(state)
			self:_updateScale(state)
		end))

	self._maid:GiveTask(self._obj.ChildAdded:Connect(function(child)
		if GROWTH_VALUE_NAMES[child.Name] and child:IsA("NumberValue") then
			local state = self._scaleState.Value
			if state then
				self:_updateScaleValue(child, state)
			end
		end
	end))
end

function RogueHumanoidBase:_setupIgnoreCFrameChangesOnScaleChange()
	self._maid:GiveTask(RxRootPartUtils.observeHumanoidRootPartBrioFromHumanoid(self._obj):Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid, rootPart = brio:ToMaidAndValue()
		local lastSafeRootPartCFrame = rootPart.CFrame
		local rootPartExperiencedTeleport = false

		-- Unfortunately have to run every frame to capture this data
		maid:GiveTask(RunService.PostSimulation:Connect(function()
			lastSafeRootPartCFrame = rootPart.CFrame
			rootPartExperiencedTeleport = false
		end))

		maid:GiveTask(rootPart:GetPropertyChangedSignal("CFrame"):Connect(function()
			rootPartExperiencedTeleport = true
		end))
		maid:GiveTask(rootPart:GetPropertyChangedSignal("Size"):Connect(function()
			rootPartExperiencedTeleport = true
		end))

		maid:GiveTask(self._scaleState.Changed:Connect(function()
			if not rootPartExperiencedTeleport then
				return
			end

			rootPart.CFrame = lastSafeRootPartCFrame
		end))
	end))
end

function RogueHumanoidBase:_updateScale(state: ScaleState)
	for _, name in GROWTH_VALUE_NAMES do
		local numberValue = self._obj:FindFirstChild(name)
		if not (numberValue and numberValue:IsA("NumberValue")) then
			continue
		end

		self:_updateScaleValue(numberValue, state)
	end
end

function RogueHumanoidBase:_updateScaleValue(numberValue: NumberValue, state: ScaleState)
	assert(typeof(numberValue) == "Instance", "Bad numberValue")
	assert(numberValue:IsA("NumberValue"), "Bad numberValue")

	local initialValue = AttributeUtils.initAttribute(numberValue, "RogueHumanoid_OriginalValue", numberValue.Value)

	local i = 1
	local t = state.scale
	local r = 0.07
	local max = state.maxSize
	local min = state.minSize

	local multiplier = min
		+ (math.exp(r*t)*(-min + max))/(math.exp(r*t)
		+ (-i + max)/(i - min))

	numberValue.Value = initialValue*multiplier
end

return RogueHumanoidBase