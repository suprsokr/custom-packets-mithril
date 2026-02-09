/*
 * Custom Packets Demo Script
 * 
 * This script demonstrates the custom packets system by responding to
 * ping requests from the client with pong responses.
 * 
 * Part of the custom-packets Thorium mod.
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "CustomPacketRead.h"
#include "CustomPacketWrite.h"
#include "CustomPacketHandler.h"
#include "Log.h"

// Custom opcodes - must match client-side (CustomPackets addon)
enum CustomPacketOpcodes
{
    // Client -> Server (CYCM = Custom Client Message)
    CYCM_PING           = 1001,
    CYCM_ECHO           = 1002,
    
    // Server -> Client (CYSM = Custom Server Message)  
    CYSM_PONG           = 2001,
    CYSM_ECHO_RESPONSE  = 2002,
};

class CustomPacketsDemoHandler : public ServerScript
{
public:
    CustomPacketsDemoHandler() : ServerScript("CustomPacketsDemoHandler") { }

    // Called when a custom packet is received from the client
    void OnCustomPacketReceive(Player* player, uint16 opcode, CustomPacketRead* packet) override
    {
        switch (opcode)
        {
            case CYCM_PING:
                HandlePing(player, packet);
                break;
            case CYCM_ECHO:
                HandleEcho(player, packet);
                break;
        }
    }

private:
    void HandlePing(Player* player, CustomPacketRead* packet)
    {
        // Read the timestamp sent by client
        uint32 clientTimestamp = packet->Read<uint32>(0);

        TC_LOG_INFO("custom.packets", "Player {} sent PING with timestamp {}", 
            player->GetName(), clientTimestamp);

        // Build pong response
        CustomPacketWrite response = CreateCustomPacket(CYSM_PONG);
        response.Write<uint32>(clientTimestamp);           // Echo back for latency calculation
        response.Write<uint32>(time(nullptr));             // Server timestamp
        response.WriteString("Pong from TrinityCore!");    // Message
        
        SendCustomPacket(player, response);
    }

    void HandleEcho(Player* player, CustomPacketRead* packet)
    {
        // Read the message from client
        std::string message = packet->ReadString("");

        TC_LOG_INFO("custom.packets", "Player {} sent ECHO: {}", 
            player->GetName(), message);

        // Echo it back with server prefix
        CustomPacketWrite response = CreateCustomPacket(CYSM_ECHO_RESPONSE);
        response.WriteString("Server received: " + message);
        
        SendCustomPacket(player, response);
    }
};

void AddSC_custom_packets_demo()
{
    TC_LOG_INFO("server.loading", "Loading CustomPacketsDemoHandler...");
    new CustomPacketsDemoHandler();
}
