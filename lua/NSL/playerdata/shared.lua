-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/playerdata/shared.lua
-- - Dragon

local kMaxNSLNicknameLength = 70
local kMaxNSLTeamnameLength = 70
local kMaxNSLLeagueName = 20
local kMaxNSLRank = 10

local oldPlayerInfoEntityOnCreate
oldPlayerInfoEntityOnCreate = Class_ReplaceMethod("PlayerInfoEntity", "OnCreate", 
	function(self)
		oldPlayerInfoEntityOnCreate(self)
		self.NSL_ID = 0
		self.NSL_TID = 0
		self.NSL_NICK = ""
		self.NSL_Team = ""
		self.NSL_Rank = 0
		self.NSL_League = ""
	end
)

function PlayerInfoEntity:GetNSLID()
	return self.NSL_ID
end

function PlayerInfoEntity:GetNSLTeamID()
	return self.NSL_TID
end

function PlayerInfoEntity:GetNSLName()
	return self.NSL_NICK
end

function PlayerInfoEntity:GetNSLTeam()
	return self.NSL_Team
end

function PlayerInfoEntity:GetNSLRank()
	return self.NSL_Rank
end

function PlayerInfoEntity:GetNSLLeague()
	return self.NSL_League
end

function PlayerInfoEntity:GetNSLData()
	return { 
				NSL_ID = self.NSL_ID, 
				NSL_TID = self.NSL_TID,
				NSL_NICK = self.NSL_NICK,
				NSL_Team = self.NSL_Team,
				NSL_Rank = self.NSL_Rank,
				NSL_League = self.NSL_League
			}
end

function PlayerInfoEntity:SetupNSLData(nsldata)
	if nsldata then
		self.NSL_ID = tonumber(nsldata.NSL_ID) or 0
		self.NSL_TID = tonumber(nsldata.NSL_TID) or 0
		self.NSL_NICK = nsldata.NICK or ""
		self.NSL_Team = nsldata.NSL_Team or ""
		self.NSL_Rank = tonumber(nsldata.NSL_Rank) or 0
		self.NSL_League = GetActiveLeague()
	end
end

Class_Reload( "PlayerInfoEntity", {
									NSL_ID = "integer",
									NSL_TID = "integer",
									NSL_NICK = string.format("string (%d)", kMaxNSLNicknameLength ),
									NSL_Team = string.format("string (%d)", kMaxNSLTeamnameLength ),
									NSL_League = string.format("string (%d)", kMaxNSLLeagueName ),
									NSL_Rank = string.format("integer (0 to %d)", kMaxNSLRank)
									} )