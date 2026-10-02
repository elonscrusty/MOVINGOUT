--[[
	Movers.luau
	The selectable mover looks (original designs). The shirt always takes the player's
	slot colour; each style adds its own hat / hair silhouette so movers stay
	distinguishable without relying on colour.
]]

local Movers = {}

Movers.Styles = {
	{ Name = "Cap", Hat = "Cap", Skin = Color3.fromRGB(255, 214, 170), Hair = Color3.fromRGB(110, 70, 40), Pants = Color3.fromRGB(60, 90, 150) },
	{ Name = "Beanie", Hat = "Beanie", Skin = Color3.fromRGB(196, 140, 100), Hair = Color3.fromRGB(40, 30, 30), Pants = Color3.fromRGB(80, 80, 90) },
	{ Name = "Hard hat", Hat = "HardHat", Skin = Color3.fromRGB(236, 190, 150), Hair = Color3.fromRGB(200, 120, 60), Pants = Color3.fromRGB(70, 110, 80) },
	{ Name = "Bun", Hat = "Bun", Skin = Color3.fromRGB(150, 100, 74), Hair = Color3.fromRGB(30, 24, 24), Pants = Color3.fromRGB(150, 70, 90) },
	{ Name = "Bunny", Hat = "Ears", Skin = Color3.fromRGB(250, 226, 200), Hair = Color3.fromRGB(240, 240, 240), Pants = Color3.fromRGB(90, 140, 190) },
	{ Name = "Chef", Hat = "Chef", Skin = Color3.fromRGB(226, 176, 136), Hair = Color3.fromRGB(60, 40, 30), Pants = Color3.fromRGB(60, 60, 70) },
	{ Name = "Headphones", Hat = "Headphones", Skin = Color3.fromRGB(120, 84, 60), Hair = Color3.fromRGB(20, 20, 24), Pants = Color3.fromRGB(110, 90, 160) },
	{ Name = "Mohawk", Hat = "Mohawk", Skin = Color3.fromRGB(255, 220, 186), Hair = Color3.fromRGB(240, 90, 160), Pants = Color3.fromRGB(50, 50, 60) },
}

function Movers.Get(i: number?)
	return Movers.Styles[math.clamp(math.floor(i or 1), 1, #Movers.Styles)]
end

return Movers
