# **SAVEFORGE — Cyber Forge**

A multi-game save editor for iOS and iPadOS.

SAVEFORGE is a native SwiftUI application designed to give players more control over their game saves through a clean, modern interface. Built around the Cyber Forge design, SAVEFORGE brings save management, editing tools, and game-specific editors together in one place.

Current release: v1.0
Platform: iOS / iPadOS
Targeted Version: 16.0+
Development: SwiftUI
Status: Fallout Shelter Editor Ready — Additional game editors coming soon.

⸻

# **Features**

* Multi-game library — Browse supported and upcoming game editors from one interface.
* Save importing — Import compatible game save files into SAVEFORGE.
* Save editing — Modify supported game data through dedicated editing modules.
* Save exporting — Export edited saves for use in your games.
* Local-first design — Your imported save files and editing workflow stay on your device.
* Library management — Access recent files, favorites, imported files, and storage tools.
* Cyber Forge interface — A dark interface with gold and cyan accents, custom game artwork, and a modern design.

## **Supported Games**

| **Game** | **Editor Status** |
|----------|----------------|
| Fallout Shelter | Editor Ready |
| Stardew Valley | Coming Soon |
| Terraria | Coming Soon |
| Minecraft Bedrock | Coming Soon |
| TheoTown | Coming Soon |
| WorldBox | Coming Soon |

Additional game editors may be introduced in future releases.

Fallout Shelter Editor

Fallout Shelter is the first fully supported game editor in SAVEFORGE.

Current editing modules include:

* Vault Overview — Edit vault information, including vault name and vault ID.
* Resources — Manage Bottle Caps, Power, Food, Water, Nuka-Cola Quantum, Stimpaks, RadAway, Lunchboxes, Mr. Handys, Pet Carriers, Starter Boxes, and other supported resources.
* Dwellers — View and edit dweller data, SPECIAL attributes, and assignments.
* Inventory — Manage weapons, outfits, pets, junk, and other inventory items.
* Rooms — Access and edit supported room and vault layout data.

# **Fallout Shelter Save Access**

SAVEFORGE supports different save-access workflows depending on the device:

* Jailbroken devices: Direct access to Fallout Shelter save files through the device filesystem.
* Non-jailbroken devices: WQFiles running inside LiveContainer (LC) is required for the Fallout Shelter save-access workflow.
* Steam (MacOS/Linux/Windows): **Windows:** C:\Users\<YourName>\AppData\Local; **Linux:** You have two ways, try ~/.steam/steam/steamapps/common/Fallout Shelter, or find ~/.steam/steam/steamapps/common -type d -iname "Fallout Shelter"; **MacOS:** ~/Library/Application Support/Fallout Shelter

* Make sure you disable Cloud Sync inside Steam before you grab your Vault(1,2,3).sav files

Save compatibility depends on the game version, save format, and device environment. Always keep a backup of your original save before editing.

# **Interface**

SAVEFORGE uses the Cyber Forge visual identity:

* Dark surfaces and backgrounds.
* Gold and cyan accent colors.
* Custom game artwork.
* Dedicated game editor screens.
* Native iOS and iPadOS interface elements.

# **Project Structure**

The project includes:

SAVEFORGE/
├── SAVEFORGEApp.swift
├── README.md
├── LICENSE
├── ContentView.swift
├── Config/
│   ├── Project.plist
│   └── Entitlements.plist
└── Resources/
    ├── AppIcon.png
    ├── manifest.json
    ├── fallout-shelter.svg
    ├── stardew-valley.svg
    ├── terraria.svg
    ├── minecraft-bedrock.svg
    ├── theotown.svg
    ├── worldbox.svg
    └── Game JSON files

# **Development**

SAVEFORGE is developed using:

* Swift
* SwiftUI
* UIKit
* Native iOS frameworks

The project is developed and built using Nyxian IDE.

# **Roadmap**

Planned improvements and future features include:

* Additional game save editors.
* Expanded game compatibility.
* Improved save import and export workflows.
* More advanced inventory editing.
* Fallout Shelter dweller customization.
* Additional editing tools and quality-of-life improvements.

Features and release timelines are subject to change.

Backups and Save Safety

Always create a backup of your original game save before making modifications.

SAVEFORGE is provided as a save-editing utility. Users are responsible for maintaining their own backups and verifying edited saves before replacing original files.

**Disclaimer**

SAVEFORGE is an independent, fan-made project and is not affiliated with, endorsed by, or sponsored by Bethesda Softworks or Microsoft.

All game names, trademarks, and third-party assets belong to their respective owners.

# **License**

SAVEFORGE — Cyber Forge is proprietary software.

See the LICENSE file for the full license terms.

Credits

Developed by Infifunk.

Project Discord and updates:

https://discord.gg/44gZWmEVzy⁠

⸻

SAVEFORGE — Cyber Forge

Your saves. Your games. Your control.
