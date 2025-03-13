--[=[
	Quaternion data type object

	Author: xXxMoNkEyMaNxXx

	@class QuaternionObject
]=]

local require = require(script.Parent.loader).load(script)

local Quaternion = require("Quaternion")

local pi = math.pi
local atan2 = math.atan2
local exp, log = math.exp, math.log
local cos, sin = math.cos, math.sin
local acos = math.acos

local function TYPE(x)
	local xMet=getmetatable(x)
	if type(xMet)=="table" and xMet.__type~=nil then
		return xMet.__type
	else
		return type(x)
	end
end

local Q={}
local metatable={__type="quaternion"}
local alt={"w","x","y","z"}
function metatable.__index(q,i)
	return q[alt[i]]
end

local function new(w,x,y,z)
	return setmetatable({w=w or 1,x=x or 0,y=y or 0,z=z or 0},metatable)
end
Q.new=new

local function fromCFrame(cframe)
	return new(Quaternion.QuaternionFromCFrame(cframe))
end
Q.fromCFrame = fromCFrame

local function toCFrame(q, position)
	local x, y, z = 0, 0, 0
	if position then
		x, y, z = position.x, position.y, position.z
	end
	return CFrame.new(x, y, z, Quaternion.QuaternionToCFrame(q))
end
Q.toCFrame = toCFrame

local function inv(q)
	local w,x,y,z=q.w,q.x,q.y,q.z
	local m=w*w+x*x+y*y+z*z
	if m>0 then
		return new(w/m,-x/m,-y/m,-z/m)
	else
		return new(0)
	end
end
Q.inv=inv

--Unary minus; -q
local function unm(q)
	return new(-q.w,-q.x,-q.y,-q.z)
end
metatable.__unm=unm
Q.unm=unm
local function add(q0,q1)
	local t0,t1=TYPE(q0),TYPE(q1)
	if t0=="quaternion" and t1=="quaternion" then
		return new(q0.w+q1.w,q0.x+q1.x,q0.y+q1.y,q0.z+q1.z)
	elseif t0=="quaternion" and t1=="number" then
		return new(q0.w+q1,q0.x,q0.y,q0.z)
	elseif t0=="number" and t1=="quaternion" then
		return new(q0+q1.w,q1.x,q1.y,q1.z)
	else
		return nil
	end
end
metatable.__add = add
Q.add = add
local function sub(q0, q1)
	local t0, t1 = TYPE(q0), TYPE(q1)
	if t0 == "quaternion" and t1 == "quaternion" then
		return new(q0.w - q1.w, q0.x - q1.x, q0.y - q1.y, q0.z - q1.z)
	elseif t0 == "quaternion" and t1 == "number" then
		return new(q0.w - q1, q0.x, q0.y, q0.z)
	elseif t0 == "number" and t1 == "quaternion" then
		return new(q0 - q1.w, -q1.x, -q1.y, -q1.z)
	else
		return nil
	end
end
metatable.__sub = sub
Q.sub = sub
local function mul(q0, q1)
	local t0, t1 = TYPE(q0), TYPE(q1)
	if t0 == "quaternion" and t1 == "quaternion" then
		local w0, x0, y0, z0, w1, x1, y1, z1 = q0.w, q0.x, q0.y, q0.z, q1.w, q1.x, q1.y, q1.z
		return new(
			w0 * w1 - x0 * x1 - y0 * y1 - z0 * z1,
			w0 * x1 + x0 * w1 + y0 * z1 - z0 * y1,
			w0 * y1 - x0 * z1 + y0 * w1 + z0 * x1,
			w0 * z1 + x0 * y1 - y0 * x1 + z0 * w1
		)
	elseif t0 == "quaternion" and t1 == "number" then
		return new(q0.w * q1, q0.x * q1, q0.y * q1, q0.z * q1)
	elseif t0 == "number" and t1 == "quaternion" then
		return new(q0 * q1.w, q0 * q1.x, q0 * q1.y, q0 * q1.z)
	else
		return nil
	end
end
metatable.__mul = mul
Q.mul = mul
local function div(q0, q1)
	local t0, t1 = TYPE(q0), TYPE(q1)
	if t0 == "quaternion" and t1 == "quaternion" then
		local w0, x0, y0, z0, w1, x1, y1, z1 = q0.w, q0.x, q0.y, q0.z, q1.w, q1.x, q1.y, q1.z
		local m1 = w1 * w1 + x1 * x1 + y1 * y1 + z1 * z1
		if m1 > 0 then
			-- This is the quaternion that gets you from q1 to q0 from q1: mul(inv(q1),q0).
			-- (quaternion division is actually ambiguous)
			return new(
				(w1 * w0 + x1 * x0 + y1 * y0 + z1 * z0) / m1,
				(w1 * x0 - x1 * w0 - y1 * z0 + z1 * y0) / m1,
				(w1 * y0 + x1 * z0 - y1 * w0 - z1 * x0) / m1,
				(w1 * z0 - x1 * y0 + y1 * x0 - z1 * w0) / m1
			)
		else
			return new(0)
		end
	elseif t0 == "quaternion" and t1 == "number" then
		return new(q0.w / q1, q0.x / q1, q0.y / q1, q0.z / q1)
	elseif t0 == "number" and t1 == "quaternion" then
		local w1, x1, y1, z1 = q1.w, q1.x, q1.y, q1.z
		local m1 = w1 * w1 + x1 * x1 + y1 * y1 + z1 * z1
		if m1 > 0 then
			local m = q0 / m1
			return new(m * w1, -m * x1, -m * y1, -m * z1)
		else
			return new(0)
		end
	else
		return nil
	end
