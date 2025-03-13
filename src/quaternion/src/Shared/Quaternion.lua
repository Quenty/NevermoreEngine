--[=[
	Quaternion data type
	Author: xXxMoNkEyMaNxXx

	@class Quaternion
]=]

--[[
God, grant me the serenity to accept the things I cannot change,
The courage to change the things I can,
And wisdom to know the difference.

I cannot change most of this.
]]

local pi = math.pi
local tau = 2*pi
local cos,sin = math.cos,math.sin
local sqrt = math.sqrt
local atan2 = math.atan2
local max = math.max

local vec3 = Vector3.new
local CF = CFrame.new

local iv = vec3()
local iq = {1,0,0,0}

local lib = {}

local function BezierPosition(x0,x1,v0,v1,t)
	local T=1-t
	return x0*T*T*T+(3*x0+v0)*t*T*T+(3*x1-v1)*t*t*T+x1*t*t*t
end
lib.BezierPosition = BezierPosition

local function BezierVelocity(x0,x1,v0,v1,t)
	local T=1-t
	return v0*T*T+2*(3*(x1-x0)-(v1+v0))*t*T+v1*t*t
end
lib.BezierVelocity = BezierVelocity

local function Qmul(q1,q2) -- Multiply
	local w1,x1,y1,z1,w2,x2,y2,z2=q1[1],q1[2],q1[3],q1[4],q2[1],q2[2],q2[3],q2[4]
	return {w1*w2-x1*x2-y1*y2-z1*z2,w1*x2+x1*w2+y1*z2-z1*y2,w1*y2-x1*z2+y1*w2+z1*x2,w1*z2+x1*y2-y1*x2+z1*w2}
end
lib.Qmul = Qmul

local function Qinv(q)--Inverse. (q^-1)
	local w,x,y,z=q[1],q[2],q[3],q[4]
	local m=w*w+x*x+y*y+z*z
	if m>0 then
		return {w/m,-x/m,-y/m,-z/m}
	else
		return {0,0,0,0}
	end
end
lib.Qinv = Qinv

local function Qpow(q,exponent,choice)
	choice=choice or 0
	local w,x,y,z=q[1],q[2],q[3],q[4]
	local vv=x*x+y*y+z*z
	if vv>0 then
		--Convert to polar form and exponentiate (all in one go)
		local v=sqrt(vv)
		local m=(w*w+vv)^(0.5*exponent)
		local theta=exponent*(atan2(v,w)+tau*choice)--swag
		local s=m*sin(theta)/v
		return {m*cos(theta),x*s,y*s,z*s}
	else--This is a regular number.  srs.  lol.
		if w<0 then--Quaternions, umad? u dun fool me nub
			local m=(-w)^exponent
			local s=m*sin(pi*exponent)*sqrt(3)/3
			return {m*cos(pi*exponent),s,s,s}
		else
			return {w^exponent,0,0,0}
		end
	end
end
lib.Qpow = Qpow

local function QuaternionFromCFrame(cf)
	local _,_,_,m00,m01,m02,m10,m11,m12,m20,m21,m22=cf:components()
	local trace=m00+m11+m22
	if trace>0 then
		local s=sqrt(1+trace)
		local recip=0.5/s
		return s*0.5,(m21-m12)*recip,(m02-m20)*recip,(m10-m01)*recip
	else
		local big=max(m00,m11,m22)
		if big==m00 then
			local s=sqrt(1+m00-m11-m22)
			local recip=0.5/s
			return (m21-m12)*recip,0.5*s,(m10+m01)*recip,(m02+m20)*recip
		elseif big==m11 then
			local s=sqrt(1-m00+m11-m22)
			local recip=0.5/s
			return (m02-m20)*recip,(m10+m01)*recip,0.5*s,(m21+m12)*recip
		elseif big==m22 then
			local s=sqrt(1-m00-m11+m22)
			local recip=0.5/s
			return (m10-m01)*recip,(m02+m20)*recip,(m21+m12)*recip,0.5*s
		else
			return nil,nil,nil,nil
		end
	end
end
lib.QuaternionFromCFrame = QuaternionFromCFrame

local function SlerpQuaternions(q0, q1, t)
	return Qmul(Qpow(Qmul(q1, Qinv(q0)), t), q0)
