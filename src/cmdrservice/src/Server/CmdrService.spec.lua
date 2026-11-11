--!strict
--[[
	@class CmdrService.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local CmdrService = require("CmdrService")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PermissionProviderUtils = require("PermissionProviderUtils")
local PermissionService = require("PermissionService")
local ServiceBag = require("ServiceBag")
local TieRealmService = require("TieRealmService")
local TieRealms = require("TieRealms")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local MOCK_USER_ID = 55234567

local remoteNameCounter = 0

local COMMAND = {
	Name = "explode",
	Aliases = { "boom" },
	Description = "Makes players explode",
	Group = "Admin",
	Args = {},
}

type Server = {
	cmdrService: CmdrService.CmdrService,
	Destroy: (self: Server) -> (),
}

type Controller = {
	newServer: () -> Server,
	Destroy: (self: Controller) -> (),
}

local function setup(): Controller
	local maid = Maid.new()

	local controller: Controller = {
		newServer = function()
			local serviceBag = ServiceBag.new()
			local tieRealmService: any = serviceBag:GetService(TieRealmService)
			tieRealmService:SetTieRealm(TieRealms.SERVER)

			local cmdrService: CmdrService.CmdrService = serviceBag:GetService(CmdrService) :: any
			local permissionService: any = serviceBag:GetService(PermissionService)
			serviceBag:Init()

			remoteNameCounter += 1
			permissionService:SetProviderFromConfig(PermissionProviderUtils.createSingleUserConfig({
				userId = MOCK_USER_ID,
				remoteFunctionName = string.format("CmdrServiceSpecPermissionRemote%d", remoteNameCounter),
			}))
			serviceBag:Start()

			local destroyed = false
			local server: Server = {
				cmdrService = cmdrService,
				Destroy = function(_self)
					if destroyed then
						return
					end
					destroyed = true

					serviceBag:Destroy()
				end,
			}
			maid:GiveTask(server)

			return server
		end,

		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("CmdrService.RegisterCommand", function()
	it("registers a command on a freshly booted server", function()
		local controller = setup()
		local server = controller.newServer()

		expect(function()
			server.cmdrService:RegisterCommand(COMMAND, function()
				return nil
			end)
		end).never.toThrow()

		controller:Destroy()
	end)

	it("registers a command after a previous server was destroyed", function()
		local controller = setup()

		local first = controller.newServer()
		first.cmdrService:RegisterCommand(COMMAND, function()
			return nil
		end)
		first:Destroy()

		local second = controller.newServer()

		expect(function()
			second.cmdrService:RegisterCommand(COMMAND, function()
				return nil
			end)
		end).never.toThrow()

		controller:Destroy()
	end)
end)
