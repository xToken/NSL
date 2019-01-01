-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/spectator_techtree/client.lua
-- - Dragon

local function UpdateOverheadGUI(script)
	if script then
		local numLines = 1
		local keyHintsText = string.gsub(script.keyHints:GetText(), "\n", " ")
		keyHintsText = keyHintsText .. " " .. string.format("[%s+(1/2)] Toggle TechMaps", BindingsUI_GetInputValue("ShowTechMap"))
		keyHintsText, _, numLines = WordWrap(script.keyHints, keyHintsText, 0, Client.GetScreenWidth() - GUIScale(260))
		script.keyHints:SetPosition(Vector(GUIScale(10), -GUIScale(20 * numLines), 0))
		GUIMakeFontScale(script.keyHints)
		script.keyHints:SetText(keyHintsText)
	end
end

local oldGUIInsight_OverheadInitialize

local originalOverheadSpectatorModeInitialize
originalOverheadSpectatorModeInitialize = Class_ReplaceMethod("OverheadSpectatorMode", "Initialize", 
	function(self, spectator)
		originalOverheadSpectatorModeInitialize(self, spectator)
		if not oldGUIInsight_OverheadInitialize then
			-- Hook this for any resolution change updates
			oldGUIInsight_OverheadInitialize = GUIInsight_Overhead.Initialize
			function GUIInsight_Overhead:Initialize()
				oldGUIInsight_OverheadInitialize(self)
				UpdateOverheadGUI(self)
			end
			-- Run now to get the script updated that is already init
			UpdateOverheadGUI(GetGUIManager():GetGUIScriptSingle("GUIInsight_Overhead"))
		end
	end
)