end
lib.SlerpQuaternions = SlerpQuaternions

local function QuaternionToCFrame(q)
	local w,x,y,z=q[1],q[2],q[3],q[4]
	local xs,ys,zs=x+x,y+y,z+z
	local wx,wy,wz=w*xs,w*ys,w*zs
	local xx,xy,xz,yy,yz,zz=x*xs,x*ys,x*zs,y*ys,y*zs,z*zs
	return 1-(yy+zz),xy-wz,xz+wy,xy+wz,1-(xx+zz),yz-wx,xz-wy,yz+wx,1-(xx+yy)
end
lib.QuaternionToCFrame = QuaternionToCFrame

local function BezierRotation(q0,q1,w0,w1,t)
	local _30,_31,_32,_33=q0,Qmul(q0,w0),Qmul(q1,Qinv(w1)),q1
	local _20,_21,_22=
		Qmul(_30,Qpow(Qmul(Qinv(_30),_31),t)),
		Qmul(_31,Qpow(Qmul(Qinv(_31),_32),t)),
		Qmul(_32,Qpow(Qmul(Qinv(_32),_33),t))
	local _10,_11=Qmul(_20,Qpow(Qmul(Qinv(_20),_21),t)),Qmul(_21,Qpow(Qmul(Qinv(_21),_22),t))
	local _00=Qmul(_10,Qpow(Qmul(Qinv(_10),_11),t))
	return _00
end
lib.BezierRotation = BezierRotation

local function BezierAngularV(q0,q1,w0,w1,t)
	local _30,_31,_32,_33=q0,Qmul(q0,w0),Qmul(q1,Qinv(w1)),q1
	local _20,_21,_22=Qmul(Qinv(_30),_31),Qmul(Qinv(_31),_32),Qmul(Qinv(_32),_33)
	local _10,_11=Qmul(_20,Qpow(Qmul(Qinv(_20),_21),t)),Qmul(_21,Qpow(Qmul(Qinv(_21),_22),t))
	local _00=Qmul(_10,Qpow(Qmul(Qinv(_10),_11),t))
	return _00
end
lib.BezierAngularV = BezierAngularV

--Regular tweening
local TweenData={}
-- stylua: ignore
local Tweens=setmetatable({},{
	__index=function(_,i)
		local data=TweenData[i]
		if data then
			local timeNow,t0,t1=tick(),data.t0,data.t1
			if timeNow>t0 and timeNow<t1 then
				return BezierPosition(data.x0,data.x1,data.v0,data.v1,(timeNow-t0)/(t1-t0))
			elseif timeNow>=t1 then
				return data.x1
			elseif timeNow<=t0 then--Whatever.
				return data.x0
			end
		end

		return nil
	end,
	__newindex=function(_,i,v)
		local data=TweenData[i]
		if data then
			local timeNow,t0,t1=tick(),data.t0,data.t1
			local x0,x1,v0,v1
			if timeNow>t0 and timeNow<t1 then
				local dt=t1-t0
				local t=(timeNow-t0)/dt
				x0,x1,v0,v1=
					BezierPosition(data.x0,data.x1,data.v0,data.v1,t),
					v,
					BezierVelocity(data.x0,data.x1,data.v0,data.v1,t)/dt,
					v*0
			elseif timeNow>=t1 then
				x0,x1,v0,v1=data.x1,v,v*0,v*0
			elseif timeNow<=t0 then
				x0,x1,v0,v1=data.x0,v,v*0,v*0
			end
			local dt,time=1,data.time
			local timeType=type(time)
			if timeType=="number" then
				dt=time
			elseif timeType=="function" then
				dt=time(x0,x1,v0,v1)
			end
			data.x0,data.x1,data.v0,data.v1,data.t0,data.t1,data.tweening=x0,x1,dt*v0,dt*v1,timeNow,timeNow+dt,true
		else
			print("A value named "..tostring(i).." has not yet been created.")
		end

		return nil
	end,
})
lib.Tweens = Tweens

