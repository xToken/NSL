-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/nsl_server.lua
-- - Dragon

-- Load shared defs
Script.Load("lua/NSL/nsl_shared.lua")

-- Load tier 1 server defs
Script.Load("lua/NSL/eventhooks/server.lua")
Script.Load("lua/NSL/config/server.lua")

-- Load remaining server defs
Script.Load("lua/NSL/admincommands/server.lua")
Script.Load("lua/NSL/coinflip/server.lua")
--Script.Load("lua/NSL/consistencychecks/server.lua") -- Loaded by filereplace
Script.Load("lua/NSL/customspawns/server.lua")
Script.Load("lua/NSL/errorreporter/server.lua")
Script.Load("lua/NSL/firstpersonspecblock/server.lua")
Script.Load("lua/NSL/handicap/server.lua")
Script.Load("lua/NSL/heartbeat/server.lua")
Script.Load("lua/NSL/pause/server.lua")
Script.Load("lua/NSL/playerdata/server.lua")
Script.Load("lua/NSL/serversettings/server.lua")
Script.Load("lua/NSL/skinsblocker/server.lua")
Script.Load("lua/NSL/spectator_techtree/server.lua")
Script.Load("lua/NSL/statesave/server.lua")
Script.Load("lua/NSL/teamdecals/server.lua")
Script.Load("lua/NSL/teammanager/server.lua")
Script.Load("lua/NSL/tournamentmode/server.lua")
Script.Load("lua/NSL/unstuck/server.lua")