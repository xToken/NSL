-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/spectator_techtree/shared.lua
-- - Dragon

local originalNS2SpectatorOnCreate
originalNS2SpectatorOnCreate = Class_ReplaceMethod("Spectator", "OnCreate", 
	function(self)
		originalNS2SpectatorOnCreate(self)
		self.hookedTechTree = 0
	end
)

Class_Reload( "Spectator", {hookedTechTree = string.format("integer (-1 to %d)", kSpectatorIndex)} )