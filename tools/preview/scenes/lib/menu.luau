--!nocheck
--[[
	scenes/lib/menu.luau - opens a menu screen the way a player would (real buttons and
	remotes) on a booted game (lib game). M.press(text) taps the first visible button
	with that text; M.open(name) asks the real Menus module (Menus.Open) as a fallback.
]]
local G = lib("game")

local M = {}

-- Visible GuiButtons whose text matches.
function M.button(text: string)
	for _, b in preview.findGui(text) do
		if b:IsA("GuiButton") and preview.isShown(b) then
			return b
		end
	end
	return nil
end

function M.press(text: string): boolean
	local b = M.button(text)
	if not b then
		preview.warn("no visible button " .. text)
		return false
	end
	preview.click(b)
	preview.advance(0.4)
	return true
end

function M.menus()
	return preview.client("Menus")
end

function M.current(): string?
	return M.menus().Current()
end

function M.open(name: string)
	M.menus().Open(name)
	preview.advance(0.4)
end

-- Common start: the game on `level` (Depot = the lobby) with N movers, HUD visible.
function M.start(opts)
	local a = preview.args
	local ctx = G.boot({
		join = opts.join,
		level = opts.level or a.level,
		movers = tonumber(a.movers) or opts.movers or 1,
		phase = opts.phase,
	})
	preview.advance(opts.settle or 1.2)
	return ctx
end

function M.report()
	preview.log("menu", tostring(M.current()), "phase", tostring(G.phase()))
end

return M
