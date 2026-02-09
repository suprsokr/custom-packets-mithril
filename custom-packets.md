# Custom Packets

Custom Packets enable bidirectional communication between WoW client addons and TrinityCore server scripts beyond the standard WoW protocol. This allows you to build features like custom UI updates, real-time data sync, and server-driven client behavior.

## Overview

The system consists of four parts:

1. **Client-side Lua API** - Provided by `ClientExtensions.dll` (embedded Lua code)
2. **Client binary patch** - Injects `ClientExtensions.dll` into `Wow.exe` to handle custom opcodes
3. **Server source patch** - Patches TrinityCore to register opcode 0x51F
4. **Server-side C++ handlers** - Your scripts that process custom packets

**Important:** Custom packets require patches to BOTH the WoW client AND TrinityCore server. Stock TrinityCore does not support custom opcodes out of the box.

### How the Client API Works

The `ClientExtensions.dll` contains embedded Lua code (`ClientNetwork.lua`) that is automatically loaded when the game starts. This code:

- Registers global functions: `CreateCustomPacket()`, `OnCustomPacket()`
- Provides reader/writer methods for all data types
- Hooks into the WoW client's packet system via detours
- Handles packet fragmentation automatically

**You don't need a separate addon for the API** - it's available globally once the DLL loads. Your addons can call `CreateCustomPacket()` and `OnCustomPacket()` directly.

## Architecture

```
┌─────────────────────┐                    ┌─────────────────────┐
│   WoW Client        │                    │   TrinityCore       │
│                     │                    │                     │
│  ┌───────────────┐  │    Custom Opcode   │  ┌───────────────┐  │
│  │ Your Addon    │  │ ──────────────────►│  │ Packet Script │  │
│  │               │  │    (0x51F)         │  │               │  │
│  │ CreateCustom- │  │                    │  │ OnCustom-     │  │
│  │ Packet()      │  │                    │  │ Packet()      │  │
│  └───────────────┘  │                    │  └───────────────┘  │
│         ▲           │                    │         │           │
│         │           │    Custom Opcode   │         │           │
│         └───────────│◄───────────────────│─────────┘           │
│                     │    (0x102)         │                     │
│  ┌───────────────┐  │                    │                     │
│  │ ClientExtens- │  │                    │                     │
│  │ ions.dll      │  │                    │                     │
│  │ (embeds Lua)  │  │                    │                     │
│  └───────────────┘  │                    │                     │
└─────────────────────┘                    └─────────────────────┘
```

### Opcodes

| Direction | Opcode | Description |
|-----------|--------|-------------|
| Client → Server | `0x51F` | Custom packets sent from addons |
| Server → Client | `0x102` | Custom packets sent from server scripts |

### Packet Structure

Each custom packet has a 6-byte header:

| Field | Size | Description |
|-------|------|-------------|
| FragmentID | 2 bytes | Current fragment index (0-based) |
| TotalFrags | 2 bytes | Total number of fragments |
| Opcode | 2 bytes | Your custom opcode (0-65535) |

The header is followed by the payload data. Large packets are automatically fragmented (max ~30KB per fragment).

## Client-Side: Lua API

The Lua API is provided by `ClientExtensions.dll` via embedded Lua code that runs when the game starts. The API is available globally - no addon dependency required.

### Sending Packets

```lua
-- Create a packet with your custom opcode
local packet = CreateCustomPacket(1001, 0)  -- opcode, size hint (0 = dynamic)

-- Write data
packet:WriteUInt8(255)
packet:WriteInt32(-12345)
packet:WriteFloat(3.14159)
packet:WriteString("Hello Server")          -- null-terminated
packet:WriteLengthString("Length prefixed") -- uint32 length + bytes

-- Send to server
packet:Send()
```

### Receiving Packets

```lua
-- Register handler for custom opcode
OnCustomPacket(1002, function(reader)
    -- Read data in same order it was written
    local flags = reader:ReadUInt8()
    local count = reader:ReadInt32()
    local multiplier = reader:ReadFloat()
    local name = reader:ReadString()       -- null-terminated
    
    print("Received:", name, "count:", count)
end)
```

### Data Types

| Write Method | Read Method | Size | Range |
|--------------|-------------|------|-------|
| `WriteUInt8(v)` | `ReadUInt8()` | 1 byte | 0 to 255 |
| `WriteInt8(v)` | `ReadInt8()` | 1 byte | -128 to 127 |
| `WriteUInt16(v)` | `ReadUInt16()` | 2 bytes | 0 to 65,535 |
| `WriteInt16(v)` | `ReadInt16()` | 2 bytes | -32,768 to 32,767 |
| `WriteUInt32(v)` | `ReadUInt32()` | 4 bytes | 0 to 4,294,967,295 |
| `WriteInt32(v)` | `ReadInt32()` | 4 bytes | -2.1B to 2.1B |
| `WriteUInt64(v)` | `ReadUInt64()` | 8 bytes | 0 to 18.4E |
| `WriteInt64(v)` | `ReadInt64()` | 8 bytes | -9.2E to 9.2E |
| `WriteFloat(v)` | `ReadFloat()` | 4 bytes | IEEE 754 single |
| `WriteDouble(v)` | `ReadDouble()` | 8 bytes | IEEE 754 double |
| `WriteString(v)` | `ReadString()` | varies | Null-terminated |

