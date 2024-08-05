--[=[
	Server-side snackbar service. See [SnackbarServiceClient] for more details.

	@server
	@class SnackbarService
]=]

local require = require(script.Parent.loader).load(script)

local SnackbarService = {}
SnackbarService.ServiceName = "SnackbarService"

function SnackbarService:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")


end

return SnackbarService