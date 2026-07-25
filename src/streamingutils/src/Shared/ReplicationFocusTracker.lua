--!strict
--[=[
	Keeps a single hidden part positioned at a point and added as a [Player] replication focus, so
	Roblox streams world content around that point. Reuses one part across position updates and
	removes the focus (and destroys the part) on cleanup.

	The subject is duck-typed at runtime -- anything with `AddReplicationFocus` /
	`RemoveReplicationFocus` methods -- so tests pass a plain table; the production caller always
	passes a [Player].

	@class ReplicationFocusTracker
]=]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local Maid = require("Maid")
local PlayerMock = require("PlayerMock")

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
	self:_addReplicationFocus(part)
end

--[=[
	Whether a focus part currently exists (i.e. [ReplicationFocusTracker:SetPosition] has run).
	@return boolean
]=]
function ReplicationFocusTracker.IsActive(self: ReplicationFocusTracker): boolean
	return self._part ~= nil
end

function ReplicationFocusTracker.Destroy(self: ReplicationFocusTracker): ()
	local part = self._part
	if part then
		self:_removeReplicationFocus(part)
	end

	self._maid:DoCleaning()
	self._part = nil
end

-- Mock-safe: a PlayerMock's backing Folder has no AddReplicationFocus method; call its stand-in.
function ReplicationFocusTracker._addReplicationFocus(self: ReplicationFocusTracker, part: BasePart): ()
	if PlayerMock.isMock(self._subject) then
		PlayerMock.addReplicationFocus(self._subject, part)
	else
		self._subject:AddReplicationFocus(part)
	end
end

function ReplicationFocusTracker._removeReplicationFocus(self: ReplicationFocusTracker, part: BasePart): ()
	if PlayerMock.isMock(self._subject) then
		PlayerMock.removeReplicationFocus(self._subject, part)
	else
		self._subject:RemoveReplicationFocus(part)
	end
end

return ReplicationFocusTracker
