-- Credit to Stravant

local Signal = {}

function Signal.new()
	local sig = {}
	
	local mSignaler = Instance.new('BindableEvent')
	
	local mArgData, mArgDataCount
	
	function sig:fire(...)
		mArgData = {...}
		mArgDataCount = select('#', ...)
		mSignaler:Fire()
	end
	
	function sig:connect(f)
		if not f then error("connect(nil)", 2) end
		return mSignaler.Event:connect(function()
			f(unpack(mArgData, 1, mArgDataCount))
		end)
	end
	
	function sig:wait()
		mSignaler.Event:wait()
		assert(mArgData, "Missing arg data, likely due to :TweenSize/Position corrupting threadrefs.")
		return unpack(mArgData, 1, mArgDataCount)
	end

	function sig:Destroy()
		mSignaler:Destroy()
		mArgData      = nil
		mArgDataCount = nil
		mSignaler     = nil
	end
	
	return sig
end

return Signal
