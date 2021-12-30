-- Main injection point
-- @script ServerMain

local require = require(script.Parent.loader).load(script)

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("IKService"))

serviceBag:Init()
serviceBag:Start()

-- Build test NPC rigs
local RigBuilderUtils = require("RigBuilderUtils")
RigBuilderUtils.promiseR15MeshRig()
	:Then(function(character)
		local humanoid = character.Humanoid

		-- reparent to middle
		humanoid.RootPart.CFrame = CFrame.new(0, 25, 0)
		character.Parent = workspace
		humanoid.RootPart.CFrame = CFrame.new(0, 25, 0)

		-- look down
		serviceBag:GetService(require("IKService")):UpdateServerRigTarget(humanoid, Vector3.new(0, 0, 0))
	end)
