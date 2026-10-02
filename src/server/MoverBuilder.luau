--[[
	MoverBuilder.luau
	Dresses a scaled-down R15 character as a cartoon mover: an oversized round head with
	big eyes, a round body in the player's slot colour, mitten hands, chunky shoes and a
	style hat. The R15 parts stay (Roblox animates and collides them) but are hidden; the
	costume parts are welded on, massless, and never collide or block queries.
	The client animates carrying / slapping / throwing on top (MoverAnimator.luau).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Movers = require(ReplicatedStorage.Shared.Movers)
local Shapes = require(ReplicatedStorage.Shared.Shapes)

local MoverBuilder = {}

local V = Vector3.new
local CF = CFrame.new
local rad = math.rad
local Ball = Enum.PartType.Ball
local Cyl = Enum.PartType.Cylinder
local smooth = Enum.Material.SmoothPlastic

local function piece(folder: Folder, anchor: BasePart, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = "Costume"
	p.Size = size
	if shape == Ball then
		Shapes.Ball(p)
	elseif shape then
		p.Shape = shape
	end
	p.Color = color
	p.Material = material or smooth
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = anchor.CFrame * offset
	local w = Instance.new("Weld")
	w.Part0 = anchor
	w.Part1 = p
	w.C0 = offset
	w.Parent = p
	p.Parent = folder
	return p
end

local function hat(folder: Folder, head: BasePart, style: any, r: number, slotColor: Color3)
	local top = r * 0.9
	local kind = style.Hat
	if kind == "Cap" then
		piece(folder, head, V(r * 1.95, r * 1.2, r * 1.95), CF(0, top * 0.55, 0), slotColor:Lerp(Color3.new(1, 1, 1), 0.25), Ball)
		piece(folder, head, V(r * 1.3, 0.18, r * 0.9), CF(0, top * 0.5, -r * 0.95), slotColor:Lerp(Color3.new(1, 1, 1), 0.25))
	elseif kind == "Beanie" then
		piece(folder, head, V(r * 2.02, r * 1.3, r * 2.02), CF(0, top * 0.5, 0), Color3.fromRGB(240, 200, 70), Ball, Enum.Material.Fabric)
		piece(folder, head, V(r * 0.6, r * 0.6, r * 0.6), CF(0, top * 1.15, 0), Color3.fromRGB(250, 250, 250), Ball, Enum.Material.Fabric)
	elseif kind == "HardHat" then
		piece(folder, head, V(r * 2, r * 1.2, r * 2), CF(0, top * 0.6, 0), Color3.fromRGB(250, 200, 40), Ball)
		piece(folder, head, V(0.18, r * 2.4, r * 2.4), CF(0, top * 0.35, 0) * CFrame.Angles(0, 0, rad(90)), Color3.fromRGB(250, 200, 40), Cyl)
	elseif kind == "Bun" then
		piece(folder, head, V(r * 2.04, r * 1.4, r * 2.04), CF(0, top * 0.45, r * 0.06), style.Hair, Ball)
		piece(folder, head, V(r * 0.9, r * 0.9, r * 0.9), CF(0, top * 1.2, r * 0.2), style.Hair, Ball)
	elseif kind == "Ears" then
		piece(folder, head, V(r * 2.02, r * 1.2, r * 2.02), CF(0, top * 0.55, 0.05), style.Hair, Ball)
		for _, sx in { -1, 1 } do
			piece(folder, head, V(r * 0.45, r * 1.6, r * 0.3), CF(sx * r * 0.45, top * 1.5, 0) * CFrame.Angles(0, 0, rad(-sx * 10)), Color3.fromRGB(250, 250, 250), Ball)
			piece(folder, head, V(r * 0.25, r * 1.1, r * 0.32), CF(sx * r * 0.45, top * 1.5, -0.03) * CFrame.Angles(0, 0, rad(-sx * 10)), Color3.fromRGB(250, 180, 200), Ball)
		end
	elseif kind == "Chef" then
		piece(folder, head, V(r * 0.9, r * 1.6, r * 1.6), CF(0, top * 0.95, 0) * CFrame.Angles(0, 0, rad(90)), Color3.fromRGB(250, 250, 250), Cyl)
		piece(folder, head, V(r * 1.9, r * 1, r * 1.9), CF(0, top * 1.45, 0), Color3.fromRGB(250, 250, 250), Ball)
		piece(folder, head, V(r * 2.02, r * 1.1, r * 2.02), CF(0, top * 0.35, 0.05), style.Hair, Ball)
	elseif kind == "Headphones" then
		piece(folder, head, V(r * 2.02, r * 1.2, r * 2.02), CF(0, top * 0.5, 0.05), style.Hair, Ball)
		piece(folder, head, V(0.3, r * 2.3, 0.35), CF(0, top * 0.75, 0), Color3.fromRGB(40, 40, 46))
		for _, sx in { -1, 1 } do
			piece(folder, head, V(0.5, r * 0.8, r * 0.8), CF(sx * r * 1.0, 0, 0) * CFrame.Angles(0, 0, 0), slotColor, Cyl)
		end
	elseif kind == "Mohawk" then
		piece(folder, head, V(r * 0.35, r * 0.9, r * 1.8), CF(0, top * 1.05, 0.1), style.Hair, Ball)
	end
end

function MoverBuilder.Dress(character: Model, styleIndex: number, slotColor: Color3)
	local old = character:FindFirstChild("Costume")
	if old then
		old:Destroy()
	end
	local style = Movers.Get(styleIndex)
	local folder = Instance.new("Folder")
	folder.Name = "Costume"

	-- hide the R15 body; the costume is the look
	for _, d in character:GetDescendants() do
		if d:IsA("Decal") then
			if d.Name == "face" then
				d:Destroy()
			end
		elseif d:IsA("BasePart") then
			if d.Name ~= "HumanoidRootPart" then
				d.Transparency = 1
				d.CastShadow = false
			end
		elseif d:IsA("Accessory") or d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then
			d:Destroy()
		end
	end

	local function p(name: string): BasePart?
		return character:FindFirstChild(name) :: BasePart?
	end

	local head = p("Head")
	local upper = p("UpperTorso")
	local lower = p("LowerTorso")
	local skin = style.Skin
	local pants = style.Pants
	local shirt = slotColor
	local shoe = Color3.fromRGB(60, 50, 46)
	local glove = Color3.fromRGB(250, 250, 250)

	if head then
		local r = 1.45 -- head radius: big cartoon head
		local headOffset = CF(0, 0.85, 0)
		local h = piece(folder, head, V(r * 2, r * 1.9, r * 1.95), headOffset, skin, Ball)
		h.Name = "BigHead"
		local front = -r * 0.92
		for _, sx in { -1, 1 } do
			piece(folder, head, V(0.62, 0.78, 0.4), headOffset * CF(sx * 0.48, 0.18, front + 0.08), Color3.fromRGB(255, 255, 255), Ball)
			piece(folder, head, V(0.36, 0.5, 0.3), headOffset * CF(sx * 0.46, 0.14, front - 0.04), Color3.fromRGB(30, 30, 36), Ball)
			piece(folder, head, V(0.12, 0.12, 0.1), headOffset * CF(sx * 0.42, 0.26, front - 0.17), Color3.new(1, 1, 1), Ball)
			piece(folder, head, V(0.45, 0.25, 0.2), headOffset * CF(sx * 0.85, -0.25, front + 0.3), Color3.fromRGB(250, 150, 150), Ball)
			piece(folder, head, V(0.5, 0.6, 0.4), headOffset * CF(sx * r * 0.98, 0, 0), skin, Ball) -- ears
		end
		piece(folder, head, V(0.55, 0.45, 0.5), headOffset * CF(0, -0.12, front - 0.12), skin:Lerp(Color3.fromRGB(220, 120, 100), 0.25), Ball)
		piece(folder, head, V(0.7, 0.16, 0.2), headOffset * CF(0, -0.55, front + 0.12), Color3.fromRGB(120, 50, 50), Ball)
		hat(folder, h, style, r, slotColor)
		-- hair fringe for hats that show the head top
		if style.Hat == "Mohawk" then
			piece(folder, h, V(r * 2.02, r * 0.9, r * 2.02), CF(0, r * 0.35, 0.15), skin:Lerp(style.Hair, 0.3), Ball)
		end
	end

	if upper then
		piece(folder, upper, V(2.3, 2.1, 1.9), CF(0, -0.05, 0), shirt, Ball)
		-- a number badge on the chest so colour is never the only identifier
		local badge = piece(folder, upper, V(0.9, 0.9, 0.1), CF(0.35, 0.25, -0.92), Color3.fromRGB(255, 255, 255), nil)
		badge.Name = "Badge"
		local gui = Instance.new("SurfaceGui")
		gui.Name = "BadgeGui"
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 60
		gui.Parent = badge
		local label = Instance.new("TextLabel")
		label.Name = "Number"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(40, 40, 50)
		label.Text = tostring(character:GetAttribute("Slot") or "")
		label.Parent = gui
		-- overall straps
		for _, sx in { -1, 1 } do
			piece(folder, upper, V(0.3, 1.5, 0.15), CF(sx * 0.55, 0.05, -0.92), pants)
		end
	end
	if lower then
		piece(folder, lower, V(2.1, 1.3, 1.8), CF(0, 0.05, 0), pants, Ball)
	end

	for _, side in { "Left", "Right" } do
		local ua = p(side .. "UpperArm")
		local la = p(side .. "LowerArm")
		local hand = p(side .. "Hand")
		local ul = p(side .. "UpperLeg")
		local ll = p(side .. "LowerLeg")
		local foot = p(side .. "Foot")
		if ua then
			piece(folder, ua, V(0.75, ua.Size.Y + 0.25, 0.75), CF(0, 0, 0), shirt, nil)
			piece(folder, ua, V(0.85, 0.85, 0.85), CF(0, ua.Size.Y / 2, 0), shirt, Ball)
		end
		if la then
			piece(folder, la, V(0.6, la.Size.Y + 0.2, 0.6), CF(), skin)
		end
		if hand then
			local mitt = piece(folder, hand, V(0.95, 0.95, 0.95), CF(0, -0.15, 0), glove, Ball)
			mitt.Name = side .. "Mitt"
		end
		if ul then
			piece(folder, ul, V(0.85, ul.Size.Y + 0.2, 0.85), CF(), pants)
		end
		if ll then
			piece(folder, ll, V(0.75, ll.Size.Y + 0.15, 0.75), CF(), pants)
		end
		if foot then
			piece(folder, foot, V(1, 0.6, 1.45), CF(0, 0.05, -0.2), shoe, Ball)
		end
	end

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
