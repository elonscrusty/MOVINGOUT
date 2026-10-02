--[[
	Shapes.luau
	Roblox draws a Ball part as a perfect sphere sized by its smallest side. For the
	oval shapes the art needs (heads, eyes, cushions, tree crowns), a non-uniform ball is
	turned into a block with a Sphere SpecialMesh, which stretches to the full size.
	Only use it on parts whose collision shape doesn't matter (or where a box is fine).
]]

local Shapes = {}

function Shapes.Ball(p: BasePart)
	local s = p.Size
	if math.abs(s.X - s.Y) < 0.01 and math.abs(s.Y - s.Z) < 0.01 then
		(p :: Part).Shape = Enum.PartType.Ball
		return
	end
	(p :: Part).Shape = Enum.PartType.Block
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
end

return Shapes
