-- CustomPackets Demo Addon
-- Demonstrates sending and receiving custom packets

-- Debug: Check if ClientExtensions functions are available
print("DEBUG: CreateCustomPacket type:", type(CreateCustomPacket))
print("DEBUG: OnCustomPacket type:", type(OnCustomPacket))
print("DEBUG: _CLIENT_NETWORK type:", type(_CLIENT_NETWORK))

-- Opcodes must match server-side script
local CYCM_PING = 1001          -- Client -> Server
local CYCM_ECHO = 1002          -- Client -> Server
local CYSM_PONG = 2001          -- Server -> Client
local CYSM_ECHO_RESPONSE = 2002 -- Server -> Client

-- Track pending ping for latency calculation
local pingStartTime = nil

-- ============================================================================
-- Packet Handlers (Server -> Client)
-- ============================================================================

-- Handle pong response from server
OnCustomPacket(CYSM_PONG, function(reader)
    local echoedTimestamp = reader:ReadUInt32(0)
    local serverTimestamp = reader:ReadUInt32(0)
    local message = reader:ReadString("")
    
    -- Calculate round-trip latency
    local latency = 0
    if pingStartTime then
        latency = math.floor((GetTime() - pingStartTime) * 1000)
        pingStartTime = nil
    end
    
    print(string.format("|cFF00FF00[CustomPackets]|r PONG received! Latency: %dms", latency))
    print(string.format("  Server says: %s", message))
end)

-- Handle echo response from server
OnCustomPacket(CYSM_ECHO_RESPONSE, function(reader)
    local message = reader:ReadString("")
    print(string.format("|cFF00FF00[CustomPackets]|r Echo response: %s", message))
end)

-- ============================================================================
-- Slash Commands
-- ============================================================================

SLASH_CPTEST1 = "/cptest"
SLASH_CPTEST2 = "/custompacket"
SlashCmdList["CPTEST"] = function(msg)
    local cmd, arg = msg:match("^(%S+)%s*(.*)$")
    cmd = cmd or msg
    
    if cmd == "ping" then
        -- Send a ping to measure latency
        print("DEBUG: About to create packet")
        pingStartTime = GetTime()
        local packet = CreateCustomPacket(CYCM_PING, 4)
        print("DEBUG: Packet created, about to write")
        packet:WriteUInt32(math.floor(GetTime() * 1000))
        print("DEBUG: Data written, about to send")
        packet:Send()
        print("|cFFFFFF00[CustomPackets]|r Sending PING... (packet sent)")
        
    elseif cmd == "echo" then
        -- Send an echo message
        local message = arg ~= "" and arg or "Hello from WoW client!"
        local packet = CreateCustomPacket(CYCM_ECHO, 0)
        packet:WriteString(message)
        packet:Send()
        print(string.format("|cFFFFFF00[CustomPackets]|r Sending ECHO: %s", message))
        
    else
        print("|cFF00FFFF[CustomPackets Demo]|r Commands:")
        print("  /cptest ping - Send ping, measure latency")
        print("  /cptest echo [message] - Echo a message through server")
    end
end

-- ============================================================================
-- Initialization
-- ============================================================================

print("|cFF00FF00[CustomPackets Demo]|r Loaded. Type /cptest for commands.")
