--[[
	MoverBuilder.luau
	Dresses a scaled-down R15 character as a cartoon mover (Movers.Build: a big blocky
	head in the chosen style, a short body in the player's slot colour with the slot
	number, brown work gloves, chunky boots). The R15 parts stay (Roblox animates and
	collides them) but are hidden; the costume parts are welded on, massless, and never
	collide or block queries.
	The client animates carrying / slapping / throwing on top (MoverAnimator.luau).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Movers = require(ReplicatedStorage.Shared.Movers)

local MoverBuilder = {}


function MoverBuilder.Dress(character: Model, styleIndex: number, slotColor: Color3)
	local old = character:FindFirstChild("Costume")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Costume"

	-- hide the R15 body; the costume is the look
	local parts: { [string]: BasePart } = {}
	for _, d in character:GetDescendants() do
		if d:IsA("Decal") then
			if d.Name == "face" then
				d:Destroy()
			end
		elseif d:IsA("BasePart") then
			if d.Name ~= "HumanoidRootPart" then
				d.Transparency = 1
				d.CastShadow = false
				if d.Parent == character then
					parts[d.Name] = d
				end
			end
		elseif d:IsA("Accessory") or d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then
			d:Destroy()
		end
	end

	local slot = (character:GetAttribute("Slot") :: number?) or 0
	Movers.Build(folder, parts, styleIndex, slotColor, slot, true)
	folder.Parent = character
end

function MoverBuilder.Description(config: any): HumanoidDescription
	local d = Instance.new("HumanoidDescription")
	d.HeightScale = config.HeightScale
	d.WidthScale = config.WidthScale
	d.DepthScale = config.DepthScale
	d.HeadScale = 1
	d.BodyTypeScale = 0
	d.ProportionScale = 0
	return d
end

return MoverBuilder
