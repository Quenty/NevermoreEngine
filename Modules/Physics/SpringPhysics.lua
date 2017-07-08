-- @author Trey Reynolds, modified by Quenty

local Physics={}

local cos			=math.cos
local sin			=math.sin
local tick			=tick
local v3			=Vector3.new

Physics.Spring		={}
Physics.NumberSpring={}
Physics.VectorSpring={}

function Physics.Spring.New(Initial)
	local x0 = tick()                     -- tick0
	local t  = Initial or 0	              -- Target
	local p0 = Initial or 0	              -- Position0
	local v0 = Initial and 0*Initial or 0 -- Velocity0
	local d  = 1                          -- Damper [0, 1]
	local s  = 1                          -- Force (also a time scale :D) [0,infinity]

	local Spring

	local function PositionVelocity(tick)
		local x	     = tick-x0
		local c0     = p0-t
		if s==0 then
			return p0, 0
		elseif d<1 then
			local c	 = (1-d*d)^0.5
			local c1 = (v0/s+d*c0)/c
			local co = cos(c*s*x)
			local si = sin(c*s*x)
			local e  = 2.718281828459045^(d*s*x)
			return     t+(c0*co+c1*si)/e,
			           s*((c*c1-d*c0)*co-(c*c0+d*c1)*si)/e
		else
			local c1 = v0/s+c0
			local e  = 2.718281828459045^(s*x)
			return     t+(c0+c1*s*x)/e,
			           s*(c1-c0-c1*s*x)/e
		end
	end

	Spring=setmetatable({
		Impulse=function(_,v)
			Spring.Velocity=Spring.Velocity+v
		end;
		TimeSkip=function(self, Delta)
			local tick = tick()
			local p,v = PositionVelocity(tick+Delta)
			p0 = p
			v0 = v
			x0 = tick
		end;
	},{
		__index=function(_,Index)
			if Index=="Value" or Index=="Position" or Index=="p" then
				local p,v=PositionVelocity(tick())
				return p
			elseif Index=="Velocity" or Index=="v" then
				local p,v=PositionVelocity(tick())
				return v
			elseif Index=="Target" or Index=="t" then
				return t
			elseif Index=="Damper" or Index=="d" then
				return d
			elseif Index=="Speed" or Index=="s" then
				return s
			else
				error(Index.." is not a valid member of Spring")
			end
		end;
		__newindex=function(_,Index,Value)
			local tick		=tick()
			if Index=="Value" or Index=="Position" or Index=="p" then
				local p,v = PositionVelocity(tick)
				p0        = Value
				v0        = v
			elseif Index=="Velocity" or Index=="v" then
				local p,v = PositionVelocity(tick)
				p0        = p
				v0        = Value
			elseif Index=="Target" or Index=="t" then
				p0,v0		=PositionVelocity(tick)
				t			=Value
			elseif Index=="Damper" or Index=="d" then
				p0,v0		=PositionVelocity(tick)
				d			=Value<0 and 0 or Value<1 and Value or 1
			elseif Index=="Speed" or Index=="s" then
				p0,v0		=PositionVelocity(tick)
				s			=Value<0 and 0 or Value
			else
				error(Index.." is not a valid member of Spring")
			end
			x0				=tick
		end;
	})
	return Spring
end

function Physics.NumberSpring.New(Initial)
	return Physics.Spring.New(Initial)
end

function Physics.VectorSpring.New(Initial)
	return Physics.Spring.New(Initial or v3())
end


return Physics