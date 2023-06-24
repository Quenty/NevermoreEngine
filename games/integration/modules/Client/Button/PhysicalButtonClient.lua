--[=[
	@class PhysicalButtonClient
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local BaseObject = require("BaseObject")
local CameraStackService = require("CameraStackService")
local GameTranslator = require("GameTranslator")
local PhysicalButtonConstants = require("PhysicalButtonConstants")
local PromiseUtils = require("PromiseUtils")
local RagdollClient = require("RagdollClient")
local Rx = require("Rx")
local RxBinderUtils = require("RxBinderUtils")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")

local PhysicalButtonClient = setmetatable({}, BaseObject)
PhysicalButtonClient.ClassName = "PhysicalButtonClient"
PhysicalButtonClient.__index = PhysicalButtonClient

require("PromiseRemoteEventMixin"):Add(PhysicalButtonClient, PhysicalButtonConstants.REMOTE_EVENT_NAME)

function PhysicalButtonClient.new(obj, serviceBag)
	local self = setmetatable(BaseObject.new(obj), PhysicalButtonClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._cameraStackService = self._serviceBag:GetService(CameraStackService)
	self._gameTranslator = self._serviceBag:GetService(GameTranslator)
	self._ragdollClient = self._serviceBag:GetService(RagdollClient)

	self:_setup()

	return self
end

function PhysicalButtonClient:GetAdornee()
	return self._obj
end

function PhysicalButtonClient:_observeLocalPlayerRagdolled()
	return RxInstanceUtils.observeProperty(Players.LocalPlayer, "Character")
		:Pipe({
			Rx.switchMap(function(character)
				if character then
					return RxBrioUtils.flattenToValueAndNil(RxInstanceUtils.observeChildrenOfClassBrio(character, "Humanoid"))
				else
					return Rx.of(nil)
				end
			end);
			Rx.switchMap(function(humanoid)
				if humanoid then
					return RxBinderUtils.observeBoundClass(self._ragdollClient, humanoid)
				else
					return Rx.of(nil)
				end
			end);
		})
end

function PhysicalButtonClient:_setup()
	-- pretend like we're initializing real UI here that needs to be bound

	self._maid:GivePromise(PromiseUtils.all({
		self._gameTranslator:PromiseFormatByKey("actions.ragdoll"),
		self._gameTranslator:PromiseFormatByKey("actions.unragdoll")
	}))
		:Then(function(ragdollText, unragdollText)
			local proximityPrompt = Instance.new("ProximityPrompt")
			proximityPrompt.Name = "PhysicalButton_Render"
			proximityPrompt.AutoLocalize = false
			proximityPrompt.Parent = self._obj
			self._maid:GiveTask(proximityPrompt)

			self._maid:GiveTask(self:_observeLocalPlayerRagdolled():Subscribe(function(ragdollClass)
				if ragdollClass then
					proximityPrompt.ActionText = unragdollText
				else
					proximityPrompt.ActionText = ragdollText
				end
			end))

			self._maid:GiveTask(proximityPrompt.Triggered:Connect(function()
				self:_activate()
			end))
		end)
end

function PhysicalButtonClient:_activate()
	-- Immediate feedback
	self._cameraStackService:GetImpulseCamera():Impulse(Vector3.new(0.25, 0, 0.25*(math.random()-0.5)))

	self:PromiseRemoteEvent():Then(function(remoteEvent)
		remoteEvent:FireServer()
	end)
end

return PhysicalButtonClient