--Quaternion tweening
local QuaternionTweenData = {}
-- stylua: ignore
local QuaternionTweens=setmetatable({},{
	__index=function(_,i)
		local data=QuaternionTweenData[i]
		if data then
			local timeNow,t0,t1=tick(),data.t0,data.t1
			if timeNow>t0 and timeNow<t1 then
				return BezierRotation(data.q0,data.q1,data.w0,data.w1,(timeNow-t0)/(t1-t0))
			elseif timeNow>=t1 then
				return data.q1
			elseif timeNow<=t0 then--Whatever.
				return data.q0
			end
		end

		return nil
	end,
	__newindex=function(_,i,v)
		local data=QuaternionTweenData[i]
		if data then
			local timeNow,t0,t1=tick(),data.t0,data.t1
			local q0,q1,w0,w1
			if timeNow>t0 and timeNow<t1 then
				local dt=t1-t0
				local t=(timeNow-t0)/dt
				q0,q1,w0,w1=
					BezierRotation(data.q0,data.q1,data.w0,data.w1,t),
					v,
					Qpow(BezierAngularV(data.q0,data.q1,data.w0,data.w1,t),1/dt),
					iq
			elseif timeNow>=t1 then
				q0,q1,w0,w1=data.q1,v,iq,iq
			elseif timeNow<=t0 then
				q0,q1,w0,w1=data.q0,v,iq,iq
			end
			if data.autoChoose then
				if q0[1]*q1[1]+q0[2]*q1[2]+q0[3]*q1[3]+q0[4]*q1[4]<0 then
					q1={-q1[1],-q1[2],-q1[3],-q1[4]}
				end
			end
			local dt,time=1,data.time
			local timeType=type(time)
			if timeType=="number" then
				dt=time
			elseif timeType=="function" then
				dt=time(q0,q1,w0,w1)
			end
			data.q0,data.q1,data.w0,data.w1,data.t0,data.t1,data.tweening=q0,q1,Qpow(w0,dt),Qpow(w1,dt),timeNow,timeNow+dt,true
		else
			print("A value named "..tostring(i).." has not yet been created.")
		end
	end,
})
lib.QuaternionTweens = QuaternionTweens

--CFrame tweening
local CFrameTweenData = {}
-- stylua: ignore
local CFrameTweens=setmetatable({},{
	__index=function(_,i)
		local data=CFrameTweenData[i]
		if data then
			local timeNow,t0,t1=tick(),data.t0,data.t1
			if timeNow>t0 and timeNow<t1 then
				local t=(timeNow-t0)/(t1-t0)
				local p=BezierPosition(data.x0,data.x1,data.v0,data.v1,t)
				return CF(p.x,p.y,p.z,QuaternionToCFrame(BezierRotation(data.q0,data.q1,data.w0,data.w1,t)))
			elseif timeNow>=t1 then
				return data.c1
			elseif timeNow<=t0 then--Whatever.
				return data.c0
			end
		end

		return nil
	end,
	__newindex=function(_,i,v)
		local data=CFrameTweenData[i]
		if data then
			local timeNow,t0,t1=tick(),data.t0,data.t1
			local x0,x1,v0,v1,q0,q1,w0,w1
			if timeNow>t0 and timeNow<t1 then
				local dt=t1-t0
				local t=(timeNow-t0)/dt
				x0,x1,v0,v1,q0,q1,w0,w1=
					BezierPosition(data.x0,data.x1,data.v0,data.v1,t),
					v.p,
					BezierVelocity(data.x0,data.x1,data.v0,data.v1,t)/dt,
					iv,
					BezierRotation(data.q0,data.q1,data.w0,data.w1,t),
					{QuaternionFromCFrame(v)},
					Qpow(BezierAngularV(data.q0,data.q1,data.w0,data.w1,t),1/dt),
					iq
			elseif timeNow>=t1 then
				x0,x1,v0,v1,q0,q1,w0,w1=data.x1,v.p,iv,iv,data.q1,{QuaternionFromCFrame(v)},iq,iq
			elseif timeNow<=t0 then
				x0,x1,v0,v1,q0,q1,w0,w1=data.x0,v.p,iv,iv,data.q0,{QuaternionFromCFrame(v)},iq,iq
			end
			local a1,b1,c1,d1,a2,b2,c2,d2
				=q0[1]-q1[1],q0[2]-q1[2],q0[3]-q1[3],q0[4]-q1[4],q0[1]+q1[1],q0[2]+q1[2],q0[3]+q1[3],q0[4]+q1[4]
			if a1*a1+b1*b1+c1*c1+d1*d1>a2*a2+b2*b2+c2*c2+d2*d2 then
				q1={-q1[1],-q1[2],-q1[3],-q1[4]}
			end
			local c0=CF(x0.x,x0.y,x0.z,QuaternionToCFrame(q0))
			local dt,time=1,data.time
			local timeType=type(time)
			if timeType=="number" then
				dt=time
			elseif timeType=="function" then
				dt=time(c0,v,x0,x1,v0,v1,q0,q1,w0,w1)--lol
			end
			data.c0,data.c1,data.x0,data.x1,data.v0,data.v1,data.q0,data.q1,data.w0,data.w1,data.t0,data.t1,data.tweening
				=c0,v,x0,x1,v0*dt,v1*dt,q0,q1,Qpow(w0,dt),Qpow(w1,dt),timeNow,timeNow+dt,true
		else
			print("A value named "..tostring(i).." has not yet been created.")
		end

		return nil
	end,
})
lib.CFrameTweens = CFrameTweens

