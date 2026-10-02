-- Loads a level data module (src/shared/Levels/*.luau) outside Roblox and prints it as
-- JSON for tools/levels/check.py. Run: lune run tools/levels/dump.luau <file>
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local file = process.args[1]
local env = {
	Color3 = roblox.Color3,
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	CFrame = roblox.CFrame,
	Enum = roblox.Enum,
	math = math,
	table = table,
	string = string,
	tostring = tostring,
	ipairs = ipairs,
	pairs = pairs,
}
local chunk = luau.load(fs.readFile(file), { debugName = file, environment = env })
local data = chunk()

local function conv(v: any): any
	local t = typeof(v)
	if t == "table" then
		local out = {}
		for k, x in v do
			out[k] = conv(x)
		end
		return out
	elseif t == "Color3" then
		return { v.R, v.G, v.B }
	elseif t == "Vector3" then
		return { v.X, v.Y, v.Z }
	elseif t == "Vector2" then
		return { v.X, v.Y }
	elseif t == "function" then
		return nil
	elseif t == "EnumItem" then
		return tostring(v)
	end
	return v
end
print(serde.encode("json", conv(data)))
