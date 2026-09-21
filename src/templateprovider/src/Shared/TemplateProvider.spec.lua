--!strict
--[[
	@class TemplateProvider.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local Brio = require("Brio")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local Observable = require("Observable")
local PlayerMockService = require("PlayerMockService")
local PlayerMockServiceClient = require("PlayerMockServiceClient")
local PromiseTestUtils = require("PromiseTestUtils")
local ServiceBag = require("ServiceBag")
local TemplateProvider = require("TemplateProvider")
local TieRealmService = require("TieRealmService")
local TieRealms = require("TieRealms")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type Realms = {
	server: TemplateProvider.TemplateProvider,
	client: TemplateProvider.TemplateProvider,
	Destroy: (self: Realms) -> (),
}

type Controller = {
	newProvider: (initialTemplates: any) -> TemplateProvider.TemplateProvider,
	newRealms: (initialTemplates: any) -> Realms,
	newInstance: (className: string, name: string, parent: Instance?) -> Instance,
	newMaid: () -> Maid.Maid,
	newBrioObservable: (template: Instance) -> Observable.Observable<Brio.Brio<Instance>>,
	collect: (observable: Observable.Observable<any>) -> { any },
	Destroy: (self: Controller) -> (),
}

local function sorted(list: { string }): { string }
	local copy = table.clone(list)
	table.sort(copy)
	return copy
end

local function setup(): Controller
	local maid = Maid.new()

	local controller: Controller = {
		newProvider = function(initialTemplates)
			local serviceBag = maid:Add(ServiceBag.new())
			local provider: TemplateProvider.TemplateProvider =
				serviceBag:GetService(TemplateProvider.new(HttpService:GenerateGUID(false), initialTemplates)) :: any
			serviceBag:Init()
			serviceBag:Start()
			return provider
		end,

		newRealms = function(initialTemplates)
			local definition = TemplateProvider.new(HttpService:GenerateGUID(false), initialTemplates)

			local serverBag = ServiceBag.new()
			local serverTieRealmService: any = serverBag:GetService(TieRealmService)
			serverTieRealmService:SetTieRealm(TieRealms.SERVER)
			local server: TemplateProvider.TemplateProvider = serverBag:GetService(definition) :: any
			local playerMockService: any = serverBag:GetService(PlayerMockService)
			serverBag:Init()
			serverBag:Start()

			local clientBag = ServiceBag.new()
			local clientTieRealmService: any = clientBag:GetService(TieRealmService)
			clientTieRealmService:SetTieRealm(TieRealms.CLIENT)
			local client: TemplateProvider.TemplateProvider = clientBag:GetService(definition) :: any
			local playerMockServiceClient: any = clientBag:GetService(PlayerMockServiceClient)
			clientBag:Init()
			playerMockServiceClient:SetLocalPlayer(playerMockService:CreatePlayer())
			clientBag:Start()

			local destroyed = false
			local realms: Realms = {
				server = server,
				client = client,
				Destroy = function(_self)
					if destroyed then
						return
					end
					destroyed = true

					clientBag:Destroy()
					serverBag:Destroy()
				end,
			}
			maid:GiveTask(realms)

			return realms
		end,

		newInstance = function(className, name, parent)
			local instance = maid:Add(Instance.new(className))
			instance.Name = name
			instance.Parent = parent
			return instance
		end,

		newMaid = function()
			return maid:Add(Maid.new())
		end,

		newBrioObservable = function(template)
			return Observable.new(function(sub)
				local brio = Brio.new(template)
				sub:Fire(brio)
				return brio
			end) :: any
		end,

		collect = function(observable)
			local emissions = {}
			maid:GiveTask(observable:Subscribe(function(value)
				table.insert(emissions, value)
			end))
			return emissions
		end,

		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("TemplateProvider.new", function()
	it("rejects a provider name that is not a string", function()
		expect(function()
			TemplateProvider.new(nil :: any, {})
		end).toThrow("Bad providerName")
	end)

	it("rejects initial templates of the wrong type", function()
		expect(function()
			TemplateProvider.new("Provider", 5 :: any)
		end).toThrow("Bad initialTemplates")
	end)

	it("accepts no initial templates", function()
		local controller = setup()
		local provider = controller.newProvider(nil)

		expect(provider:GetTemplateList()).toEqual({})

		controller:Destroy()
	end)
end)

describe("TemplateProvider.isTemplateProvider", function()
	it("returns true for a template provider", function()
		expect(TemplateProvider.isTemplateProvider(TemplateProvider.new("Provider", {}))).toBe(true)
	end)

	it("returns false for other values", function()
		expect(TemplateProvider.isTemplateProvider({})).toBe(false)
		expect(TemplateProvider.isTemplateProvider(nil)).toBe(false)
	end)
end)

describe("TemplateProvider.Init", function()
	it("rejects a second initialization", function()
		local controller = setup()
		local provider = controller.newProvider({})

		expect(function()
			provider:Init(ServiceBag.new())
		end).toThrow("Already initialized")

		controller:Destroy()
	end)

	it("leaves templates in place when the bag was not told a realm", function()
		local controller = setup()
		local root = controller.newInstance("Folder", "Templates")
		local sword = controller.newInstance("Model", "Sword", root)
		controller.newProvider(root)

		expect(sword.Parent).toBe(root)
		expect(#root:GetChildren()).toBe(1)

		controller:Destroy()
	end)
end)

describe("TemplateProvider.GetTemplate", function()
	it("returns the children of a root folder", function()
		local controller = setup()
		local root = controller.newInstance("Folder", "Templates")
		local sword = controller.newInstance("Model", "Sword", root)
		local provider = controller.newProvider(root)

		expect(provider:GetTemplate("Sword")).toBe(sword)

		controller:Destroy()
	end)

	it("does not return the root itself", function()
		local controller = setup()
		local root = controller.newInstance("Folder", "Templates")
		local provider = controller.newProvider(root)

		expect(provider:GetTemplate("Templates")).toBeNil()

		controller:Destroy()
	end)

	it("returns a nested folder and its children", function()
		local controller = setup()
		local root = controller.newInstance("Folder", "Templates")
		local weapons = controller.newInstance("Folder", "Weapons", root)
		local sword = controller.newInstance("Model", "Sword", weapons)
		local provider = controller.newProvider(root)

		expect(provider:GetTemplate("Weapons")).toBe(weapons)
		expect(provider:GetTemplate("Sword")).toBe(sword)

		controller:Destroy()
	end)

	it("does not return the children of a non-folder template", function()
		local controller = setup()
		local root = controller.newInstance("Folder", "Templates")
		local car = controller.newInstance("Model", "Car", root)
		controller.newInstance("Part", "Wheel", car)
		local provider = controller.newProvider(root)

		expect(provider:GetTemplate("Car")).toBe(car)
		expect(provider:GetTemplate("Wheel")).toBeNil()

		controller:Destroy()
	end)

	it("returns nil for an unknown template", function()
		local controller = setup()
		local provider = controller.newProvider({})

		expect(provider:GetTemplate("Missing")).toBeNil()

		controller:Destroy()
	end)

	it("returns a template added to the root later", function()
		local controller = setup()
		local root = controller.newInstance("Folder", "Templates")
		local provider = controller.newProvider(root)

		local sword = controller.newInstance("Model", "Sword", root)

		expect(PromiseTestUtils.awaitValue(function()
			return provider:GetTemplate("Sword") == sword
		end)).toBe(true)

		controller:Destroy()
	end)

	it("stops returning a template removed from the root", function()
		local controller = setup()
		local root = controller.newInstance("Folder", "Templates")
		local sword = controller.newInstance("Model", "Sword", root)
		local provider = controller.newProvider(root)

		sword.Parent = nil

		expect(PromiseTestUtils.awaitValue(function()
			return provider:GetTemplate("Sword") == nil
		end)).toBe(true)

		controller:Destroy()
	end)

	it("follows a renamed template", function()
		local controller = setup()
		local root = controller.newInstance("Folder", "Templates")
		local sword = controller.newInstance("Model", "Sword", root)
		local provider = controller.newProvider(root)

		sword.Name = "Blade"

		expect(PromiseTestUtils.awaitValue(function()
			return provider:GetTemplate("Blade") == sword and provider:GetTemplate("Sword") == nil
		end)).toBe(true)

		controller:Destroy()
	end)

	it("prefers the most recently added template of a name", function()
		local controller = setup()
		local first = controller.newInstance("Folder", "First")
		controller.newInstance("Model", "Sword", first)
		local second = controller.newInstance("Folder", "Second")
		local secondSword = controller.newInstance("Model", "Sword", second)
		local provider = controller.newProvider(first)

		controller.newMaid():GiveTask(provider:AddTemplates(second))

		expect(provider:GetTemplate("Sword")).toBe(secondSword)

		controller:Destroy()
	end)

	it("rejects a template name that is not a string", function()
		local controller = setup()
		local provider = controller.newProvider({})

		expect(function()
			provider:GetTemplate(nil :: any)
		end).toThrow("Bad templateName")

		controller:Destroy()
	end)
end)

describe("TemplateProvider.IsTemplateAvailable", function()
	it("returns whether the template is known", function()
		local controller = setup()
		local root = controller.newInstance("Folder", "Templates")
		controller.newInstance("Model", "Sword", root)
		local provider = controller.newProvider(root)

		expect(provider:IsTemplateAvailable("Sword")).toBe(true)
		expect(provider:IsTemplateAvailable("Missing")).toBe(false)

		controller:Destroy()
	end)
end)

describe("TemplateProvider.CloneTemplate", function()
	it("returns an unparented copy of the template", function()
		local controller = setup()
		local root = controller.newInstance("Folder", "Templates")
		local sword = controller.newInstance("Model", "Sword", root)
		controller.newInstance("Part", "Handle", sword)
		local provider = controller.newProvider(root)

		local clone = controller.newMaid():Add(provider:CloneTemplate("Sword") :: Instance)

		expect(clone).never.toBe(sword)
		expect(clone.Name).toBe("Sword")
		expect(clone.Parent).toBeNil()
		expect(clone:FindFirstChild("Handle")).never.toBeNil()

		controller:Destroy()
	end)

	it("removes a Template postfix from the copy's name", function()
		local controller = setup()
		local root = controller.newInstance("Folder", "Templates")
		controller.newInstance("Model", "SwordTemplate", root)
		local provider = controller.newProvider(root)

		local clone = controller.newMaid():Add(provider:CloneTemplate("SwordTemplate") :: Instance)

		expect(clone.Name).toBe("Sword")

		controller:Destroy()
	end)

	it("throws for an unknown template", function()
		local controller = setup()
		local provider = controller.newProvider({})

		expect(function()
			provider:CloneTemplate("Missing")
		end).toThrow("Cannot provide template")

		controller:Destroy()
	end)
end)

describe("TemplateProvider.PromiseTemplate", function()
	it("resolves with a known template", function()
		local controller = setup()
		local root = controller.newInstance("Folder", "Templates")
		local sword = controller.newInstance("Model", "Sword", root)
		local provider = controller.newProvider(root)

		local outcome, value = PromiseTestUtils.awaitOutcome(provider:PromiseTemplate("Sword"))

		expect(outcome).toBe("resolved")
		expect(value).toBe(sword)

		controller:Destroy()
	end)

	it("resolves once the template is added", function()
		local controller = setup()
		local root = controller.newInstance("Folder", "Templates")
		local provider = controller.newProvider(root)

		local promise = provider:PromiseTemplate("Sword")
		expect(promise:IsPending()).toBe(true)

		local sword = controller.newInstance("Model", "Sword", root)

		local outcome, value = PromiseTestUtils.awaitOutcome(promise)
		expect(outcome).toBe("resolved")
		expect(value).toBe(sword)

		controller:Destroy()
	end)

	it("shares one promise between pending requests for a template", function()
		local controller = setup()
		local provider = controller.newProvider({})

		expect(provider:PromiseTemplate("Sword")).toBe(provider:PromiseTemplate("Sword"))

		controller:Destroy()
	end)
end)

describe("TemplateProvider.PromiseCloneTemplate", function()
	it("resolves with a copy of the template", function()
		local controller = setup()
		local root = controller.newInstance("Folder", "Templates")
		local sword = controller.newInstance("Model", "SwordTemplate", root)
		local provider = controller.newProvider(root)

		local outcome, clone = PromiseTestUtils.awaitOutcome(provider:PromiseCloneTemplate("SwordTemplate"))
		controller.newMaid():GiveTask(clone)

		expect(outcome).toBe("resolved")
		expect(clone).never.toBe(sword)
		expect(clone.Name).toBe("Sword")

		controller:Destroy()
	end)
end)

describe("TemplateProvider.AddTemplates", function()
	it("stops providing a folder's templates once its task is cleaned", function()
		local controller = setup()
		local folder = controller.newInstance("Folder", "Templates")
		controller.newInstance("Model", "Sword", folder)
		local provider = controller.newProvider({})

		local addMaid = controller.newMaid()
		addMaid:GiveTask(provider:AddTemplates(folder))
		expect(provider:IsTemplateAvailable("Sword")).toBe(true)

		addMaid:DoCleaning()
		expect(provider:IsTemplateAvailable("Sword")).toBe(false)

		controller:Destroy()
	end)

	it("falls back to the earlier template once the override is cleaned", function()
		local controller = setup()
		local first = controller.newInstance("Folder", "First")
		local firstSword = controller.newInstance("Model", "Sword", first)
		local second = controller.newInstance("Folder", "Second")
		controller.newInstance("Model", "Sword", second)
		local provider = controller.newProvider(first)

		local addMaid = controller.newMaid()
		addMaid:GiveTask(provider:AddTemplates(second))
		addMaid:DoCleaning()

		expect(provider:GetTemplate("Sword")).toBe(firstSword)

		controller:Destroy()
	end)

	it("provides the template emitted by an observable of brios", function()
		local controller = setup()
		local sword = controller.newInstance("Model", "Sword")
		local provider = controller.newProvider({})

		local addMaid = controller.newMaid()
		addMaid:GiveTask(provider:AddTemplates(controller.newBrioObservable(sword)))
		expect(provider:GetTemplate("Sword")).toBe(sword)

		addMaid:DoCleaning()
		expect(provider:GetTemplate("Sword")).toBeNil()

		controller:Destroy()
	end)

	it("provides the children of a folder emitted by an observable", function()
		local controller = setup()
		local folder = controller.newInstance("Folder", "Weapons")
		local sword = controller.newInstance("Model", "Sword", folder)
		local provider = controller.newProvider({})

		controller.newMaid():GiveTask(provider:AddTemplates(controller.newBrioObservable(folder)))

		expect(provider:GetTemplate("Weapons")).toBe(folder)
		expect(provider:GetTemplate("Sword")).toBe(sword)

		controller:Destroy()
	end)

	it("provides every entry of a table", function()
		local controller = setup()
		local folder = controller.newInstance("Folder", "Templates")
		local sword = controller.newInstance("Model", "Sword", folder)
		local shield = controller.newInstance("Model", "Shield")
		local provider = controller.newProvider({})

		local declarations: { TemplateProvider.TemplateDeclaration } = { folder, controller.newBrioObservable(shield) }

		local addMaid = controller.newMaid()
		addMaid:GiveTask(provider:AddTemplates(declarations))
		expect(provider:GetTemplate("Sword")).toBe(sword)
		expect(provider:GetTemplate("Shield")).toBe(shield)

		addMaid:DoCleaning()
		expect(provider:GetTemplate("Sword")).toBeNil()
		expect(provider:GetTemplate("Shield")).toBeNil()

		controller:Destroy()
	end)

	it("provides a table given as the initial templates", function()
		local controller = setup()
		local first = controller.newInstance("Folder", "First")
		local sword = controller.newInstance("Model", "Sword", first)
		local second = controller.newInstance("Folder", "Second")
		local shield = controller.newInstance("Model", "Shield", second)
		local provider = controller.newProvider({ first, second })

		expect(provider:GetTemplate("Sword")).toBe(sword)
		expect(provider:GetTemplate("Shield")).toBe(shield)

		controller:Destroy()
	end)

	it("rejects a table entry that is not an instance or observable", function()
		local controller = setup()
		local provider = controller.newProvider({})

		expect(function()
			provider:AddTemplates({ 5 } :: any)
		end).toThrow("Bad value of type")

		controller:Destroy()
	end)

	it("rejects a container of the wrong type", function()
		local controller = setup()
		local provider = controller.newProvider({})

		expect(function()
			provider:AddTemplates(5 :: any)
		end).toThrow("Bad container")

		controller:Destroy()
	end)
end)

describe("TemplateProvider.GetTemplateList", function()
	it("returns every known template", function()
		local controller = setup()
		local root = controller.newInstance("Folder", "Templates")
		local weapons = controller.newInstance("Folder", "Weapons", root)
		local sword = controller.newInstance("Model", "Sword", weapons)
		local provider = controller.newProvider(root)

		local list = provider:GetTemplateList()

		expect(#list).toBe(2)
		expect(table.find(list, weapons)).never.toBeNil()
		expect(table.find(list, sword)).never.toBeNil()

		controller:Destroy()
	end)

	it("keeps the backwards compatible aliases", function()
		expect(TemplateProvider.GetAll).toBe(TemplateProvider.GetTemplateList)
		expect(TemplateProvider.GetAllTemplates).toBe(TemplateProvider.GetTemplateList)
		expect(TemplateProvider.Get).toBe(TemplateProvider.GetTemplate)
		expect(TemplateProvider.IsAvailable).toBe(TemplateProvider.IsTemplateAvailable)
		expect(TemplateProvider.Clone).toBe(TemplateProvider.CloneTemplate)
		expect(TemplateProvider.PromiseClone).toBe(TemplateProvider.PromiseCloneTemplate)
	end)
end)

describe("TemplateProvider.GetContainerList", function()
	it("returns the roots and the folders inside them", function()
		local controller = setup()
		local root = controller.newInstance("Folder", "Templates")
		local weapons = controller.newInstance("Folder", "Weapons", root)
		controller.newInstance("Model", "Sword", weapons)
		local provider = controller.newProvider(root)

		local list = provider:GetContainerList()

		expect(#list).toBe(2)
		expect(table.find(list, root)).never.toBeNil()
		expect(table.find(list, weapons)).never.toBeNil()

		controller:Destroy()
	end)
end)

describe("TemplateProvider.GetChildTemplateNameList", function()
	it("returns an empty list for an unknown folder", function()
		local controller = setup()
		local provider = controller.newProvider({})

		expect(provider:GetChildTemplateNameList("Weapons")).toEqual({})

		controller:Destroy()
	end)

	it("returns the names of the templates inside a folder", function()
		local controller = setup()
		local root = controller.newInstance("Folder", "Templates")
		local weapons = controller.newInstance("Folder", "Weapons", root)
		controller.newInstance("Model", "Sword", weapons)
		controller.newInstance("Model", "Bow", weapons)
		local provider = controller.newProvider(root)

		expect(sorted(provider:GetChildTemplateNameList("Weapons"))).toEqual({ "Bow", "Sword" })

		controller:Destroy()
	end)

	it("does not include deeper descendants", function()
		local controller = setup()
		local root = controller.newInstance("Folder", "Templates")
		local weapons = controller.newInstance("Folder", "Weapons", root)
		local ranged = controller.newInstance("Folder", "Ranged", weapons)
		controller.newInstance("Model", "Bow", ranged)
		local provider = controller.newProvider(root)

		expect(provider:GetChildTemplateNameList("Weapons")).toEqual({ "Ranged" })

		controller:Destroy()
	end)

	it("keeps an unloaded postfix on a template that is not a tombstone", function()
		local controller = setup()
		local root = controller.newInstance("Folder", "Templates")
		local weapons = controller.newInstance("Folder", "Weapons", root)
		controller.newInstance("Model", "Sword_Unloaded", weapons)
		local provider = controller.newProvider(root)

		expect(provider:GetChildTemplateNameList("Weapons")).toEqual({ "Sword_Unloaded" })

		controller:Destroy()
	end)

	it("rejects a folder name that is not a string", function()
		local controller = setup()
		local provider = controller.newProvider({})

		expect(function()
			provider:GetChildTemplateNameList(nil :: any)
		end).toThrow("Bad folderTemplateName")

		controller:Destroy()
	end)
end)

describe("TemplateProvider.ObserveChildTemplateNameList", function()
	it("emits an empty list until the folder is known", function()
		local controller = setup()
		local provider = controller.newProvider({})

		local emissions = controller.collect(provider:ObserveChildTemplateNameList("Weapons"))

		expect(emissions).toEqual({ {} })

		controller:Destroy()
	end)

	it("emits the names once the folder is added", function()
		local controller = setup()
		local root = controller.newInstance("Folder", "Templates")
		local weapons = controller.newInstance("Folder", "Weapons", root)
		controller.newInstance("Model", "Sword", weapons)
		local provider = controller.newProvider({})

		local emissions = controller.collect(provider:ObserveChildTemplateNameList("Weapons"))
		controller.newMaid():GiveTask(provider:AddTemplates(root))

		expect(emissions).toEqual({ {}, { "Sword" } })

		controller:Destroy()
	end)

	it("emits again as children are added and removed", function()
		local controller = setup()
		local root = controller.newInstance("Folder", "Templates")
		local weapons = controller.newInstance("Folder", "Weapons", root)
		local sword = controller.newInstance("Model", "Sword", weapons)
		local provider = controller.newProvider(root)

		local emissions = controller.collect(provider:ObserveChildTemplateNameList("Weapons"))

		controller.newInstance("Model", "Bow", weapons)
		expect(PromiseTestUtils.awaitValue(function()
			return #emissions == 2
		end)).toBe(true)
		expect(sorted(emissions[2])).toEqual({ "Bow", "Sword" })

		sword.Parent = nil
		expect(PromiseTestUtils.awaitValue(function()
			return #emissions == 3
		end)).toBe(true)
		expect(emissions[3]).toEqual({ "Bow" })

		controller:Destroy()
	end)

	it("does not emit when a descendant leaves the names unchanged", function()
		local controller = setup()
		local root = controller.newInstance("Folder", "Templates")
		local weapons = controller.newInstance("Folder", "Weapons", root)
		local sword = controller.newInstance("Model", "Sword", weapons)
		local provider = controller.newProvider(root)

		local emissions = controller.collect(provider:ObserveChildTemplateNameList("Weapons"))
		local handle = controller.newInstance("Part", "Handle", sword)
		handle.Parent = nil
		task.wait()
		task.wait()

		expect(emissions).toEqual({ { "Sword" } })

		controller:Destroy()
	end)
end)

describe("TemplateProvider across a server and a client", function()
	it("hides templates from the client on the server", function()
		local controller = setup()
		local root = controller.newInstance("Folder", "Templates")
		local sword = controller.newInstance("Model", "Sword", root)
		local realms = controller.newRealms(root)

		expect(realms.server:GetTemplate("Sword")).toBe(sword)
		expect(sword:FindFirstAncestorWhichIsA("Camera")).never.toBeNil()
		expect(realms.client:GetTemplate("Sword")).toBeNil()
		expect(realms.client:IsTemplateAvailable("Sword")).toBe(false)

		controller:Destroy()
	end)

	it("hands the container its templates back when the server provider is destroyed", function()
		local controller = setup()
		local root = controller.newInstance("Folder", "Templates")
		local sword = controller.newInstance("Model", "Sword", root)
		local realms = controller.newRealms(root)

		realms:Destroy()

		expect(sword.Parent).toBe(root)
		expect(root:GetChildren()).toEqual({ sword })

		local rebooted = controller.newRealms(root)

		expect(rebooted.server:GetTemplate("Sword")).toBe(sword)
		expect(controller.newMaid():Add(rebooted.server:CloneTemplate("Sword") :: Instance).Name).toBe("Sword")

		controller:Destroy()
	end)

	it("refuses to clone a template the client has not loaded", function()
		local controller = setup()
		local root = controller.newInstance("Folder", "Templates")
		controller.newInstance("Model", "Sword", root)
		local realms = controller.newRealms(root)

		expect(function()
			realms.client:CloneTemplate("Sword")
		end).toThrow("is not replicated")

		controller:Destroy()
	end)

	it("replicates a template to the client on request", function()
		local controller = setup()
		local root = controller.newInstance("Folder", "Templates")
		local sword = controller.newInstance("Model", "Sword", root)
		controller.newInstance("Part", "Handle", sword)
		local realms = controller.newRealms(root)

		local outcome, template = PromiseTestUtils.awaitOutcome(realms.client:PromiseTemplate("Sword"))

		expect(outcome).toBe("resolved")
		expect(template).never.toBe(sword)
		expect(template.Name).toBe("Sword")
		expect(template:FindFirstChild("Handle")).never.toBeNil()
		expect(PromiseTestUtils.awaitValue(function()
			return realms.client:GetTemplate("Sword") == template
		end)).toBe(true)

		controller:Destroy()
	end)

	it("replicates a template nested in a folder", function()
		local controller = setup()
		local root = controller.newInstance("Folder", "Templates")
		local weapons = controller.newInstance("Folder", "Weapons", root)
		controller.newInstance("Model", "SwordTemplate", weapons)
		local realms = controller.newRealms(root)

		local outcome, clone = PromiseTestUtils.awaitOutcome(realms.client:PromiseCloneTemplate("SwordTemplate"))
		controller.newMaid():GiveTask(clone)

		expect(outcome).toBe("resolved")
		expect(clone.Name).toBe("Sword")

		controller:Destroy()
	end)

	it("replicates a template the server adds later", function()
		local controller = setup()
		local root = controller.newInstance("Folder", "Templates")
		local weapons = controller.newInstance("Folder", "Weapons", root)
		local realms = controller.newRealms(root)

		controller.newInstance("Model", "Bow", weapons)

		local outcome, template = PromiseTestUtils.awaitOutcome(realms.client:PromiseTemplate("Bow"))

		expect(outcome).toBe("resolved")
		expect(template.Name).toBe("Bow")

		controller:Destroy()
	end)

	it("lists a folder's templates on the client before any are loaded", function()
		local controller = setup()
		local root = controller.newInstance("Folder", "Templates")
		local weapons = controller.newInstance("Folder", "Weapons", root)
		controller.newInstance("Model", "Sword", weapons)
		controller.newInstance("Model", "Bow", weapons)
		local realms = controller.newRealms(root)

		expect(sorted(realms.client:GetChildTemplateNameList("Weapons"))).toEqual({ "Bow", "Sword" })
		expect(sorted(realms.server:GetChildTemplateNameList("Weapons"))).toEqual({ "Bow", "Sword" })

		controller:Destroy()
	end)

	it("lists each name once in a folder the server hides from inside", function()
		local controller = setup()
		local weapons = controller.newInstance("Folder", "Weapons")
		controller.newInstance("Model", "Sword", weapons)
		controller.newInstance("Model", "Bow", weapons)
		local realms = controller.newRealms(controller.newBrioObservable(weapons))

		expect(sorted(realms.server:GetChildTemplateNameList("Weapons"))).toEqual({ "Bow", "Sword" })
		expect(sorted(realms.client:GetChildTemplateNameList("Weapons"))).toEqual({ "Bow", "Sword" })

		controller:Destroy()
	end)

	it("lists a loaded template once on the client", function()
		local controller = setup()
		local root = controller.newInstance("Folder", "Templates")
		local weapons = controller.newInstance("Folder", "Weapons", root)
		controller.newInstance("Model", "Sword", weapons)
		local realms = controller.newRealms(root)

		local outcome = PromiseTestUtils.awaitOutcome(realms.client:PromiseTemplate("Sword"))

		expect(outcome).toBe("resolved")
		expect(realms.client:GetChildTemplateNameList("Weapons")).toEqual({ "Sword" })

		controller:Destroy()
	end)

	it("follows the server's templates in the client's observed names", function()
		local controller = setup()
		local root = controller.newInstance("Folder", "Templates")
		local weapons = controller.newInstance("Folder", "Weapons", root)
		local sword = controller.newInstance("Model", "Sword", weapons)
		local realms = controller.newRealms(root)

		local emissions = controller.collect(realms.client:ObserveChildTemplateNameList("Weapons"))
		expect(emissions).toEqual({ { "Sword" } })

		controller.newInstance("Model", "Bow", weapons)
		expect(PromiseTestUtils.awaitValue(function()
			return table.concat(sorted(emissions[#emissions]), ",") == "Bow,Sword"
		end)).toBe(true)

		sword:Destroy()
		expect(PromiseTestUtils.awaitValue(function()
			return table.concat(emissions[#emissions], ",") == "Bow"
		end)).toBe(true)

		controller:Destroy()
	end)
end)
