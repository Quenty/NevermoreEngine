--!strict
--[=[
	Keeps a single hidden part positioned at a point and assigned as a [Player]'s
	`ReplicationFocus`, so Roblox streams world content around that point. Reuses one part
	across position updates and clears the focus (and destroys the part) on cleanup.

	The subject is duck-typed at runtime -- anything with a settable `ReplicationFocus` -- so tests
	pass a plain table; the production caller always passes a [Player].

	@class ReplicationFocusTracker
]=]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local Maid = require("Maid")

local FOCUS_PART_NAME = "StreamingCinematicFocus"

local ReplicationFocusTracker = {}
ReplicationFocusTracker.ClassName = "ReplicationFocusTracker"
ReplicationFocusTracker.__index = ReplicationFocusTracker

export type ReplicationFocusTracker = typeof(setmetatable(
	{} :: {
		_subject: Player,
		_maid: Maid.Maid,
		_part: BasePart?,
	},
	{} :: typeof({ __index = ReplicationFocusTracker })
))

function ReplicationFocusTracker.new(subject: Player): ReplicationFocusTracker
	local self: ReplicationFocusTracker = setmetatable({} :: any, ReplicationFocusTracker)

	self._subject = assert(subject, "No subject")
	self._maid = Maid.new()

	return self
end

--[=[
	Moves the focus to `position`, creating and assigning the part on first call.
	@param position Vector3
]=]
function ReplicationFocusTracker.SetPosition(self: ReplicationFocusTracker, position: Vector3): ()
	assert(typeof(position) == "Vector3", "Bad position")

	local existing = self._part
	if existing then
		existing.Position = position
		return
	end

	local part = Instance.new("Part")
	part.Name = FOCUS_PART_NAME
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.Archivable = false
	part.Position = position
	part.Parent = Workspace.Terrain

	self._part = part
	self._maid:GiveTask(part)
	self._subject.ReplicationFocus = part
end

--[=[
	Whether a focus part currently exists (i.e. [ReplicationFocusTracker:SetPosition] has run).
	@return boolean
]=]
function ReplicationFocusTracker.IsActive(self: ReplicationFocusTracker): boolean
	return self._part ~= nil
end

function ReplicationFocusTracker.Destroy(self: ReplicationFocusTracker): ()
	self._subject.ReplicationFocus = nil
	self._maid:DoCleaning()
	self._part = nil
end

return ReplicationFocusTracker
