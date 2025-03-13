--[=[
	Server-side snackbar service. See [SnackbarServiceClient] for more details.

	@server
	@class SnackbarService
]=]

local require = require(script.Parent.loader).load(script)

local _ServiceBag = require("ServiceBag")

local SnackbarService = {}
SnackbarService.ServiceName = "SnackbarService"

function SnackbarService:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")


end

return SnackbarService