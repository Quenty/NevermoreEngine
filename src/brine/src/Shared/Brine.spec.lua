--!strict
--[[
	@class Brine.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Brine = require("Brine")
local BrineContext = require("BrineContext")
local BrineOptionUtils = require("BrineOptionUtils")
local Jest = require("Jest")
local Observable = require("Observable")
local StepUtils = require("StepUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("Brine.serialize", function()
	it("returns a non-empty string", function()
		local part = Instance.new("Part")
		local serialized = Brine.serialize(part)

		expect(typeof(serialized)).toEqual("string")
		expect(#serialized > 0).toEqual(true)
	end)

	it("returns deterministic output for equivalent inputs", function()
		local first = Instance.new("Folder")
		first.Name = "Same"

		local second = Instance.new("Folder")
		second.Name = "Same"

		expect((Brine.serialize(first))).toEqual((Brine.serialize(second)))
	end)

	it("returns different output for inputs that differ", function()
		local a = Instance.new("Folder")
		a.Name = "First"

		local b = Instance.new("Folder")
		b.Name = "Second"

		expect((Brine.serialize(a))).never.toEqual((Brine.serialize(b)))
	end)
end)

describe("Brine.deserialize", function()
	it("returns an instance for a valid serialized payload", function()
		local part = Instance.new("Part")
		local serialized = Brine.serialize(part)
		local result = Brine.deserialize(serialized)

		expect(typeof(result)).toEqual("Instance")
	end)

	it("preserves the class of the original instance", function()
		local original = Instance.new("Folder")
		local result = Brine.deserialize((Brine.serialize(original))) :: Folder

		expect(result.ClassName).toEqual("Folder")
	end)
end)

describe("Brine.serialize / Brine.deserialize roundtrip", function()
	describe("for a Part with non-default properties", function()
		local part = Instance.new("Part")
		part.Name = "MyPart"
		part.Size = Vector3.new(2, 4, 6)
		part.Color = Color3.new(1, 0, 0)
		part.Transparency = 0.5
		part.Anchored = true
		part.CanCollide = false

		local result = Brine.deserialize((Brine.serialize(part))) :: Part

		it("preserves the class name", function()
			expect(result.ClassName).toEqual("Part")
		end)

		it("preserves the Name", function()
			expect(result.Name).toEqual("MyPart")
		end)

		it("preserves the Size", function()
			expect(result.Size).toEqual(Vector3.new(2, 4, 6))
		end)

		it("preserves the Color", function()
			expect(result.Color).toEqual(Color3.new(1, 0, 0))
		end)

		it("preserves the Transparency", function()
			expect(result.Transparency).toEqual(0.5)
		end)

		it("preserves the Anchored flag", function()
			expect(result.Anchored).toEqual(true)
		end)

		it("preserves the CanCollide flag", function()
			expect(result.CanCollide).toEqual(false)
		end)
	end)

	describe("for ValueBase instances", function()
		it("preserves the StringValue Value", function()
			local original = Instance.new("StringValue")
			original.Value = "hello, brine"

			local result = Brine.deserialize((Brine.serialize(original))) :: StringValue

			expect(result.ClassName).toEqual("StringValue")
			expect(result.Value).toEqual("hello, brine")
		end)

		it("preserves the IntValue Value", function()
			local original = Instance.new("IntValue")
			original.Value = 42

			local result = Brine.deserialize((Brine.serialize(original))) :: IntValue

			expect(result.ClassName).toEqual("IntValue")
			expect(result.Value).toEqual(42)
		end)

		it("preserves the BoolValue Value when true", function()
			local original = Instance.new("BoolValue")
			original.Value = true

			local result = Brine.deserialize((Brine.serialize(original))) :: BoolValue

			expect(result.Value).toEqual(true)
		end)
	end)

	describe("for a Folder containing children", function()
		local folder = Instance.new("Folder")
		folder.Name = "Container"

		local first = Instance.new("Part")
		first.Name = "First"
		first.Parent = folder

		local second = Instance.new("StringValue")
		second.Name = "Second"
		second.Value = "child value"
		second.Parent = folder

		local result = Brine.deserialize((Brine.serialize(folder))) :: Folder

		it("preserves the parent name", function()
			expect(result.Name).toEqual("Container")
		end)

		it("preserves both children", function()
			expect(#result:GetChildren()).toEqual(2)
		end)

		it("preserves the Part child", function()
			local child = result:FindFirstChild("First") :: Instance
			expect(child).never.toEqual(nil)
			expect(child.ClassName).toEqual("Part")
		end)

		it("preserves the StringValue child and its Value", function()
			local child = result:FindFirstChild("Second") :: StringValue
			expect(child).never.toEqual(nil)
			expect(child.ClassName).toEqual("StringValue")
			expect(child.Value).toEqual("child value")
		end)
	end)

	describe("for nested children", function()
		it("preserves the full hierarchy", function()
			local outer = Instance.new("Folder")
			outer.Name = "Outer"

			local middle = Instance.new("Folder")
			middle.Name = "Middle"
			middle.Parent = outer

			local inner = Instance.new("StringValue")
			inner.Name = "Inner"
			inner.Value = "deep"
			inner.Parent = middle

			local result = Brine.deserialize((Brine.serialize(outer))) :: Folder
			local resolvedMiddle = result:FindFirstChild("Middle")
			local resolvedInner = if resolvedMiddle then resolvedMiddle:FindFirstChild("Inner") else nil

			expect(resolvedMiddle).never.toEqual(nil)
			expect(resolvedInner).never.toEqual(nil)
			expect((resolvedInner :: any).Value).toEqual("deep")
		end)
	end)

	describe("for an instance with attributes", function()
		it("preserves attribute values across types", function()
			local part = Instance.new("Part")
			part:SetAttribute("Count", 7)
			part:SetAttribute("Label", "tagged")
			part:SetAttribute("Enabled", true)

			local result = Brine.deserialize((Brine.serialize(part))) :: Instance

			expect(result:GetAttribute("Count")).toEqual(7)
			expect(result:GetAttribute("Label")).toEqual("tagged")
			expect(result:GetAttribute("Enabled")).toEqual(true)
		end)
	end)

	describe("for an instance with tags", function()
		it("preserves all tags", function()
			local part = Instance.new("Part")
			part:AddTag("First")
			part:AddTag("Second")

			local result = Brine.deserialize((Brine.serialize(part, {
				includeTags = true,
				includeAttributes = false,
				includeDescendants = false,
			}))) :: Instance
			local tags = result:GetTags()

			expect(#tags).toEqual(2)
			expect(table.find(tags, "First")).never.toEqual(nil)
			expect(table.find(tags, "Second")).never.toEqual(nil)
		end)
	end)

	describe("with includeDescendants = false", function()
		it("does not serialize children", function()
			local folder = Instance.new("Folder")
			folder.Name = "Empty"

			local child = Instance.new("Part")
			child.Parent = folder

			local serialized = Brine.serialize(folder, { includeDescendants = false })
			local result = Brine.deserialize(serialized, { includeDescendants = false }) :: Folder

			expect(result.Name).toEqual("Empty")
			expect(#result:GetChildren()).toEqual(0)
		end)
	end)
end)

describe("Brine.observeSerialize", function()
	it("fires a full-frame packet immediately on subscribe", function()
		local original = Instance.new("StringValue")
		original.Value = "initial"

		local emissions = {}
		local sub = Brine.observeSerialize(original):Subscribe(function(packet)
			table.insert(emissions, packet)
		end)

		expect(#emissions).toEqual(1)
		expect(typeof(emissions[1])).toEqual("string")
		expect(#emissions[1] > 0).toEqual(true)
		sub:Destroy()
	end)

	it("fires another packet when an encoded property changes", function()
		local original = Instance.new("StringValue")
		original.Value = "before"

		local emissions = {}
		local sub = Brine.observeSerialize(original):Subscribe(function(packet)
			table.insert(emissions, packet)
		end)

		local before = #emissions
		original.Value = "after"

		expect(#emissions > before).toEqual(true)
		sub:Destroy()
	end)

	it("stops firing after the subscription is destroyed", function()
		local original = Instance.new("StringValue")
		original.Value = "pre-destroy"

		local emissions = {}
		local sub = Brine.observeSerialize(original):Subscribe(function(packet)
			table.insert(emissions, packet)
		end)
		sub:Destroy()

		local before = #emissions
		original.Value = "post-destroy"

		expect(#emissions).toEqual(before)
	end)
end)

describe("Brine.observeDeserialize", function()
	it("does not emit anything for a source that never fires", function()
		local source = Observable.new(function(_sub)
			return function() end
		end)

		local emitted = false
		local sub = Brine.observeDeserialize(source :: any):Subscribe(function()
			emitted = true
		end)

		expect(emitted).toEqual(false)
		sub:Destroy()
	end)

	it("emits an instance with the upstream class and properties on the full frame", function()
		local original = Instance.new("StringValue")
		original.Name = "Source"
		original.Value = "hello observable"

		local result: any
		local sub = Brine.observeDeserialize(Brine.observeSerialize(original)):Subscribe(function(instance)
			result = instance
		end)

		expect(result).never.toEqual(nil)
		expect(result.ClassName).toEqual("StringValue")
		expect(result.Name).toEqual("Source")
		expect(result.Value).toEqual("hello observable")
		sub:Destroy()
	end)

	it("applies upstream property changes to the deserialized instance", function()
		local original = Instance.new("StringValue")
		original.Value = "first"

		local result: any
		local sub = Brine.observeDeserialize(Brine.observeSerialize(original)):Subscribe(function(instance)
			result = instance
		end)

		original.Value = "second"

		expect(result).never.toEqual(nil)
		expect(result.Value).toEqual("second")
		sub:Destroy()
	end)

	it("emits the same instance reference on each upstream packet", function()
		local original = Instance.new("StringValue")
		original.Value = "alpha"

		local seen = {}
		local sub = Brine.observeDeserialize(Brine.observeSerialize(original)):Subscribe(function(instance)
			table.insert(seen, instance)
		end)

		original.Value = "beta"
		original.Value = "gamma"

		expect(#seen >= 1).toEqual(true)
		for index = 2, #seen do
			expect(seen[index]).toEqual(seen[1])
		end
		sub:Destroy()
	end)
end)

-- Edge-case probes for the observe pipeline. These are documentation tests:
-- some are expected to fail today and the failures are the signal — they
-- highlight scenarios the change-packet pipeline does not propagate yet.
describe("Brine.observeSerialize / Brine.observeDeserialize edge cases", function()
	it("propagates a descendant added after subscribe", function()
		local original = Instance.new("Folder")

		local result
		local sub = Brine.observeDeserialize(Brine.observeSerialize(original)):Subscribe(function(instance)
			result = instance
		end)

		local child = Instance.new("StringValue")
		child.Name = "AddedAfterSubscribe"
		child.Value = "fresh"
		child.Parent = original

		expect(result).never.toEqual(nil)
		local resolvedChild = result:FindFirstChild("AddedAfterSubscribe") :: StringValue
		expect(resolvedChild).never.toEqual(nil)
		expect(resolvedChild.Value).toEqual("fresh")
		sub:Destroy()
	end)

	it("propagates a descendant removed after subscribe", function()
		local original = Instance.new("Folder")
		local child = Instance.new("StringValue")
		child.Name = "Removable"
		child.Parent = original

		local result
		local sub = Brine.observeDeserialize(Brine.observeSerialize(original)):Subscribe(function(instance)
			result = instance
		end)

		expect(result:FindFirstChild("Removable")).never.toEqual(nil)

		child.Parent = nil
		StepUtils.deferWait()

		expect(result:FindFirstChild("Removable")).toEqual(nil)

		sub:Destroy()
	end)

	it("propagates reparenting between two folders inside the source tree", function()
		local root = Instance.new("Folder")

		local first = Instance.new("Folder")
		first.Name = "First"
		first.Parent = root

		local second = Instance.new("Folder")
		second.Name = "Second"
		second.Parent = root

		local item = Instance.new("StringValue")
		item.Name = "Item"
		item.Parent = first

		local result
		local sub = Brine.observeDeserialize(Brine.observeSerialize(root)):Subscribe(function(instance)
			result = instance
		end)

		item.Parent = second
		StepUtils.deferWait()

		local resolvedFirst = result:FindFirstChild("First") :: Instance
		local resolvedSecond = result:FindFirstChild("Second") :: Instance
		expect(resolvedFirst).never.toEqual(nil)
		expect(resolvedSecond).never.toEqual(nil)
		expect(resolvedFirst:FindFirstChild("Item")).toEqual(nil)
		expect(resolvedSecond:FindFirstChild("Item")).never.toEqual(nil)
		sub:Destroy()
	end)

	it("propagates an ObjectValue.Value assignment that points inside the tree", function()
		local root = Instance.new("Folder")

		local target = Instance.new("StringValue")
		target.Name = "Target"
		target.Value = "target value"
		target.Parent = root

		local pointer = Instance.new("ObjectValue")
		pointer.Name = "Pointer"
		pointer.Parent = root

		local result
		local sub = Brine.observeDeserialize(Brine.observeSerialize(root)):Subscribe(function(instance)
			result = instance
		end)

		pointer.Value = target

		local resolvedPointer = result:FindFirstChild("Pointer") :: ObjectValue
		local resolvedTarget = result:FindFirstChild("Target")
		expect(resolvedPointer).never.toEqual(nil)
		expect(resolvedTarget).never.toEqual(nil)
		expect(resolvedPointer.Value).toEqual(resolvedTarget)
		sub:Destroy()
	end)

	it("propagates clearing an ObjectValue.Value back to nil", function()
		local root = Instance.new("Folder")

		local target = Instance.new("StringValue")
		target.Name = "Target"
		target.Parent = root

		local pointer = Instance.new("ObjectValue")
		pointer.Name = "Pointer"
		pointer.Value = target
		pointer.Parent = root

		local result
		local sub = Brine.observeDeserialize(Brine.observeSerialize(root)):Subscribe(function(instance)
			result = instance
		end)

		pointer.Value = nil

		local resolvedPointer = result:FindFirstChild("Pointer") :: ObjectValue
		expect(resolvedPointer).never.toEqual(nil)
		expect(resolvedPointer.Value).toEqual(nil)
		sub:Destroy()
	end)

	-- Tag change propagation is intentionally unsupported — there is no performant
	-- way to observe per-instance tag changes, so these scenarios are skipped.
	it.skip("propagates a tag added after subscribe", function()
		local original = Instance.new("Part")

		local result
		local sub = Brine.observeDeserialize(Brine.observeSerialize(original)):Subscribe(function(instance)
			result = instance
		end)

		original:AddTag("LateTag")

		expect(result).never.toEqual(nil)
		expect(result:HasTag("LateTag")).toEqual(true)
		sub:Destroy()
	end)

	it.skip("propagates a tag removed after subscribe", function()
		local original = Instance.new("Part")
		original:AddTag("InitialTag")

		local result
		local sub = Brine.observeDeserialize(Brine.observeSerialize(original)):Subscribe(function(instance)
			result = instance
		end)

		expect(result:HasTag("InitialTag")).toEqual(true)

		original:RemoveTag("InitialTag")

		expect(result:HasTag("InitialTag")).toEqual(false)
		sub:Destroy()
	end)

	it("propagates an attribute set after subscribe", function()
		local original = Instance.new("Part")

		local result
		local sub = Brine.observeDeserialize(Brine.observeSerialize(original)):Subscribe(function(instance)
			result = instance
		end)

		original:SetAttribute("LateAttr", 99)

		expect(result).never.toEqual(nil)
		expect(result:GetAttribute("LateAttr")).toEqual(99)
		sub:Destroy()
	end)

	it("propagates an attribute cleared back to nil after subscribe", function()
		local original = Instance.new("Part")
		original:SetAttribute("InitialAttr", 7)

		local result
		local sub = Brine.observeDeserialize(Brine.observeSerialize(original)):Subscribe(function(instance)
			result = instance
		end)

		expect(result:GetAttribute("InitialAttr")).toEqual(7)

		original:SetAttribute("InitialAttr", nil)

		expect(result:GetAttribute("InitialAttr")).toEqual(nil)
		sub:Destroy()
	end)

	it("propagates a descendant added two levels deep", function()
		local root = Instance.new("Folder")
		local middle = Instance.new("Folder")
		middle.Name = "Middle"
		middle.Parent = root

		local result
		local sub = Brine.observeDeserialize(Brine.observeSerialize(root)):Subscribe(function(instance)
			result = instance
		end)

		local grandchild = Instance.new("StringValue")
		grandchild.Name = "Grandchild"
		grandchild.Value = "deep"
		grandchild.Parent = middle

		local resolvedMiddle = result:FindFirstChild("Middle") :: Instance
		expect(resolvedMiddle).never.toEqual(nil)
		local resolvedGrandchild = resolvedMiddle:FindFirstChild("Grandchild") :: StringValue
		expect(resolvedGrandchild).never.toEqual(nil)
		expect(resolvedGrandchild.Value).toEqual("deep")
		sub:Destroy()
	end)
end)

-- Asserts directly on the wire packets emitted by observeSerialize. Each
-- emission is decoded with a fresh BrineContext so the test sees the raw
-- {type = ..., ...} packet table rather than the side effect on the receiver.
describe("Brine.observeSerialize packet shape", function()
	local function decodePacket(stream, encodedReferences)
		local context = BrineContext.new(BrineOptionUtils.defaultOptions(nil))
		return Brine._fromStream(context, stream, encodedReferences)
	end

	local function collectPackets(observable)
		local packets = {}
		local sub = observable:Subscribe(function(stream, encodedReferences)
			table.insert(packets, decodePacket(stream, encodedReferences))
		end)
		return packets, sub
	end

	it("emits exactly one 'full' packet on initial subscribe with no descendants", function()
		local original = Instance.new("StringValue")

		local packets, sub = collectPackets(Brine.observeSerialize(original))

		expect(#packets).toEqual(1)
		expect(packets[1].type).toEqual("full")
		sub:Destroy()
	end)

	it("emits exactly one 'full' packet on initial subscribe with pre-existing descendants", function()
		local root = Instance.new("Folder")
		local first = Instance.new("StringValue")
		first.Name = "First"
		first.Parent = root
		local second = Instance.new("StringValue")
		second.Name = "Second"
		second.Parent = root

		local packets, sub = collectPackets(Brine.observeSerialize(root))

		expect(#packets).toEqual(1)
		expect(packets[1].type).toEqual("full")
		sub:Destroy()
	end)

	it("does not emit any 'descendantAdded' packets on initial subscribe", function()
		local root = Instance.new("Folder")
		local child = Instance.new("StringValue")
		child.Name = "Existing"
		child.Parent = root

		local packets, sub = collectPackets(Brine.observeSerialize(root))

		for _, packet in packets do
			expect(packet.type).never.toEqual("descendantAdded")
		end
		sub:Destroy()
	end)

	it("does not emit any 'change' packets on initial subscribe with attributes pre-set", function()
		local original = Instance.new("Part")
		original:SetAttribute("Existing", 1)

		local packets, sub = collectPackets(Brine.observeSerialize(original))

		for _, packet in packets do
			expect(packet.type).never.toEqual("change")
		end
		sub:Destroy()
	end)

	it("emits a 'change' packet carrying the property that changed", function()
		local original = Instance.new("StringValue")

		local packets, sub = collectPackets(Brine.observeSerialize(original))
		local before = #packets

		original.Value = "updated"

		expect(#packets > before).toEqual(true)
		local latest = packets[#packets]
		expect(latest.type).toEqual("change")
		expect(latest.properties).never.toEqual(nil)
		expect(latest.properties.Value).toEqual("updated")
		sub:Destroy()
	end)

	it("emits a 'change' packet carrying the attribute that was set", function()
		local original = Instance.new("Part")

		local packets, sub = collectPackets(Brine.observeSerialize(original))
		local before = #packets

		original:SetAttribute("Late", 99)

		expect(#packets > before).toEqual(true)
		local latest = packets[#packets]
		expect(latest.type).toEqual("change")
		expect(latest.attributes).never.toEqual(nil)
		expect(latest.attributes.Late).toEqual(99)
		sub:Destroy()
	end)

	it("emits a 'descendantAdded' packet when a descendant is parented after subscribe", function()
		local root = Instance.new("Folder")

		local packets, sub = collectPackets(Brine.observeSerialize(root))
		local before = #packets

		local child = Instance.new("StringValue")
		child.Name = "Late"
		child.Parent = root
		StepUtils.deferWait()

		local sawDescendantAdded = false
		for index = before + 1, #packets do
			if packets[index].type == "descendantAdded" then
				sawDescendantAdded = true
				break
			end
		end
		expect(sawDescendantAdded).toEqual(true)
		sub:Destroy()
	end)

	it("emits a 'descendantRemoving' packet when a descendant is removed after subscribe", function()
		local root = Instance.new("Folder")
		local child = Instance.new("StringValue")
		child.Name = "Removable"
		child.Parent = root

		local packets, sub = collectPackets(Brine.observeSerialize(root))
		local before = #packets

		child.Parent = nil
		StepUtils.deferWait()

		local sawDescendantRemoving = false
		for index = before + 1, #packets do
			if packets[index].type == "descendantRemoving" then
				sawDescendantRemoving = true
				break
			end
		end
		expect(sawDescendantRemoving).toEqual(true)
		sub:Destroy()
	end)

	it("does not emit any 'full' packets on a property change", function()
		local original = Instance.new("StringValue")

		local packets, sub = collectPackets(Brine.observeSerialize(original))
		local before = #packets

		original.Value = "updated"

		for index = before + 1, #packets do
			expect(packets[index].type).never.toEqual("full")
		end
		sub:Destroy()
	end)
end)

-- Direct (non-Rx) repro: build the same packet shape that observeSerialize
-- emits internally and roundtrip it via _toStream / _fromStream. Used to
-- isolate whether the hang is in the encode/decode layer or in the observer.
describe("Brine direct packet roundtrip (non-Rx)", function()
	it("can roundtrip a manually-constructed 'full' packet", function()
		local original = Instance.new("StringValue")
		original.Value = "hello"

		local writeContext = BrineContext.new(BrineOptionUtils.defaultOptions(nil))
		local data = Brine._toIntermediate(writeContext, original)
		local packet = {
			type = "full",
			data = data,
		}

		local stream = Brine._toStream(writeContext, packet)

		local readContext = BrineContext.new(BrineOptionUtils.defaultOptions(nil))
		local intermediate = Brine._fromStream(readContext, stream, nil)

		expect(intermediate.type).toEqual("full")
	end)

	local function buildDescendantAddedStream()
		local root = Instance.new("Folder")
		local child = Instance.new("StringValue")
		child.Name = "Test"
		child.Parent = root

		local writeContext = BrineContext.new(BrineOptionUtils.defaultOptions(nil))
		writeContext.InstanceRegistry:InstanceToId(root)
		local data = Brine._toIntermediate(writeContext, child)
		local packet = {
			type = "descendantAdded",
			parentInstanceId = writeContext.InstanceRegistry:InstanceToId(root),
			instanceId = writeContext.InstanceRegistry:InstanceToId(child),
			data = data,
		}
		return Brine._toStream(writeContext, packet)
	end

	it("step 1: can encode a 'descendantAdded' packet", function()
		local stream = buildDescendantAddedStream()
		expect(#stream > 0).toEqual(true)
	end)

	it("step 2: can buffer.fromstring the encoded stream", function()
		local stream = buildDescendantAddedStream()
		local buff = buffer.fromstring(stream)
		expect(buffer.len(buff) > 0).toEqual(true)
	end)

	it("step 3: can DecompressBuffer the encoded stream", function()
		local stream = buildDescendantAddedStream()
		local buff = buffer.fromstring(stream)
		local EncodingService = game:GetService("EncodingService")
		local decompressed = EncodingService:DecompressBuffer(buff, Enum.CompressionAlgorithm.Zstd)
		expect(buffer.len(decompressed) > 0).toEqual(true)
	end)

	it("step 4: can BufferEncoder.read the decompressed stream", function()
		local stream = buildDescendantAddedStream()
		local buff = buffer.fromstring(stream)
		local EncodingService = game:GetService("EncodingService")
		local decompressed = EncodingService:DecompressBuffer(buff, Enum.CompressionAlgorithm.Zstd)
		local BufferEncoder = require("BufferEncoder")
		local intermediate = BufferEncoder.read(decompressed, nil, {
			allowdeduplication = true,
			allowreferences = true,
			references = nil,
			rbxenum_behavior = "compact",
		})
		expect(intermediate.type).toEqual("descendantAdded")
	end)

	it("can decode N 'descendantAdded' streams back-to-back", function()
		local N = 5
		local streams = {}
		for _ = 1, N do
			local stream = buildDescendantAddedStream()
			table.insert(streams, stream)
		end

		for _, stream in streams do
			local readContext = BrineContext.new(BrineOptionUtils.defaultOptions(nil))
			local intermediate = Brine._fromStream(readContext, stream, nil)
			expect(intermediate.type).toEqual("descendantAdded")
		end
	end)

	it("subscribe-only with 1 pre-existing descendant", function()
		local root = Instance.new("Folder")
		local first = Instance.new("StringValue")
		first.Name = "First"
		first.Parent = root

		local rawPackets = {}
		local sub = (Brine.observeSerialize(root) :: any):Subscribe(function(stream, _encodedReferences)
			table.insert(rawPackets, stream)
		end)
		sub:Destroy()

		expect(#rawPackets > 0).toEqual(true)
	end)

	it("subscribe-only with 2 pre-existing descendants", function()
		local root = Instance.new("Folder")
		local first = Instance.new("StringValue")
		first.Name = "First"
		first.Parent = root
		local second = Instance.new("StringValue")
		second.Name = "Second"
		second.Parent = root

		local rawPackets = {}
		local sub = (Brine.observeSerialize(root) :: any):Subscribe(function(stream, _encodedReferences)
			table.insert(rawPackets, stream)
		end)
		sub:Destroy()

		expect(#rawPackets > 0).toEqual(true)
	end)

	it("can _toIntermediate a folder with 2 descendants", function()
		local root = Instance.new("Folder")
		local first = Instance.new("StringValue")
		first.Name = "First"
		first.Parent = root
		local second = Instance.new("StringValue")
		second.Name = "Second"
		second.Parent = root

		local writeContext = BrineContext.new(BrineOptionUtils.defaultOptions(nil))
		local data = Brine._toIntermediate(writeContext, root)
		expect(data).never.toEqual(nil)
	end)

	it("can _toStream a folder with 2 descendants as a full frame", function()
		local root = Instance.new("Folder")
		local first = Instance.new("StringValue")
		first.Name = "First"
		first.Parent = root
		local second = Instance.new("StringValue")
		second.Name = "Second"
		second.Parent = root

		local writeContext = BrineContext.new(BrineOptionUtils.defaultOptions(nil))
		local data = Brine._toIntermediate(writeContext, root)
		local packet = { type = "full", data = data }
		local stream = Brine._toStream(writeContext, packet)
		expect(#stream > 0).toEqual(true)
	end)

	it("shared-context: encode multiple packets reusing the same writeContext", function()
		local root = Instance.new("Folder")
		local first = Instance.new("StringValue")
		first.Name = "First"
		first.Parent = root
		local second = Instance.new("StringValue")
		second.Name = "Second"
		second.Parent = root

		local writeContext = BrineContext.new(BrineOptionUtils.defaultOptions(nil))

		-- Encode root as a full frame
		local rootData = Brine._toIntermediate(writeContext, root)
		local fullPacket = { type = "full", data = rootData }
		local fullStream = Brine._toStream(writeContext, fullPacket)
		expect(#fullStream > 0).toEqual(true)

		-- Encode first child as a descendantAdded
		local firstData = Brine._toIntermediate(writeContext, first)
		local firstPacket = {
			type = "descendantAdded",
			parentInstanceId = writeContext.InstanceRegistry:InstanceToId(root),
			instanceId = writeContext.InstanceRegistry:InstanceToId(first),
			data = firstData,
		}
		local firstStream = Brine._toStream(writeContext, firstPacket)
		expect(#firstStream > 0).toEqual(true)
	end)

	it("can roundtrip a 'full' packet whose data is a parented child", function()
		local root = Instance.new("Folder")
		local child = Instance.new("StringValue")
		child.Name = "Test"
		child.Parent = root

		local writeContext = BrineContext.new(BrineOptionUtils.defaultOptions(nil))
		writeContext.InstanceRegistry:InstanceToId(root)
		local data = Brine._toIntermediate(writeContext, child)
		local packet = {
			type = "full",
			data = data,
		}

		local stream = Brine._toStream(writeContext, packet)

		local readContext = BrineContext.new(BrineOptionUtils.defaultOptions(nil))
		local intermediate = Brine._fromStream(readContext, stream, nil)

		expect(intermediate.type).toEqual("full")
	end)
end)
