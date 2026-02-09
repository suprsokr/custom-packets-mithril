# Custom Packets

A [Mithril](https://github.com/suprsokr/mithril) mod that enables bidirectional custom packet communication between WoW client addons and TrinityCore server scripts.

## Custom Packets vs Addon Messages

| Feature | Custom Packets | Addon Messages |
|---------|---------------|----------------|
| **Max payload size** | Several MB per packet | 255 bytes per message |
| **Transfer speed** | Fast (no throttling) | Slow (10-20 messages/sec throttled) |
| **Large data transfer** | Seconds for MB of data | 10+ minutes for MB of data |
| **Fragmentation** | Not needed | Required for >255 bytes |
| **Reliability** | Built-in TCP reliability | Manual reassembly/error handling |
| **Server-initiated** | Yes (server can push) | No (client-initiated only) |
| **Setup complexity** | Requires client patching | Built-in, no setup |
| **Best for** | Bulk data, real-time large transfers | Small, frequent updates |

## What's Included

```
custom-packets/
├── binary-patches/
│   ├── load-clientextensions.json   # Injects ClientExtensions.dll into Wow.exe
│   └── ClientExtensions.dll         # DLL handling custom packets on client
├── core-patches/
│   └── custom-packets.patch         # Patches TrinityCore for custom opcodes
├── addons/Interface/AddOns/
│   └── CustomPacketsDemo/           # Demo addon with /cptest commands
└── scripts/
    └── custom_packets_demo.cpp      # Demo server script (ping/echo)
```

## Install

Requires [Mithril](https://github.com/suprsokr/mithril).

```bash
# Apply binary patch + copy DLL to client
mithril mod patch apply --mod custom-packets

# Build everything else (core patch, scripts, addons, server rebuild)
mithril mod build

# Restart server
mithril server restart
```

## Usage

The demo addon provides slash commands in-game:

```
/cptest ping         - Send ping to server, shows round-trip latency
/cptest echo [msg]   - Echo a message through the server
```

Refer to [custom-packets.md](custom-packets.md) for how to make your own custom packets and use them. 

## Credits

- ClientExtensions.dll from [wotlk-custom-packets](https://github.com/suprsokr/wotlk-custom-packets), based on [TSWoW](https://github.com/tswow/tswow) (MIT License)
