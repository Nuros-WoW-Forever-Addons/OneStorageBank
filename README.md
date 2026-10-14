# OneStorageBank

**OneStorageBank** is an all-in-one unified bank and reagent storage window for World of Warcraft featuring authentic Blizzard Metal styling, live search filtering, bank bag purchasing, and sub-tabbed navigation.

Part of the **OneSuite** family of addons.

---

## 🚀 Features

- 🏦 **Unified All-In-One Bank Window**: Consolidates all bank containers into a single, organized interface.
- 🗂️ **Sub-Tab Navigation**: Clean metallic sub-tabs to switch seamlessly between **Main Bank** and **Reagent Bank** storage.
- 🛡️ **Authentic Blizzard Metal Styling**: Framed with signature silver dialog borders, dark slate insets, and metallic headers matching the OneSuite visual design standard.
- 🔍 **Live Search Filtering**: Search query highlighting that dims non-matching slots in real time.
- 📐 **Customizable Layout**:
  - **Merged Grid Mode**: Compact continuous grid of bank slots.
  - **Separated Bags Mode**: Visual dividers separating individual bank bags.
  - **Configurable Column Width**: Adjust from 6 to 18 columns (`/osbank cols <number>`).
- 💰 **Bank Bag Drawer & Slot Purchasing**: Expandable bank bag bar with integrated slot cost calculation and 1-click slot purchase confirmation.
- 🔄 **Bank Interaction Hooks**: Automatically opens when visiting any Banker NPC and cleanly closes upon walking away.

---

## 🛠️ Installation

Copy the `OneStorageBank` directory (along with `OneStorageUtils`) into your World of Warcraft `Interface/AddOns/` directory:

```text
World of Warcraft/Interface/AddOns/OneStorageBank/
├── OneStorageBank.toc
├── Core.lua
├── Hooks.lua
├── CHANGELOG.md
├── CONTEXT.md
└── README.md
```

Then start or reload World of Warcraft (`/reload`).

---

## 💻 Slash Commands

| Command | Description |
|---|---|
| `/onebank` or `/osbank` | Open / toggle the unified bank window (view-only if away from Banker) |
| `/osbank mode` or `/osbank separate` | Toggle between separated bank rows and merged continuous grid |
| `/osbank cols <6-18>` | Set the column width of the bank window |
| `/osbank reset` | Reset bank window position to default |
| `/osbank options` | Open configuration options |

---

For detailed version history and release notes, see [CHANGELOG.md](CHANGELOG.md).
