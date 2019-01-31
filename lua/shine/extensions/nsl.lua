local Shine = Shine
local Plugin = Shine.Plugin( ... )

Plugin.Version = "1.0"
Plugin.HasConfig = false
Plugin.DefaultState = true

function Plugin:Initialise()
	self.commandRefs = { }
	self.Enabled = true
	return true
end

function Plugin:CreateCommand(commandData)
	local command = commandData[i]
	local commandObj = self:BindCommand(commandData.Command, nil, commandData.Callback)
	if commandData.Params then
		for j = 1, #commandData.Params do
			commandObj:AddParam(commandData.Params[j])
		end
	end
	commandObj:Help(commandData.Help)
	table.insert(self.commandRefs, commandObj)
end

Shine:RegisterExtension("nsl", Plugin)

return Plugin -- ??