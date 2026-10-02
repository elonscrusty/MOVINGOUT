--[[
	FurnitureData.luau
	Physical stats of every furniture kind. The visual models are built on the server by
	FurnitureModels.luau; the collider is always one box of exactly Size.

	Class   Light / Medium / Heavy: carrying lift, carry speed and throw rules (Config).
	Mass    relative mass units (Light 1-3, Medium 4-8, Heavy 10-20). These are
	        reconstruction defaults, multiplied by MassScale into Roblox mass.
	Holders how many movers can grip it at once.
	Sound   impact sound family: Wood, Soft, Metal, Glass.
	Size    collider box in studs (X width, Y height, Z depth) at rotation 0.
]]

local FurnitureData = {
	MassScale = 4,
}

type Kind = {
	Name: string,
	Class: string,
	Mass: number,
	Holders: number,
	Sound: string,
	Size: Vector3,
	Friction: number?,
	Elasticity: number?,
}

local K: { [string]: Kind } = {
	-- light
	Box = { Name = "Box", Class = "Light", Mass = 2, Holders = 1, Sound = "Soft", Size = Vector3.new(2.3, 2.3, 2.3) },
	BoxTall = { Name = "Tall box", Class = "Light", Mass = 2.5, Holders = 1, Sound = "Soft", Size = Vector3.new(2, 3.1, 2) },
	Lamp = { Name = "Lamp", Class = "Light", Mass = 1.5, Holders = 1, Sound = "Metal", Size = Vector3.new(1.6, 4.6, 1.6) },
	Stool = { Name = "Stool", Class = "Light", Mass = 1.5, Holders = 1, Sound = "Wood", Size = Vector3.new(1.8, 2.4, 1.8) },
	SideTable = { Name = "Side table", Class = "Light", Mass = 2.5, Holders = 1, Sound = "Wood", Size = Vector3.new(2.2, 2.3, 2.2) },
	Plant = { Name = "Plant", Class = "Light", Mass = 2, Holders = 1, Sound = "Soft", Size = Vector3.new(1.8, 3.4, 1.8) },
	BeachBall = { Name = "Beach ball", Class = "Light", Mass = 1, Holders = 1, Sound = "Soft", Size = Vector3.new(2.2, 2.2, 2.2), Elasticity = 0.7 },
	Flamingo = { Name = "Pool flamingo", Class = "Light", Mass = 1, Holders = 1, Sound = "Soft", Size = Vector3.new(2.8, 3.4, 2), Elasticity = 0.5 },
	Microwave = { Name = "Microwave", Class = "Light", Mass = 3, Holders = 1, Sound = "Metal", Size = Vector3.new(2.4, 1.6, 1.8) },
	Vase = { Name = "Vase", Class = "Light", Mass = 1.5, Holders = 1, Sound = "Glass", Size = Vector3.new(1.4, 2.4, 1.4) },
	Candelabra = { Name = "Candelabra", Class = "Light", Mass = 1.5, Holders = 1, Sound = "Metal", Size = Vector3.new(1.6, 3, 1.6) },
	Parcel = { Name = "Parcel", Class = "Light", Mass = 2, Holders = 1, Sound = "Soft", Size = Vector3.new(2.6, 1.8, 2.2) },
	BoxSmall = { Name = "Small box", Class = "Light", Mass = 1, Holders = 1, Sound = "Soft", Size = Vector3.new(1.8, 1.5, 1.8) },
	BoxFlat = { Name = "Flat box", Class = "Light", Mass = 1.5, Holders = 1, Sound = "Soft", Size = Vector3.new(2.8, 1.2, 2.2) },
	Toaster = { Name = "Toaster", Class = "Light", Mass = 1.5, Holders = 1, Sound = "Metal", Size = Vector3.new(1.8, 1.4, 1.2) },
	Guitar = { Name = "Guitar", Class = "Light", Mass = 1.5, Holders = 1, Sound = "Wood", Size = Vector3.new(1.6, 0.6, 4.2) },
	PlantSmall = { Name = "Cactus", Class = "Light", Mass = 1, Holders = 1, Sound = "Soft", Size = Vector3.new(1.4, 2.2, 1.4) },
	Bin = { Name = "Bin", Class = "Light", Mass = 1.5, Holders = 1, Sound = "Metal", Size = Vector3.new(1.6, 2.4, 1.6) },
	RugRoll = { Name = "Rolled rug", Class = "Light", Mass = 2, Holders = 1, Sound = "Soft", Size = Vector3.new(4.4, 1, 1) },
	Fan = { Name = "Fan", Class = "Light", Mass = 1.5, Holders = 1, Sound = "Metal", Size = Vector3.new(1.6, 3.6, 1.2) },
	Suitcase = { Name = "Suitcase", Class = "Light", Mass = 2, Holders = 1, Sound = "Soft", Size = Vector3.new(2.6, 0.9, 1.8) },

	-- medium
	Chair = { Name = "Chair", Class = "Medium", Mass = 4, Holders = 2, Sound = "Wood", Size = Vector3.new(2.6, 4, 2.6) },
	TV = { Name = "TV", Class = "Medium", Mass = 5, Holders = 2, Sound = "Glass", Size = Vector3.new(3.6, 2.7, 1.4) },
	CoffeeTable = { Name = "Coffee table", Class = "Medium", Mass = 5, Holders = 2, Sound = "Wood", Size = Vector3.new(5, 2, 3) },
	Armchair = { Name = "Armchair", Class = "Medium", Mass = 7, Holders = 2, Sound = "Soft", Size = Vector3.new(3.6, 3.6, 3.4) },
	DeckChair = { Name = "Deck chair", Class = "Medium", Mass = 4, Holders = 2, Sound = "Wood", Size = Vector3.new(2.6, 2.2, 6) },
	Grill = { Name = "Barbecue", Class = "Medium", Mass = 7, Holders = 2, Sound = "Metal", Size = Vector3.new(3, 3.6, 2.2) },
	Cooler = { Name = "Cooler", Class = "Medium", Mass = 5, Holders = 2, Sound = "Soft", Size = Vector3.new(3, 2, 2) },
	Crate = { Name = "Crate", Class = "Medium", Mass = 6, Holders = 2, Sound = "Wood", Size = Vector3.new(3.4, 3.4, 3.4) },
	Barrel = { Name = "Barrel", Class = "Medium", Mass = 6, Holders = 2, Sound = "Metal", Size = Vector3.new(2.6, 3.6, 2.6) },
	Mirror = { Name = "Mirror", Class = "Medium", Mass = 4, Holders = 2, Sound = "Glass", Size = Vector3.new(2.6, 5, 0.8) },
	Toolbox = { Name = "Toolbox", Class = "Medium", Mass = 5, Holders = 2, Sound = "Metal", Size = Vector3.new(2.8, 1.8, 1.6) },
	Dresser = { Name = "Dresser", Class = "Medium", Mass = 8, Holders = 2, Sound = "Wood", Size = Vector3.new(4.4, 3.6, 2.2) },

	-- heavy
	Sofa = { Name = "Sofa", Class = "Heavy", Mass = 16, Holders = 2, Sound = "Soft", Size = Vector3.new(9, 4, 3.6) },
	Bed = { Name = "Bed", Class = "Heavy", Mass = 18, Holders = 2, Sound = "Soft", Size = Vector3.new(5.6, 2.8, 8.6) },
	Fridge = { Name = "Fridge", Class = "Heavy", Mass = 14, Holders = 2, Sound = "Metal", Size = Vector3.new(3.2, 7, 3.2) },
	DiningTable = { Name = "Dining table", Class = "Heavy", Mass = 12, Holders = 2, Sound = "Wood", Size = Vector3.new(7.5, 3.2, 4.2) },
	Piano = { Name = "Piano", Class = "Heavy", Mass = 20, Holders = 2, Sound = "Wood", Size = Vector3.new(6, 5, 2.6) },
	Clock = { Name = "Grandfather clock", Class = "Heavy", Mass = 11, Holders = 2, Sound = "Wood", Size = Vector3.new(2.4, 8, 1.8) },
	Coffin = { Name = "Coffin", Class = "Heavy", Mass = 13, Holders = 2, Sound = "Wood", Size = Vector3.new(3, 2.2, 8) },
	Bookcase = { Name = "Bookcase", Class = "Heavy", Mass = 12, Holders = 2, Sound = "Wood", Size = Vector3.new(4.4, 7, 1.8) },
	Washer = { Name = "Washing machine", Class = "Heavy", Mass = 12, Holders = 2, Sound = "Metal", Size = Vector3.new(3, 3.6, 3) },
	BigCrate = { Name = "Big crate", Class = "Heavy", Mass = 14, Holders = 2, Sound = "Wood", Size = Vector3.new(5, 4, 4) },
	Sunbed = { Name = "Sun bed", Class = "Heavy", Mass = 10, Holders = 2, Sound = "Wood", Size = Vector3.new(3, 2, 8) },
}

FurnitureData.Kinds = K

function FurnitureData.Get(kind: string): Kind
	local k = K[kind]
	assert(k, "unknown furniture kind " .. tostring(kind))
	return k
end

return FurnitureData
