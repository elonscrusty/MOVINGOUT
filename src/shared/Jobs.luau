--[[
	Jobs.luau
	The job list in campaign order, plus the lobby yard. Each level module is pure data
	(see Levels/README in docs/LEVELS.md for the format).
]]

local Levels = script.Parent:WaitForChild("Levels")

local Jobs = {}

Jobs.Lobby = require(Levels:WaitForChild("Depot")) :: any

Jobs.List = {
	require(Levels:WaitForChild("Suburb")) :: any,
	require(Levels:WaitForChild("Poolside")) :: any,
	require(Levels:WaitForChild("Warehouse")) :: any,
	require(Levels:WaitForChild("Haunted")) :: any,
}

Jobs.ById = {} :: { [string]: any }
for i, job in Jobs.List do
	job.Order = i
	Jobs.ById[job.Id] = job
end

function Jobs.Next(id: string): any?
	local job = Jobs.ById[id]
	if not job then
		return nil
	end
	return Jobs.List[job.Order + 1]
end

-- number of required items in a job
function Jobs.RequiredCount(job: any): number
	local n = 0
	for _, item in job.Items do
		if item.Required ~= false then
			n += 1
		end
	end
	return n
end

-- the medal for a time (seconds), with the assist time scale applied
function Jobs.Medal(job: any, seconds: number, scale: number?): string
	local s = scale or 1
	local a = job.Awards
	if seconds <= a.Gold * s then
		return "Gold"
	elseif seconds <= a.Silver * s then
		return "Silver"
	elseif seconds <= a.Bronze * s then
		return "Bronze"
	end
	return "None"
end

Jobs.MedalRank = { None = 0, Bronze = 1, Silver = 2, Gold = 3 }

return Jobs