local function updateTweens(timeNow)
	for _, data in next,TweenData do
		local f,t0,t1=data.update,data.t0,data.t1
		if f then
			if data.tweening then
				if timeNow>t0 and timeNow<t1 then
					f(BezierPosition(data.x0,data.x1,data.v0,data.v1,(timeNow-t0)/(t1-t0)))
				elseif timeNow>=t1 then
					f(data.x1)
					data.tweening=false
				end
			elseif timeNow<=t0 then
				data.tweening=true
			end
		end
	end
end
lib.updateTweens = updateTweens

local function updateQuaternionTweens(timeNow)
	for _, data in next,QuaternionTweenData do
		local f,t0,t1=data.update,data.t0,data.t1
		if f then
			if data.tweening then
				if timeNow>t0 and timeNow<t1 then
					f(BezierRotation(data.q0,data.q1,data.w0,data.w1,(timeNow-t0)/(t1-t0)))
				elseif timeNow>=t1 then
					f(data.q1)
					data.tweening=false
				end
			elseif timeNow<=t0 then
				data.tweening=true
			end
		end
	end
end
lib.updateQuaternionTweens = updateQuaternionTweens

local function updateCFrameTweens(timeNow)
	for _, data in next,CFrameTweenData do
		local f,t0,t1=data.update,data.t0,data.t1
		if f then
			if data.tweening then
				if timeNow>t0 and timeNow<t1 then
					local t=(timeNow-t0)/(t1-t0)
					local p=BezierPosition(data.x0,data.x1,data.v0,data.v1,t)
					f(CF(p.x,p.y,p.z,QuaternionToCFrame(BezierRotation(data.q0,data.q1,data.w0,data.w1,t))))
				elseif timeNow>=t1 then
					f(data.c1)
					data.tweening=false
				end
			elseif timeNow<=t0 then
				data.tweening=true
			end
		end
	end
end
lib.updateCFrameTweens = updateCFrameTweens

local function newTween(name,value,updateFunction,time)
	TweenData[name]={
		x0=value,x1=value,v0=value*0,v1=value*0,t0=0,t1=tick(),time=time or 1,update=updateFunction,tweening=false
	}
	if updateFunction then
		updateFunction(value)--Just in case c:
	end
end
lib.newTween = newTween

local function newQuaternionTween(name,value,updateFunction,time,autoChoose)
	QuaternionTweenData[name]={
		q0=value,
		q1=value,
		w0=iq,
		w1=iq,
		t0=0,
		t1=tick(),
		time=time or 1,
		update=updateFunction,
		tweening=false,
		autoChoose=autoChoose==nil or autoChoose
	}
	if updateFunction then
		updateFunction(value)--Just in case c:
	end
end
lib.newQuaternionTween = newQuaternionTween

local function newCFrameTween(name,value,updateFunction,time)
	local q={QuaternionFromCFrame(value)}
	CFrameTweenData[name]={
		c0=value,
		c1=value,
		x0=value.p,
		x1=value.p,
		v0=iv,
		v1=iv,
		q0=q,
		q1=q,
		w0=iq,
		w1=iq,
		t0=0,
		t1=tick(),
		time=time or 1,
		update=updateFunction,
		tweening=false
	}
	if updateFunction then
		updateFunction(value)--Just in case c:
	end
end
lib.newCFrameTween = newCFrameTween

return lib