**Note:** Read methods do not take default parameters. If you need to handle read failures, check `reader:Size()` before reading.

### Utility Methods

```lua
-- Writer
packet:Size()              -- Current packet size in bytes

-- Reader  
reader:Size()              -- Total size of packet
```

### Chain Writing

Writer methods return `self`, so you can chain calls:

```lua
CreateCustomPacket(1001, 0)
    :WriteUInt32(123)
    :WriteString("Hello")
    :Send()
```

## Server-Side: C++ Scripts

Create a packet handler script:

```bash
thorium create-script --mod my-mod --type packet my_protocol
```

This generates a script template in `mods/my-mod/scripts/`.

### Example Handler

```cpp
#include "ScriptMgr.h"
#include "Player.h"
#include "WorldPacket.h"

// Define your opcodes (must match client-side)
enum MyOpcodes
{
    CYCM_MY_REQUEST  = 1001,  // Client -> Server
    CYSM_MY_RESPONSE = 1002   // Server -> Client
};

class MyCustomPacketHandler : public ServerScript
{
public:
    MyCustomPacketHandler() : ServerScript("MyCustomPacketHandler") { }

    // This hook is added by the custom-packets server patch
    void OnCustomPacketReceive(Player* player, uint16 opcode, WorldPacket& packet) override
    {
        if (opcode != CYCM_MY_REQUEST)
            return;

        // Read data in same order client wrote it
        uint8 flags;
        int32 count;
        float multiplier;
        std::string name;

        packet >> flags >> count >> multiplier >> name;

        // Process the data
        TC_LOG_INFO("custom", "Received from {}: flags={}, count={}, name={}",
            player->GetName(), flags, count, name);

        // Build response payload (just the data, no header needed)
        WorldPacket response;
        response << uint32(player->GetGUID().GetCounter());
        response << std::string("Response from server");
        
        // SendCustomPacket handles the transport header automatically
        player->SendCustomPacket(CYSM_MY_RESPONSE, &response);
    }
};

void AddSC_my_custom_packets()
{
    new MyCustomPacketHandler();
}
```

## Setup

Custom packets require the `custom-packets` mod which is distributed separately from Thorium. This mod contains:
- Binary edits to load `ClientExtensions.dll` into `Wow.exe`
- The `ClientExtensions.dll` binary (with embedded Lua API)
- Server patches for TrinityCore

### 1. Get the custom-packets Mod

Download or clone the `custom-packets` mod into your workspace:

```
mods/mods/custom-packets/
├── binary-edits/
│   └── load-clientextensions.json
├── server-patches/
│   └── custom-packets.patch
└── assets/
    ├── config.json
    └── ClientExtensions.dll
```

### 2. Build to Apply Patches

```bash
thorium build
```

This automatically:
- Applies the binary edits to `Wow.exe` (hooks LoadLibrary to load the DLL)
- Copies `ClientExtensions.dll` to your WoW directory
- Applies the server patch to TrinityCore source

Binary edits and server patches are tracked and only applied once. Use `--force` to reapply.

**What happens when you start WoW:**
1. Binary patch intercepts LoadLibrary and loads `ClientExtensions.dll`
2. DLL loads embedded `ClientNetwork.lua` into the game's Lua state
3. Global functions `CreateCustomPacket()` and `OnCustomPacket()` become available
4. Your addons can now send/receive custom packets

### 3. Rebuild TrinityCore

After the server patch is applied, rebuild TrinityCore:

```bash
cd /path/to/TrinityCore/build && make -j$(nproc)
```

The server patch adds:
- Opcode `0x51F` (`CMSG_CUSTOM_PACKET`) registration
- `OnCustomPacketReceive` hook to `ServerScript`
- `Player::SendCustomPacket(opcode, data)` helper

### 4. Create Your Addon

```bash
thorium create-addon --mod my-mod MyFeatureUI
```

Edit `mods/my-mod/luaxml/Interface/AddOns/MyFeatureUI/main.lua`:

```lua
-- No dependencies needed! The API is global via ClientExtensions.dll

local MY_OPCODE = 1001

OnCustomPacket(MY_OPCODE, function(reader)
    local data = reader:ReadString()
    print("Received:", data)
end)

-- Send a packet
local packet = CreateCustomPacket(MY_OPCODE, 0)
packet:WriteString("Hello server")
packet:Send()
```

### 5. Create Server Handler

```bash
thorium create-script --mod my-mod --type packet my_feature_protocol
```

### 6. Build and Test

```bash
# Build client files (packages addons into MPQ)
thorium build

# Rebuild TrinityCore with your script (if you added new scripts)
cd /path/to/TrinityCore/build && make -j$(nproc)

# Restart server and test in-game
```
