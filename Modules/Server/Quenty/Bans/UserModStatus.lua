--- Encapsulates the mod status retrieved from server
-- @classmod UserModStatus
-- @author Quenty

local UserModStatus = {}
UserModStatus.ClassName = "UserModStatus"
UserModStatus.__index = UserModStatus

function UserModStatus.new(data)
	local self = setmetatable({}, UserModStatus)

	self._data = data or error("No data")

	return self
end

function UserModStatus:IsBanned()
	return self._data.banned
end

function UserModStatus:IsModerator()
	return self._data.is_moderator
end

function UserModStatus:_getLatestBanEntry()
	for _, item in pairs(self._data.entry) do
		if item.is_valid then
			return item
		end
	end

	warn("[UserModStatus] - Unable to find latest ban entry that is valid")
	return nil
end

function UserModStatus:GetBanReasonAsText()
	local entry = self:_getLatestBanEntry()

	local reason = tostring(entry and entry.reason)
	local duration = tostring(entry and entry.duration_text or "[error]")
	local endsIn = tostring(entry and entry.end_in_text or "[error]")

	local bannedMessage = "You are banned for '%s' for %s. Your ban will lift %s. (Appeal code: #%d)"
	return bannedMessage:format(reason, duration, endsIn, entry.ban_id or -1)
end

return UserModStatus