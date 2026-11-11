--!strict
--[[
	@class Brine.restore.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Brine = require("Brine")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function snapshot(root: Instance): string
	return (Brine.serialize(root))
end

describe("Brine.checkpoint", function()
	it("returns a checkpoint for a valid instance", function()
		local part = Instance.new("Part")
		local checkpoint = Brine.checkpoint(part)

		expect(checkpoint).never.toEqual(nil)
	end)

	it("does not mutate the source tree", function()
		local root = Instance.new("Folder")
		local child = Instance.new("Part")
		child.Name = "Child"
		child.Parent = root

		local before = snapshot(root)
		Brine.checkpoint(root)
		local after = snapshot(root)

		expect(after).toEqual(before)
	end)
end)

describe("Brine.restore round-trip (serialize-equality oracle)", function()
	it("leaves an unmutated tree unchanged", function()
		local root = Instance.new("Folder")
		local part = Instance.new("Part")
		part.Parent = root

		local baseline = snapshot(root)
		local checkpoint = Brine.checkpoint(root)

		Brine.restore(root, checkpoint)

		expect(snapshot(root)).toEqual(baseline)
	end)

	it("resets a property changed from a non-default baseline", function()
		local part = Instance.new("Part")
		part.Color = Color3.new(1, 0, 0)

		local baseline = snapshot(part)
		local checkpoint = Brine.checkpoint(part)

		part.Color = Color3.new(0, 1, 0)
		Brine.restore(part, checkpoint)

		expect(snapshot(part)).toEqual(baseline)
		expect(part.Color).toEqual(Color3.new(1, 0, 0))
	end)

	it("resets a property the script set away from its default back to the default", function()
		local part = Instance.new("Part")
		local defaultTransparency = part.Transparency

		local baseline = snapshot(part)
		local checkpoint = Brine.checkpoint(part)

		part.Transparency = 0.5
		Brine.restore(part, checkpoint)

		expect(part.Transparency).toEqual(defaultTransparency)
		expect(snapshot(part)).toEqual(baseline)
	end)

	it("resets multiple properties at once", function()
		local part = Instance.new("Part")
		part.Size = Vector3.new(2, 4, 6)
		part.Anchored = true

		local baseline = snapshot(part)
		local checkpoint = Brine.checkpoint(part)

		part.Size = Vector3.new(1, 1, 1)
		part.Anchored = false
		part.CanCollide = false
		Brine.restore(part, checkpoint)

		expect(snapshot(part)).toEqual(baseline)
	end)

	it("resets a deep-nested descendant property", function()
		local root = Instance.new("Folder")
		local middle = Instance.new("Folder")
		middle.Name = "Middle"
		middle.Parent = root
		local leaf = Instance.new("StringValue")
		leaf.Name = "Leaf"
		leaf.Value = "pristine"
		leaf.Parent = middle

		local baseline = snapshot(root)
		local checkpoint = Brine.checkpoint(root)

		leaf.Value = "mutated"
		Brine.restore(root, checkpoint)

		expect(snapshot(root)).toEqual(baseline)
		expect(leaf.Value).toEqual("pristine")
	end)

	it("restores attributes: re-adds removed, resets changed, drops script-added", function()
		local part = Instance.new("Part")
		part:SetAttribute("Keep", "original")
		part:SetAttribute("Removable", 1)

		local baseline = snapshot(part)
		local checkpoint = Brine.checkpoint(part)

		part:SetAttribute("Keep", "changed")
		part:SetAttribute("Removable", nil)
		part:SetAttribute("Added", true)
		Brine.restore(part, checkpoint)

		expect(part:GetAttribute("Keep")).toEqual("original")
		expect(part:GetAttribute("Removable")).toEqual(1)
		expect(part:GetAttribute("Added")).toEqual(nil)
		expect(snapshot(part)).toEqual(baseline)
	end)

	it("restores tags: re-adds removed, drops script-added", function()
		local part = Instance.new("Part")
		part:AddTag("Original")

		local baseline = snapshot(part)
		local checkpoint = Brine.checkpoint(part)

		part:RemoveTag("Original")
		part:AddTag("Added")
		Brine.restore(part, checkpoint)

		expect(part:HasTag("Original")).toEqual(true)
		expect(part:HasTag("Added")).toEqual(false)
		expect(snapshot(part)).toEqual(baseline)
	end)

	it("restores a moved child to its pivot", function()
		local root = Instance.new("Folder")
		local part = Instance.new("Part")
		part.Name = "Mover"
		part.Anchored = true
		part:PivotTo(CFrame.new(1, 2, 3))
		part.Parent = root

		local baseline = snapshot(root)
		local checkpoint = Brine.checkpoint(root)

		part:PivotTo(CFrame.new(10, 20, 30))
		Brine.restore(root, checkpoint)

		expect(snapshot(root)).toEqual(baseline)
	end)

	it("restores a reparented child to its original parent", function()
		local root = Instance.new("Folder")
		local first = Instance.new("Folder")
		first.Name = "First"
		first.Parent = root
		local second = Instance.new("Folder")
		second.Name = "Second"
		second.Parent = root
		local item = Instance.new("Part")
		item.Name = "Item"
		item.Parent = first

		local baseline = snapshot(root)
		local checkpoint = Brine.checkpoint(root)

		item.Parent = second
		Brine.restore(root, checkpoint)

		expect(first:FindFirstChild("Item")).never.toEqual(nil)
		expect(second:FindFirstChild("Item")).toEqual(nil)
		expect(snapshot(root)).toEqual(baseline)
	end)

	it("removes a script-added child", function()
		local root = Instance.new("Folder")
		local part = Instance.new("Part")
		part.Name = "Original"
		part.Parent = root

		local baseline = snapshot(root)
		local checkpoint = Brine.checkpoint(root)

		local added = Instance.new("Part")
		added.Name = "Added"
		added.Parent = root
		Brine.restore(root, checkpoint)

		expect(root:FindFirstChild("Added")).toEqual(nil)
		expect(snapshot(root)).toEqual(baseline)
	end)

	it("recreates a destroyed child with its properties, attributes, and tags", function()
		local root = Instance.new("Folder")
		local part = Instance.new("Part")
		part.Name = "Destructible"
		-- fromRGB so the value is an 8-bit quantization fixed-point (Part.Color is Color3uint8);
		-- an arbitrary Color3.new fraction would differ by rounding across a recreate.
		part.Color = Color3.fromRGB(64, 128, 192)
		part:SetAttribute("Hp", 100)
		part:AddTag("Enemy")
		part.Parent = root

		local baseline = snapshot(root)
		local checkpoint = Brine.checkpoint(root)

		part:Destroy()
		Brine.restore(root, checkpoint)

		local restored = root:FindFirstChild("Destructible") :: Part
		expect(restored).never.toEqual(nil)
		expect(restored.Color).toEqual(Color3.fromRGB(64, 128, 192))
		expect(restored:GetAttribute("Hp")).toEqual(100)
		expect(restored:HasTag("Enemy")).toEqual(true)
		expect(snapshot(root)).toEqual(baseline)
	end)

	it("recreates a destroyed nested subtree", function()
		local root = Instance.new("Folder")
		local model = Instance.new("Model")
		model.Name = "Container"
		model.Parent = root
		local grandchild = Instance.new("StringValue")
		grandchild.Name = "Deep"
		grandchild.Value = "buried"
		grandchild.Parent = model

		local baseline = snapshot(root)
		local checkpoint = Brine.checkpoint(root)

		model:Destroy()
		Brine.restore(root, checkpoint)

		local restoredModel = root:FindFirstChild("Container")
		expect(restoredModel).never.toEqual(nil)
		local restoredDeep = (restoredModel :: Instance):FindFirstChild("Deep") :: StringValue
		expect(restoredDeep).never.toEqual(nil)
		expect(restoredDeep.Value).toEqual("buried")
		expect(snapshot(root)).toEqual(baseline)
	end)
end)

describe("Brine.restore instance identity", function()
	it("keeps the same instance reference for a survivor", function()
		local root = Instance.new("Folder")
		local part = Instance.new("Part")
		part.Name = "Survivor"
		part.Parent = root

		local checkpoint = Brine.checkpoint(root)

		part.Color = Color3.new(1, 0, 0)
		Brine.restore(root, checkpoint)

		expect(root:FindFirstChild("Survivor")).toEqual(part)
	end)

	it("produces a new instance reference for a recreated node", function()
		local root = Instance.new("Folder")
		local part = Instance.new("Part")
		part.Name = "Phoenix"
		part.Parent = root

		local checkpoint = Brine.checkpoint(root)

		part:Destroy()
		Brine.restore(root, checkpoint)

		expect(root:FindFirstChild("Phoenix")).never.toEqual(part)
	end)
end)

describe("Brine.restore references", function()
	it("preserves an ObjectValue pointing at a survivor", function()
		local root = Instance.new("Folder")
		local target = Instance.new("StringValue")
		target.Name = "Target"
		target.Parent = root
		local pointer = Instance.new("ObjectValue")
		pointer.Name = "Pointer"
		pointer.Value = target
		pointer.Parent = root

		local checkpoint = Brine.checkpoint(root)

		pointer.Value = nil
		Brine.restore(root, checkpoint)

		expect(pointer.Value).toEqual(target)
	end)

	it("resets an ObjectValue the script repointed", function()
		local root = Instance.new("Folder")
		local target = Instance.new("StringValue")
		target.Name = "Target"
		target.Parent = root
		local decoy = Instance.new("StringValue")
		decoy.Name = "Decoy"
		decoy.Parent = root
		local pointer = Instance.new("ObjectValue")
		pointer.Name = "Pointer"
		pointer.Value = target
		pointer.Parent = root

		local checkpoint = Brine.checkpoint(root)

		pointer.Value = decoy
		Brine.restore(root, checkpoint)

		expect(pointer.Value).toEqual(target)
	end)

	it("clears an ObjectValue the script set from nil", function()
		local root = Instance.new("Folder")
		local target = Instance.new("StringValue")
		target.Name = "Target"
		target.Parent = root
		local pointer = Instance.new("ObjectValue")
		pointer.Name = "Pointer"
		pointer.Parent = root

		local checkpoint = Brine.checkpoint(root)

		pointer.Value = target
		Brine.restore(root, checkpoint)

		expect(pointer.Value).toEqual(nil)
	end)

	it("repoints an ObjectValue at the recreation of a destroyed target", function()
		local root = Instance.new("Folder")
		local target = Instance.new("StringValue")
		target.Name = "Target"
		target.Value = "original"
		target.Parent = root
		local pointer = Instance.new("ObjectValue")
		pointer.Name = "Pointer"
		pointer.Value = target
		pointer.Parent = root

		local checkpoint = Brine.checkpoint(root)

		target:Destroy()
		Brine.restore(root, checkpoint)

		local recreated = root:FindFirstChild("Target")
		expect(recreated).never.toEqual(nil)
		expect(recreated).never.toEqual(target)
		expect(pointer.Value).toEqual(recreated)
	end)

	it("preserves a surviving Model.PrimaryPart", function()
		local root = Instance.new("Folder")
		local model = Instance.new("Model")
		model.Name = "Rig"
		model.Parent = root
		local primary = Instance.new("Part")
		primary.Name = "Root"
		primary.Parent = model
		model.PrimaryPart = primary

		local checkpoint = Brine.checkpoint(root)

		model.PrimaryPart = nil
		Brine.restore(root, checkpoint)

		expect(model.PrimaryPart).toEqual(primary)
	end)

	it("repoints Model.PrimaryPart at the recreation of a destroyed part", function()
		local root = Instance.new("Folder")
		local model = Instance.new("Model")
		model.Name = "Rig"
		model.Parent = root
		local primary = Instance.new("Part")
		primary.Name = "Root"
		primary.Parent = model
		model.PrimaryPart = primary

		local checkpoint = Brine.checkpoint(root)

		primary:Destroy()
		Brine.restore(root, checkpoint)

		local recreated = model:FindFirstChild("Root")
		expect(recreated).never.toEqual(nil)
		expect(model.PrimaryPart).toEqual(recreated)
	end)
end)

describe("Brine.restore idempotency and robustness", function()
	it("is idempotent -- restoring twice matches restoring once", function()
		local root = Instance.new("Folder")
		local part = Instance.new("Part")
		part.Parent = root

		local baseline = snapshot(root)
		local checkpoint = Brine.checkpoint(root)

		part.Transparency = 0.5
		Brine.restore(root, checkpoint)
		Brine.restore(root, checkpoint)

		expect(snapshot(root)).toEqual(baseline)
	end)

	it("returns to baseline regardless of how much changed", function()
		local root = Instance.new("Folder")
		local keep = Instance.new("Part")
		keep.Name = "Keep"
		keep.Parent = root

		local baseline = snapshot(root)
		local checkpoint = Brine.checkpoint(root)

		keep.Color = Color3.new(1, 0, 0)
		keep:SetAttribute("Junk", true)
		keep:AddTag("Junk")
		for index = 1, 5 do
			local litter = Instance.new("Part")
			litter.Name = "Litter" .. index
			litter.Parent = root
		end
		Brine.restore(root, checkpoint)

		expect(snapshot(root)).toEqual(baseline)
	end)

	it("reuses one checkpoint across repeated mutate/restore cycles", function()
		local root = Instance.new("Folder")
		local part = Instance.new("Part")
		part.Parent = root

		local baseline = snapshot(root)
		local checkpoint = Brine.checkpoint(root)

		part.Color = Color3.new(1, 0, 0)
		Brine.restore(root, checkpoint)
		expect(snapshot(root)).toEqual(baseline)

		part.Transparency = 0.9
		Brine.restore(root, checkpoint)
		expect(snapshot(root)).toEqual(baseline)
	end)
end)

describe("Brine.restore with lifecycle disabled (server-replicated path)", function()
	it("reconciles a survivor's property in place", function()
		local root = Instance.new("Folder")
		local part = Instance.new("Part")
		part.Parent = root

		local baseline = snapshot(root)
		local checkpoint = Brine.checkpoint(root)

		part.Transparency = 0.5
		Brine.restore(root, checkpoint, { lifecycle = false })

		expect(snapshot(root)).toEqual(baseline)
	end)

	it("still restores attributes and tags on survivors", function()
		local part = Instance.new("Part")
		part:SetAttribute("Hp", 100)
		part:AddTag("Original")

		local checkpoint = Brine.checkpoint(part)

		part:SetAttribute("Hp", 1)
		part:RemoveTag("Original")
		part:AddTag("Added")
		Brine.restore(part, checkpoint, { lifecycle = false })

		expect(part:GetAttribute("Hp")).toEqual(100)
		expect(part:HasTag("Original")).toEqual(true)
		expect(part:HasTag("Added")).toEqual(false)
	end)

	it("does not recreate a missing node -- it warns and skips", function()
		local root = Instance.new("Folder")
		local part = Instance.new("Part")
		part.Name = "Gone"
		part.Parent = root

		local checkpoint = Brine.checkpoint(root)

		part:Destroy()
		Brine.restore(root, checkpoint, { lifecycle = false })

		expect(root:FindFirstChild("Gone")).toEqual(nil)
	end)

	it("does not destroy an unexpected extra instance -- it warns and leaves it", function()
		local root = Instance.new("Folder")
		local original = Instance.new("Part")
		original.Name = "Original"
		original.Parent = root

		local checkpoint = Brine.checkpoint(root)

		local added = Instance.new("Part")
		added.Name = "Added"
		added.Parent = root
		Brine.restore(root, checkpoint, { lifecycle = false })

		expect(root:FindFirstChild("Added")).never.toEqual(nil)
	end)
end)
