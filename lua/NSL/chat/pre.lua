if not Client then return end

g_NSL_Client_HookNetworkMessage = Client.HookNetworkMessage
g_NSL_Chat_OnMessageChat = nil

function Client.HookNetworkMessage(name, func)
    if name == "Chat" then
        g_NSL_Chat_OnMessageChat = func
    end

    return g_NSL_Client_HookNetworkMessage(name, func)
end
