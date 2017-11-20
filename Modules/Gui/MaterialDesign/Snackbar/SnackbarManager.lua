local SnackbarManager = {}
SnackbarManager.ClassName = "SnackbarManager"
SnackbarManager.__index = SnackbarManager

-- Guarantees that only one snackbar is visible at once
function SnackbarManager.new()
	local self = {}
	setmetatable(self, SnackbarManager)

	self.CurrentSnackbar = nil

	return self
end

--- Cleanup existing snackbar
function SnackbarManager:ShowSnackbar(Snackbar)

	assert(Snackbar, "Must send a Snackbar")

	if self.CurrentSnackbar == Snackbar and self.CurrentSnackbar.Visible then
		Snackbar:Dismiss()
	else
		local DismissedSnackbar = false

		if self.CurrentSnackbar then
			if self.CurrentSnackbar.Visible then
				self.CurrentSnackbar:Dismiss()
				self.CurrentSnackbar = nil
				DismissedSnackbar = true
			end
		end

		self.CurrentSnackbar = Snackbar
		if DismissedSnackbar then
			delay(Snackbar.FadeTime, function()
				if self.CurrentSnackbar == Snackbar then
					Snackbar:Show()
				end
			end)
		else
			Snackbar:Show()
		end
	end
end

--- Automatically makes a snackbar and then adds it.
function SnackbarManager:MakeSnackbar(Parent, Text, Options)
	local NewSnackbar = DraggableSnackbar.new(Parent, Text, nil, Options)
	self:ShowSnackbar(NewSnackbar)
end

return SnackbarManager