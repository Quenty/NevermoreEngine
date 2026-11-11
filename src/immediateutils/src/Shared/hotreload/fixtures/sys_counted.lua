local destroyCount = 0

local module = {
	system = function() end,
}

function module.Destroy()
	destroyCount += 1
end

function module.getDestroyCount()
	return destroyCount
end

return module
