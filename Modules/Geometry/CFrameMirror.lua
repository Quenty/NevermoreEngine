local CFrameMirror = {}
CFrameMirror.__index = CFrameMirror
CFrameMirror.ClassName = "CFrameMirror"

function CFrameMirror.new()
	local self = {}
	setmetatable(self, CFrameMirror)
	
	return self
end


function CFrameMirror:SetCFrame(ReflectOver)
	-- This is the CFrame that things are reflected over. Reflects over the
	-- x axis. 
	
	self.ReflectOver = ReflectOver
end

function CFrameMirror:Reflect(ReflectCFrame)
	local ReflectOver = self.ReflectOver or error("No reflect over")
	
	-- Algorithm from wingman8
	local RelativeCFrame = ReflectOver:toObjectSpace(ReflectCFrame) -- Move to object space.
	local x,   y,     z,
	      r00, r01, r02,
	      r10, r11, r12,
	      r20, r21, r22 = RelativeCFrame:components()

	-- Reflect over the x axis.
	local Mirror = CFrame.new(-x,y,z,
		r00,  -r01, -r02,
		-r10, r11,  r12,
		-r20, r21,  r22)

	return ReflectOver:toWorldSpace(Mirror)
end

function CFrameMirror:ReflectVector(Vector)
	local ReflectOver = self.ReflectOver
	
	local Relative    = self.ReflectOver:vectorToObjectSpace(Vector)
	local Mirror      = Vector3.new(-Relative.x, Relative.y, Relative.z)
	
	return ReflectOver:vectorToWorldSpace(Mirror)
end

function CFrameMirror:ReflectPoint(Point)
	local ReflectOver = self.ReflectOver
	
	local Relative    = ReflectOver:pointToObjectSpace(Point)
	local Mirror      = Vector3.new(-Relative.x, Relative.y, Relative.z)
	
	return ReflectOver:pointToWorldSpace(Mirror)
end


function CFrameMirror:ReflectRay(MirrorMeRay)
	local MirrorOrigin = self:ReflectPoint(MirrorMeRay.Origin)
	local MirrorDirection = self:ReflectVector(MirrorMeRay.Direction)
	
	return Ray.new(MirrorOrigin, MirrorDirection)
end



return CFrameMirror