end
metatable.__div = div
Q.div = div
local function pow(q0,q1)
	local t0, t1 = TYPE(q0), TYPE(q1)
	if t0=="quaternion" and t1=="quaternion" then
		local w0, x0, y0, z0 = q0.w, q0.x, q0.y, q0.z
		local vv = x0 * x0 + y0 * y0 + z0 * z0
		local mm = w0 * w0 + vv
		if mm > 0 then
			if vv > 0 then
				local m = mm ^ 0.5
				local s = acos(w0 / m) / vv ^ 0.5
				w0, x0, y0, z0 = log(m), x0 * s, y0 * s, z0 * s
			else
				w0, x0, y0, z0 = log(mm) / 2, 0, 0, 0
			end
		else
			w0, x0, y0, z0 = -math.huge, 0, 0, 0
		end
		local w1, x1, y1, z1 = q1.w, q1.x, q1.y, q1.z
		local m = exp(w0 * w1 - x0 * x1 - y0 * y1 - z0 * z1)
		local x, y, z =
			w0 * x1 + x0 * w1 + y0 * z1 - z0 * y1,
			w0 * y1 - x0 * z1 + y0 * w1 + z0 * x1,
			w0 * z1 + x0 * y1 - y0 * x1 + z0 * w1
		vv = x * x + y * y + z * z
		if vv > 0 then
			local v = vv ^ 0.5
			local s = m * sin(v) / v
			return new(m * cos(v), x * s, y * s, z * s)
		else
			return new(m)
		end
	elseif t0=="quaternion" and t1=="number" then
		local w, x, y, z = q0.w, q0.x, q0.y, q0.z
		local vv = x * x + y * y + z * z
		if vv > 0 then
			local v = vv ^ 0.5
			local m = (w * w + vv) ^ (q1 / 2)
			local theta = q1 * atan2(v, w)
			local s = m * sin(theta) / v
			return new(m * cos(theta), x * s, y * s, z * s)
		else
			if w < 0 then
				local m = (-w) ^ q1
				local s = m * sin(pi * q1) * 0.57735026918962576450914878050196 --3^-0.5
				return new(m * cos(pi * q1), s, s, s)
			else
				return new(w ^ q1)
			end
		end
	elseif t0=="number" and t1=="quaternion" then
		local w, x, y, z = q1.w, q1.x, q1.y, q1.z
		if q0 > 0 then
			local m = q0 ^ w
			local vv = x * x + y * y + z * z
			if vv > 0 then
				local v = vv ^ 0.5
				local s = m * sin(v) / v
				return new(m * cos(v), x * s, y * s, z * s)
			else
				return new(m)
			end
		elseif q0 < 0 then --Not a good idea to use this.
			local m = (-q0) ^ w
			local vv = x * x + y * y + z * z
			local mc, ms = m * cos(pi * w), m * sin(pi * w)
			if vv > 0 then
				local v = vv ^ 0.5
				local c, s = cos(v), sin(v) / v
				local vc, vs = mc * s, ms * c * 0.57735026918962576450914878050196
				-- This is probably TERRIBLY wrong, but raising a negative number to the power of a quaternion is ill-defined in the
				-- first place.
				return new(mc * c - ms * s, vc * x + vs, vc * y + vs, vc * z + vs)
			else
				-- No idea why this is broken! Weird edge case!
				warn("Hitting weird quaternion edge case!")
				return new(nil, nil, nil, nil)
				--return new(c,s,s,s)
			end
		elseif w * w + x * x + y * y + z * z > 0 then
			return new(0)
		else
			return new() --anyeting to da powa of 0 is 1 dud
		end
	else
		return nil
	end
end
metatable.__pow=pow
Q.pow=pow
local function length(q)
	local w,x,y,z=q.w,q.x,q.y,q.z
	return (w*w+x*x+y*y+z*z)^0.5
end
metatable.__len=length
Q.length=length
Q.magnitude=length
local function Qtostring(q,precision)
	precision=precision or 3
	return string.sub(string.rep(string.format(", %."..precision.."f", q.w,q.x,q.y,q.z), 4), 3)
end
metatable.__tostring=Qtostring
Q.tostring=Qtostring

local function Qlog(q)
	local w,x,y,z=q.w,q.x,q.y,q.z
	local vv=x*x+y*y+z*z
	local mm=w*w+vv
	if mm>0 then
		if vv>0 then
			local m=mm^0.5
			local s=acos(w/m)/vv^0.5
			return new(log(m),x*s,y*s,z*s)
		else
			return new(log(mm)/2)--lim v->0 x/v*acos(a/(a*a+v*v)^0.5)=0 when a is positive
		end
	else
		return new(-math.huge)
	end
end
Q.log=Qlog

local function Qexp(q)
	local m=exp(q.w)
	local x,y,z=q.x,q.y,q.z
	local vv=x*x+y*y+z*z
	if vv>0 then
		local v=vv^0.5
		local s=m*sin(v)/v
		return new(m*cos(v),x*s,y*s,z*s)
	else
		return new(m)
	end
end
Q.exp=Qexp

local function Qnormalize(q)
	local w,x,y,z=q.w,q.x,q.y,q.z
	local mm=w*w+x*x+y*y+z*z
	if mm>0 then
		local m=mm^0.5
		return new(w/m,x/m,y/m,z/m)
	else
		return new()
	end
end
Q.normalize=Qnormalize
Q.unit=Qnormalize

local function Qsqrt(q)
	local w,x,y,z=q.w,q.x,q.y,q.z
	local vv=x*x+y*y+z*z
	if vv>0 then
		local m=(w*w+vv)^0.5
		local s=((m-w)/(2*vv))^0.5
		return new(((m+w)/2)^0.5,x*s,y*s,z*s)
	else
		return new((w*w)^0.25)
	end
end
Q.sqrt=Qsqrt

return Q