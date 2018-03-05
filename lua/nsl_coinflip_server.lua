local LastCoinFlipTime = 0
local kCoinFlipPeriod = 20 --Seconds between allowed coin flips

local function OnCommandCoinFlip(client)
	local gamerules = GetGamerules()
	local player = client:GetControllingPlayer()
	local playername = player:GetName()
	local teamname = GetActualTeamName(player:GetTeamNumber())
	if gamerules and client and GetNSLModEnabled() and gamerules:GetGameState() <= kGameState.PreGame then
		local timeleft = LastCoinFlipTime + kCoinFlipPeriod - Shared.GetTime()
		if timeleft <= 0 then
			local flip = math.random(0,1) == 0 and "HEADS" or "TAILS"
			LastCoinFlipTime = Shared.GetTime()
			SendAllClientsMessage(string.format(GetNSLMessage("CoinFlip"), playername, teamname, flip))
		else
			SendClientMessage(client, string.format(GetNSLMessage("CoinFlipRecently"), timeleft))
		end
	end
end

Event.Hook("Console_coinflip", OnCommandCoinFlip)
gChatCommands["coinflip"] = OnCommandCoinFlip
gChatCommands["!coinflip"] = OnCommandCoinFlip
gChatCommands["!flip"] = OnCommandCoinFlip