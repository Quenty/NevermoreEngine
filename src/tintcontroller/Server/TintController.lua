--[=[
	Dummy class providing a convenient wrapper over [TintControllerUtils].
	All color changing is done on the client, in [TintControllerClient].

	@server
	@class TintController
]=]

local require = require(script.Parent.loader).load(script)

local TintControllerUtils = require("TintControllerUtils")
local BaseObject = require("BaseObject")

local TintController = setmetatable({}, BaseObject)
TintController.ClassName = "TintController"
TintController.__index = TintController

--[=[
	Construct a new controller on the server.

	@param adornee Instance
	@return TintControllerClient
]=]
function TintController.new(adornee: Instance)
	local self = setmetatable(BaseObject.new(adornee), TintController)

	return self
end

--[=[
	Sets the tint of this controller, and all of its tagged tintable descendants.

	@param tint any
]=]
function TintController:SetTint(tint: any)
	TintControllerUtils.setTint(self._obj, tint)
end

--[=[
	Sets the blending of this controller's tint. Typically ranges between 0 and 1.

	@param blend number
]=]
function TintController:SetTintBlend(blend: number)
	TintControllerUtils.setTintBlend(self._obj, blend)
end

return TintController
