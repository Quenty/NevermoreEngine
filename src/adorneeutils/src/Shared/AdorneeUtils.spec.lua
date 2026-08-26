--!strict
--[[
	@class AdorneeUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local AdorneeUtils = require("AdorneeUtils")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local HANDLE_CFRAME = CFrame.new(5, 5, 5)
local HANDLE_SIZE = Vector3.new(1, 1, 2)
local BLADE_CFRAME = CFrame.new(50, 0, 0)
local BLADE_SIZE = Vector3.new(1, 1, 8)
local TOOL_BOUNDING_BOX_CFRAME = CFrame.new(27.5, 2.5, 1)
local TOOL_BOUNDING_BOX_SIZE = Vector3.new(46, 6, 10)

local MODEL_BOUNDING_BOX_CFRAME = CFrame.new(5, 0, 0)
local MODEL_BOUNDING_BOX_SIZE = Vector3.new(12, 2, 2)

local ROOT_PART_CFRAME = CFrame.new(1, 2, 3)
local CHARACTER_BOUNDING_BOX_SIZE = Vector3.new(2, 4, 1)

local ACCESSORY_HANDLE_CFRAME = CFrame.new(7, 8, 9)
local ACCESSORY_HANDLE_SIZE = Vector3.new(3, 3, 3)

local CLOTHING_PART_CFRAME = CFrame.new(20, 0, 0)
local CLOTHING_PART_SIZE = Vector3.new(4, 4, 4)

type Controller = {
	newPart: (size: Vector3?, cframe: CFrame?, name: string?) -> BasePart,
	newFolder: () -> Folder,
	newModel: () -> (Model, BasePart, BasePart),
	newEmptyModel: () -> Model,
	newAttachment: (parent: Instance, cframe: CFrame?) -> Attachment,
	newCharacter: () -> (Model, Humanoid, BasePart),
	newOrphanHumanoid: () -> Humanoid,
	newTool: () -> (Tool, BasePart, BasePart),
	newHandlelessTool: () -> (Tool, BasePart),
	newAccessory: () -> (Accessory, BasePart),
	newClothing: () -> (Clothing, BasePart),
	destroy: () -> (),
}

local function setup(): Controller
	local maid = Maid.new()

	local function newPart(size: Vector3?, cframe: CFrame?, name: string?): BasePart
		local part = Instance.new("Part")
		part.Anchored = true
		part.Name = name or "Part"
		part.Size = size or Vector3.new(2, 2, 2)
		part.CFrame = cframe or CFrame.new()
		maid:GiveTask(part)
		return part
	end

	local controller: Controller = {
		newPart = newPart,

		newFolder = function()
			local folder = Instance.new("Folder")
			maid:GiveTask(folder)
			return folder
		end,

		newModel = function()
			local model = Instance.new("Model")

			local first = newPart(Vector3.new(2, 2, 2), CFrame.new(0, 0, 0), "First")
			first.Parent = model

			local second = newPart(Vector3.new(2, 2, 2), CFrame.new(10, 0, 0), "Second")
			second.Parent = model

			maid:GiveTask(model)
			return model, first, second
		end,

		newEmptyModel = function()
			local model = Instance.new("Model")
			maid:GiveTask(model)
			return model
		end,

		newAttachment = function(parent, cframe)
			local attachment = Instance.new("Attachment")
			attachment.CFrame = cframe or CFrame.new(0, 1, 0)
			attachment.Parent = parent
			maid:GiveTask(attachment)
			return attachment
		end,

		newCharacter = function()
			local character = Instance.new("Model")

			local rootPart = newPart(Vector3.new(2, 2, 1), ROOT_PART_CFRAME, "HumanoidRootPart")
			rootPart.Parent = character

			local torso = newPart(Vector3.new(2, 2, 1), CFrame.new(1, 4, 3), "Torso")
			torso.Parent = character

			local humanoid = Instance.new("Humanoid")
			humanoid.Parent = character

			maid:GiveTask(character)
			return character, humanoid, rootPart
		end,

		newOrphanHumanoid = function()
			local humanoid = Instance.new("Humanoid")
			maid:GiveTask(humanoid)
			return humanoid
		end,

		newTool = function()
			local tool = Instance.new("Tool")

			local blade = newPart(BLADE_SIZE, BLADE_CFRAME, "Blade")
			blade.Parent = tool

			local handle = newPart(HANDLE_SIZE, HANDLE_CFRAME, "Handle")
			handle.Parent = tool

			maid:GiveTask(tool)
			return tool, handle, blade
		end,

		newHandlelessTool = function()
			local tool = Instance.new("Tool")

			local blade = newPart(BLADE_SIZE, BLADE_CFRAME, "Blade")
			blade.Parent = tool

			maid:GiveTask(tool)
			return tool, blade
		end,

		newAccessory = function()
			local accessory = Instance.new("Accessory")

			local handle = newPart(ACCESSORY_HANDLE_SIZE, ACCESSORY_HANDLE_CFRAME, "Handle")
			handle.Parent = accessory

			maid:GiveTask(accessory)
			return accessory, handle
		end,

		newClothing = function()
			local clothing = Instance.new("Shirt")

			local part = newPart(CLOTHING_PART_SIZE, CLOTHING_PART_CFRAME, "ClothingPart")
			part.Parent = clothing

			maid:GiveTask(clothing)
			return clothing, part
		end,

		destroy = function()
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller.destroy))

	return controller
end

describe("Tool inheriting from Model", function()
	it("still reports as a model", function()
		local controller = setup()
		local tool = controller.newTool()

		expect(tool:IsA("Model")).toEqual(true)

		controller.destroy()
	end)

	it("adorns to the handle rather than the model bounding box", function()
		local controller = setup()
		local tool, handle = controller.newTool()

		expect(AdorneeUtils.getCenter(tool)).toEqual(handle.Position)
		expect(AdorneeUtils.getPart(tool)).toEqual(handle)
		expect(AdorneeUtils.getPartCFrame(tool)).toEqual(handle.CFrame)
		expect(AdorneeUtils.getAlignedSize(tool)).toEqual(handle.Size)
		expect(AdorneeUtils.getRenderAdornee(tool)).toEqual(handle)

		controller.destroy()
	end)

	it("does not fall back to another part when the tool has no handle", function()
		local controller = setup()
		local tool, blade = controller.newHandlelessTool()

		expect(tool:FindFirstChildWhichIsA("BasePart")).toEqual(blade)
		expect(AdorneeUtils.getCenter(tool)).toBeNil()
		expect(AdorneeUtils.getPart(tool)).toBeNil()
		expect(AdorneeUtils.getAlignedSize(tool)).toBeNil()
		expect(AdorneeUtils.getRenderAdornee(tool)).toBeNil()

		controller.destroy()
	end)

	it("adorns to the handle even when the tool has a primary part", function()
		local controller = setup()
		local tool, handle, blade = controller.newTool()
		tool.PrimaryPart = blade

		expect(AdorneeUtils.getPart(tool)).toEqual(handle)

		controller.destroy()
	end)

	it("leaves plain models on the model path", function()
		local controller = setup()
		local model = controller.newModel()

		expect(AdorneeUtils.getCenter(model)).toEqual(MODEL_BOUNDING_BOX_CFRAME.Position)
		expect(AdorneeUtils.getAlignedSize(model)).toEqual(MODEL_BOUNDING_BOX_SIZE)
		expect(AdorneeUtils.getRenderAdornee(model)).toEqual(model)

		controller.destroy()
	end)
end)

describe("AdorneeUtils.getCenter", function()
	it("returns the position of a base part", function()
		local controller = setup()
		local part = controller.newPart(nil, CFrame.new(1, 2, 3))

		expect(AdorneeUtils.getCenter(part)).toEqual(Vector3.new(1, 2, 3))

		controller.destroy()
	end)

	it("returns the bounding box center of a model", function()
		local controller = setup()
		local model = controller.newModel()

		expect(AdorneeUtils.getCenter(model)).toEqual(MODEL_BOUNDING_BOX_CFRAME.Position)

		controller.destroy()
	end)

	it("returns the world position of an attachment", function()
		local controller = setup()
		local part = controller.newPart(nil, CFrame.new(10, 0, 0))
		local attachment = controller.newAttachment(part, CFrame.new(0, 1, 0))

		expect(AdorneeUtils.getCenter(attachment)).toEqual(Vector3.new(10, 1, 0))

		controller.destroy()
	end)

	it("returns the root part position of a humanoid", function()
		local controller = setup()
		local _character, humanoid = controller.newCharacter()

		expect(AdorneeUtils.getCenter(humanoid)).toEqual(ROOT_PART_CFRAME.Position)

		controller.destroy()
	end)

	it("returns nil for a humanoid with no root part", function()
		local controller = setup()
		local humanoid = controller.newOrphanHumanoid()

		expect(AdorneeUtils.getCenter(humanoid)).toBeNil()

		controller.destroy()
	end)

	it("returns the handle position of an accessory", function()
		local controller = setup()
		local accessory = controller.newAccessory()

		expect(AdorneeUtils.getCenter(accessory)).toEqual(ACCESSORY_HANDLE_CFRAME.Position)

		controller.destroy()
	end)

	it("returns nil for an accessory with no part", function()
		local controller = setup()
		local accessory = Instance.new("Accessory")

		expect(AdorneeUtils.getCenter(accessory)).toBeNil()

		accessory:Destroy()
		controller.destroy()
	end)

	it("returns the part position of clothing", function()
		local controller = setup()
		local clothing = controller.newClothing()

		expect(AdorneeUtils.getCenter(clothing)).toEqual(CLOTHING_PART_CFRAME.Position)

		controller.destroy()
	end)

	it("returns the handle position of a tool", function()
		local controller = setup()
		local tool = controller.newTool()

		expect(AdorneeUtils.getCenter(tool)).toEqual(HANDLE_CFRAME.Position)

		controller.destroy()
	end)

	it("returns nil when a tool's handle is not a base part", function()
		local controller = setup()
		local tool = controller.newHandlelessTool()

		local decoy = Instance.new("Folder")
		decoy.Name = "Handle"
		decoy.Parent = tool

		expect(AdorneeUtils.getCenter(tool)).toBeNil()

		controller.destroy()
	end)

	it("returns nil for an unsupported adornee", function()
		local controller = setup()
		local folder = controller.newFolder()

		expect(AdorneeUtils.getCenter(folder)).toBeNil()

		controller.destroy()
	end)

	it("throws for a non-instance", function()
		expect(function()
			AdorneeUtils.getCenter(nil :: any)
		end).toThrow()

		expect(function()
			AdorneeUtils.getCenter(Vector3.zero :: any)
		end).toThrow()
	end)
end)

describe("AdorneeUtils.getBoundingBox", function()
	it("returns the model bounding box", function()
		local controller = setup()
		local model = controller.newModel()

		local cframe, size = AdorneeUtils.getBoundingBox(model)

		expect(cframe).toEqual(MODEL_BOUNDING_BOX_CFRAME)
		expect(size).toEqual(MODEL_BOUNDING_BOX_SIZE)

		controller.destroy()
	end)

	it("returns a zero sized box at an attachment's world cframe", function()
		local controller = setup()
		local part = controller.newPart(nil, CFrame.new(10, 0, 0))
		local attachment = controller.newAttachment(part, CFrame.new(0, 1, 0))

		local cframe, size = AdorneeUtils.getBoundingBox(attachment)

		expect(cframe).toEqual(CFrame.new(10, 1, 0))
		expect(size).toEqual(Vector3.zero)

		controller.destroy()
	end)

	it("returns the cframe and size of a base part", function()
		local controller = setup()
		local part = controller.newPart(Vector3.new(4, 1, 2), CFrame.new(1, 2, 3))

		local cframe, size = AdorneeUtils.getBoundingBox(part)

		expect(cframe).toEqual(CFrame.new(1, 2, 3))
		expect(size).toEqual(Vector3.new(4, 1, 2))

		controller.destroy()
	end)

	it("returns the handle box of a tool rather than its model bounding box", function()
		local controller = setup()
		local tool = controller.newTool()

		local modelCFrame, modelSize = tool:GetBoundingBox()

		expect(modelCFrame).toEqual(TOOL_BOUNDING_BOX_CFRAME)
		expect(modelSize).toEqual(TOOL_BOUNDING_BOX_SIZE)

		local cframe, size = AdorneeUtils.getBoundingBox(tool)

		expect(cframe).toEqual(HANDLE_CFRAME)
		expect(size).toEqual(HANDLE_SIZE)

		controller.destroy()
	end)

	it("returns nil for a tool with no handle", function()
		local controller = setup()
		local tool = controller.newHandlelessTool()

		local cframe, size = AdorneeUtils.getBoundingBox(tool)

		expect(cframe).toBeNil()
		expect(size).toBeNil()

		controller.destroy()
	end)

	it("returns the root part cframe and the character size for a humanoid", function()
		local controller = setup()
		local _character, humanoid = controller.newCharacter()

		local cframe, size = AdorneeUtils.getBoundingBox(humanoid)

		expect(cframe).toEqual(ROOT_PART_CFRAME)
		expect(size).toEqual(CHARACTER_BOUNDING_BOX_SIZE)

		controller.destroy()
	end)

	it("returns nil for an unsupported adornee", function()
		local controller = setup()
		local folder = controller.newFolder()

		local cframe, size = AdorneeUtils.getBoundingBox(folder)

		expect(cframe).toBeNil()
		expect(size).toBeNil()

		controller.destroy()
	end)
end)

describe("AdorneeUtils.isPartOfAdornee", function()
	it("returns true when the part is the adornee", function()
		local controller = setup()
		local part = controller.newPart()

		expect(AdorneeUtils.isPartOfAdornee(part, part)).toEqual(true)

		controller.destroy()
	end)

	it("returns true for a descendant part", function()
		local controller = setup()
		local model, first = controller.newModel()

		expect(AdorneeUtils.isPartOfAdornee(model, first)).toEqual(true)

		controller.destroy()
	end)

	it("returns true for a deeply nested part", function()
		local controller = setup()
		local model = controller.newEmptyModel()

		local folder = Instance.new("Folder")
		folder.Parent = model

		local nested = controller.newPart()
		nested.Parent = folder

		expect(AdorneeUtils.isPartOfAdornee(model, nested)).toEqual(true)

		controller.destroy()
	end)

	it("returns false for an unrelated part", function()
		local controller = setup()
		local model = controller.newModel()
		local other = controller.newPart()

		expect(AdorneeUtils.isPartOfAdornee(model, other)).toEqual(false)

		controller.destroy()
	end)

	it("returns true for a part of the humanoid's character", function()
		local controller = setup()
		local _character, humanoid, rootPart = controller.newCharacter()

		expect(AdorneeUtils.isPartOfAdornee(humanoid, rootPart)).toEqual(true)

		controller.destroy()
	end)

	it("returns false for a part outside the humanoid's character", function()
		local controller = setup()
		local _character, humanoid = controller.newCharacter()
		local other = controller.newPart()

		expect(AdorneeUtils.isPartOfAdornee(humanoid, other)).toEqual(false)

		controller.destroy()
	end)

	it("returns false for a humanoid with no parent", function()
		local controller = setup()
		local humanoid = controller.newOrphanHumanoid()
		local part = controller.newPart()

		expect(AdorneeUtils.isPartOfAdornee(humanoid, part)).toEqual(false)

		controller.destroy()
	end)

	it("returns true for the parts of a tool", function()
		local controller = setup()
		local tool, handle, blade = controller.newTool()

		expect(AdorneeUtils.isPartOfAdornee(tool, handle)).toEqual(true)
		expect(AdorneeUtils.isPartOfAdornee(tool, blade)).toEqual(true)

		controller.destroy()
	end)

	it("throws for a bad part", function()
		local controller = setup()
		local part = controller.newPart()
		local folder = controller.newFolder()

		expect(function()
			AdorneeUtils.isPartOfAdornee(part, nil :: any)
		end).toThrow()

		expect(function()
			AdorneeUtils.isPartOfAdornee(part, folder :: any)
		end).toThrow()

		controller.destroy()
	end)
end)

describe("AdorneeUtils.getParts", function()
	it("returns the base part itself", function()
		local controller = setup()
		local part = controller.newPart()

		expect(AdorneeUtils.getParts(part)).toEqual({ part })

		controller.destroy()
	end)

	it("includes the descendants of a base part", function()
		local controller = setup()
		local part = controller.newPart()
		local child = controller.newPart()
		child.Parent = part

		expect(AdorneeUtils.getParts(part)).toEqual({ part, child })

		controller.destroy()
	end)

	it("returns every part of a model", function()
		local controller = setup()
		local model, first, second = controller.newModel()

		expect(AdorneeUtils.getParts(model)).toEqual({ first, second })

		controller.destroy()
	end)

	it("returns the nested parts of a model", function()
		local controller = setup()
		local model = controller.newEmptyModel()

		local folder = Instance.new("Folder")
		folder.Parent = model

		local nested = controller.newPart()
		nested.Parent = folder

		expect(AdorneeUtils.getParts(model)).toEqual({ nested })

		controller.destroy()
	end)

	it("returns the character's parts for a humanoid", function()
		local controller = setup()
		local _character, humanoid, rootPart = controller.newCharacter()

		local parts = AdorneeUtils.getParts(humanoid)

		expect(#parts).toEqual(2)
		expect(parts[1]).toEqual(rootPart)

		controller.destroy()
	end)

	it("returns an empty list for a humanoid with no parent", function()
		local controller = setup()
		local humanoid = controller.newOrphanHumanoid()

		expect(AdorneeUtils.getParts(humanoid)).toEqual({})

		controller.destroy()
	end)

	it("returns every part of a tool", function()
		local controller = setup()
		local tool, handle, blade = controller.newTool()

		expect(AdorneeUtils.getParts(tool)).toEqual({ blade, handle })

		controller.destroy()
	end)

	it("returns an empty list for an adornee with no parts", function()
		local controller = setup()
		local folder = controller.newFolder()

		expect(AdorneeUtils.getParts(folder)).toEqual({})

		controller.destroy()
	end)

	it("throws for a non-instance", function()
		expect(function()
			AdorneeUtils.getParts(nil :: any)
		end).toThrow()
	end)
end)

describe("AdorneeUtils.getAlignedSize", function()
	it("returns the bounding box size of a model", function()
		local controller = setup()
		local model = controller.newModel()

		expect(AdorneeUtils.getAlignedSize(model)).toEqual(MODEL_BOUNDING_BOX_SIZE)

		controller.destroy()
	end)

	it("returns the character bounding box size for a humanoid", function()
		local controller = setup()
		local _character, humanoid = controller.newCharacter()

		expect(AdorneeUtils.getAlignedSize(humanoid)).toEqual(CHARACTER_BOUNDING_BOX_SIZE)

		controller.destroy()
	end)

	it("returns nil for a humanoid whose parent is not a model", function()
		local controller = setup()
		local humanoid = controller.newOrphanHumanoid()
		humanoid.Parent = controller.newFolder()

		expect(AdorneeUtils.getAlignedSize(humanoid)).toBeNil()

		controller.destroy()
	end)

	it("returns nil for a humanoid with no parent", function()
		local controller = setup()
		local humanoid = controller.newOrphanHumanoid()

		expect(AdorneeUtils.getAlignedSize(humanoid)).toBeNil()

		controller.destroy()
	end)

	it("returns the size of a base part", function()
		local controller = setup()
		local part = controller.newPart(Vector3.new(4, 1, 2))

		expect(AdorneeUtils.getAlignedSize(part)).toEqual(Vector3.new(4, 1, 2))

		controller.destroy()
	end)

	it("returns the ancestor part size for an attachment", function()
		local controller = setup()
		local part = controller.newPart(Vector3.new(4, 1, 2))
		local attachment = controller.newAttachment(part)

		expect(AdorneeUtils.getAlignedSize(attachment)).toEqual(Vector3.new(4, 1, 2))

		controller.destroy()
	end)

	it("returns the handle size of a tool", function()
		local controller = setup()
		local tool = controller.newTool()

		expect(AdorneeUtils.getAlignedSize(tool)).toEqual(HANDLE_SIZE)

		controller.destroy()
	end)

	it("returns nil for a tool with no handle", function()
		local controller = setup()
		local tool = controller.newHandlelessTool()

		expect(AdorneeUtils.getAlignedSize(tool)).toBeNil()

		controller.destroy()
	end)

	it("returns nil for an unsupported adornee", function()
		local controller = setup()
		local folder = controller.newFolder()

		expect(AdorneeUtils.getAlignedSize(folder)).toBeNil()

		controller.destroy()
	end)
end)

describe("AdorneeUtils.getPartCFrame", function()
	it("returns the cframe of a base part", function()
		local controller = setup()
		local part = controller.newPart(nil, CFrame.new(1, 2, 3))

		expect(AdorneeUtils.getPartCFrame(part)).toEqual(CFrame.new(1, 2, 3))

		controller.destroy()
	end)

	it("returns the handle cframe of a tool", function()
		local controller = setup()
		local tool = controller.newTool()

		expect(AdorneeUtils.getPartCFrame(tool)).toEqual(HANDLE_CFRAME)

		controller.destroy()
	end)

	it("returns the root part cframe of a humanoid", function()
		local controller = setup()
		local _character, humanoid = controller.newCharacter()

		expect(AdorneeUtils.getPartCFrame(humanoid)).toEqual(ROOT_PART_CFRAME)

		controller.destroy()
	end)

	it("returns nil for an adornee with no part", function()
		local controller = setup()
		local folder = controller.newFolder()

		expect(AdorneeUtils.getPartCFrame(folder)).toBeNil()

		controller.destroy()
	end)

	it("throws for a non-instance", function()
		expect(function()
			AdorneeUtils.getPartCFrame(nil :: any)
		end).toThrow()
	end)
end)

describe("AdorneeUtils.getPartPosition", function()
	it("returns the position of a base part", function()
		local controller = setup()
		local part = controller.newPart(nil, CFrame.new(1, 2, 3))

		expect(AdorneeUtils.getPartPosition(part)).toEqual(Vector3.new(1, 2, 3))

		controller.destroy()
	end)

	it("returns the primary part position of a model", function()
		local controller = setup()
		local model, _first, second = controller.newModel()
		model.PrimaryPart = second

		expect(AdorneeUtils.getPartPosition(model)).toEqual(second.Position)

		controller.destroy()
	end)

	it("returns the root part position of a humanoid", function()
		local controller = setup()
		local _character, humanoid = controller.newCharacter()

		expect(AdorneeUtils.getPartPosition(humanoid)).toEqual(ROOT_PART_CFRAME.Position)

		controller.destroy()
	end)

	it("returns nil for an adornee with no part", function()
		local controller = setup()
		local folder = controller.newFolder()

		expect(AdorneeUtils.getPartPosition(folder)).toBeNil()

		controller.destroy()
	end)

	it("throws for a non-instance", function()
		expect(function()
			AdorneeUtils.getPartPosition(nil :: any)
		end).toThrow()
	end)
end)

describe("AdorneeUtils.getPartVelocity", function()
	it("returns the assembly linear velocity of a base part", function()
		local controller = setup()
		local part = controller.newPart()
		part.Anchored = false
		part.AssemblyLinearVelocity = Vector3.new(1, 2, 3)

		expect(AdorneeUtils.getPartVelocity(part)).toEqual(Vector3.new(1, 2, 3))

		controller.destroy()
	end)

	it("returns zero for an anchored part", function()
		local controller = setup()
		local part = controller.newPart()

		expect(AdorneeUtils.getPartVelocity(part)).toEqual(Vector3.zero)

		controller.destroy()
	end)

	it("returns the handle velocity of a tool", function()
		local controller = setup()
		local tool, handle = controller.newTool()
		handle.Anchored = false
		handle.AssemblyLinearVelocity = Vector3.new(0, 5, 0)

		expect(AdorneeUtils.getPartVelocity(tool)).toEqual(Vector3.new(0, 5, 0))

		controller.destroy()
	end)

	it("returns nil for an adornee with no part", function()
		local controller = setup()
		local folder = controller.newFolder()

		expect(AdorneeUtils.getPartVelocity(folder)).toBeNil()

		controller.destroy()
	end)
end)

describe("AdorneeUtils.getPart", function()
	it("returns a base part itself", function()
		local controller = setup()
		local part = controller.newPart()

		expect(AdorneeUtils.getPart(part)).toEqual(part)

		controller.destroy()
	end)

	it("returns a model's primary part", function()
		local controller = setup()
		local model, _first, second = controller.newModel()
		model.PrimaryPart = second

		expect(AdorneeUtils.getPart(model)).toEqual(second)

		controller.destroy()
	end)

	it("returns a model's first base part when there is no primary part", function()
		local controller = setup()
		local model, first = controller.newModel()

		expect(AdorneeUtils.getPart(model)).toEqual(first)

		controller.destroy()
	end)

	it("returns nil for a model with no parts", function()
		local controller = setup()
		local model = controller.newEmptyModel()

		expect(AdorneeUtils.getPart(model)).toBeNil()

		controller.destroy()
	end)

	it("returns nil for a model whose parts are not direct children", function()
		local controller = setup()
		local model = controller.newEmptyModel()

		local folder = Instance.new("Folder")
		folder.Parent = model

		local nested = controller.newPart()
		nested.Parent = folder

		expect(AdorneeUtils.getPart(model)).toBeNil()

		controller.destroy()
	end)

	it("returns the ancestor part of an attachment", function()
		local controller = setup()
		local part = controller.newPart()
		local attachment = controller.newAttachment(part)

		expect(AdorneeUtils.getPart(attachment)).toEqual(part)

		controller.destroy()
	end)

	it("returns nil for an attachment with no ancestor part", function()
		local controller = setup()
		local folder = controller.newFolder()
		local attachment = controller.newAttachment(folder)

		expect(AdorneeUtils.getPart(attachment)).toBeNil()

		controller.destroy()
	end)

	it("returns the root part of a humanoid", function()
		local controller = setup()
		local _character, humanoid, rootPart = controller.newCharacter()

		expect(AdorneeUtils.getPart(humanoid)).toEqual(rootPart)

		controller.destroy()
	end)

	it("returns nil for a humanoid with no root part", function()
		local controller = setup()
		local humanoid = controller.newOrphanHumanoid()

		expect(AdorneeUtils.getPart(humanoid)).toBeNil()

		controller.destroy()
	end)

	it("returns the handle of an accessory", function()
		local controller = setup()
		local accessory, handle = controller.newAccessory()

		expect(AdorneeUtils.getPart(accessory)).toEqual(handle)

		controller.destroy()
	end)

	it("returns the part of clothing", function()
		local controller = setup()
		local clothing, part = controller.newClothing()

		expect(AdorneeUtils.getPart(clothing)).toEqual(part)

		controller.destroy()
	end)

	it("returns the handle of a tool ahead of any other part", function()
		local controller = setup()
		local tool, handle = controller.newTool()

		expect(AdorneeUtils.getPart(tool)).toEqual(handle)

		controller.destroy()
	end)

	it("returns nil for a tool with no handle", function()
		local controller = setup()
		local tool = controller.newHandlelessTool()

		expect(AdorneeUtils.getPart(tool)).toBeNil()

		controller.destroy()
	end)

	it("returns nil for an unsupported adornee", function()
		local controller = setup()
		local folder = controller.newFolder()

		expect(AdorneeUtils.getPart(folder)).toBeNil()

		controller.destroy()
	end)

	it("throws for a non-instance", function()
		expect(function()
			AdorneeUtils.getPart(nil :: any)
		end).toThrow()
	end)
end)

describe("AdorneeUtils.getRenderAdornee", function()
	it("returns a base part itself", function()
		local controller = setup()
		local part = controller.newPart()

		expect(AdorneeUtils.getRenderAdornee(part)).toEqual(part)

		controller.destroy()
	end)

	it("returns a model itself", function()
		local controller = setup()
		local model = controller.newModel()

		expect(AdorneeUtils.getRenderAdornee(model)).toEqual(model)

		controller.destroy()
	end)

	it("returns an attachment itself", function()
		local controller = setup()
		local part = controller.newPart()
		local attachment = controller.newAttachment(part)

		expect(AdorneeUtils.getRenderAdornee(attachment)).toEqual(attachment)

		controller.destroy()
	end)

	it("returns the character of a humanoid", function()
		local controller = setup()
		local character, humanoid = controller.newCharacter()

		expect(AdorneeUtils.getRenderAdornee(humanoid)).toEqual(character)

		controller.destroy()
	end)

	it("returns nil for a humanoid with no parent", function()
		local controller = setup()
		local humanoid = controller.newOrphanHumanoid()

		expect(AdorneeUtils.getRenderAdornee(humanoid)).toBeNil()

		controller.destroy()
	end)

	it("returns the handle of an accessory", function()
		local controller = setup()
		local accessory, handle = controller.newAccessory()

		expect(AdorneeUtils.getRenderAdornee(accessory)).toEqual(handle)

		controller.destroy()
	end)

	it("returns the part of clothing", function()
		local controller = setup()
		local clothing, part = controller.newClothing()

		expect(AdorneeUtils.getRenderAdornee(clothing)).toEqual(part)

		controller.destroy()
	end)

	it("returns the handle of a tool rather than the tool", function()
		local controller = setup()
		local tool, handle = controller.newTool()

		expect(AdorneeUtils.getRenderAdornee(tool)).toEqual(handle)

		controller.destroy()
	end)

	it("returns nil for a tool with no handle", function()
		local controller = setup()
		local tool = controller.newHandlelessTool()

		expect(AdorneeUtils.getRenderAdornee(tool)).toBeNil()

		controller.destroy()
	end)

	it("returns nil for an unsupported adornee", function()
		local controller = setup()
		local folder = controller.newFolder()

		expect(AdorneeUtils.getRenderAdornee(folder)).toBeNil()

		controller.destroy()
	end)

	it("throws for a non-instance", function()
		expect(function()
			AdorneeUtils.getRenderAdornee(nil :: any)
		end).toThrow()
	end)
end)
