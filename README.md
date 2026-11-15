# ⚡ Aegis Fruit Sniper v3.0 — Blox Fruits

**Ultra-Lightweight, Event-Driven Fruit Sniper & Dealer Stock Buyer for Blox Fruits**

## 🚀 Quick Execute (`loadstring`)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Rxuser2/Aegis-Fruit-Sniper/main/GreatestFruitSniper.luau"))()
```
Aegis auth key
```txt
aegis_f47a31a9d85bb69395f21db426f7e24559c13084
```
## ✨ Key Features (v3.0)
- **Event-Driven 0ms Fruit Radar**: Uses `Workspace.ChildAdded` & `Backpack.ChildAdded` for instant detection and auto-store without heavy `GetDescendants()` polling or memory leaks.
- **Zero-Crash Anti-Detection Flight Engine**: Cached character `BasePart` collision lock, `Physics` Humanoid state lock, zeroed assembly/part velocities, water-safe altitude clamp (`MinY`), and `FlyPlatform` support at `300 studs/s`.
- **Official Blox Fruits Wiki Fruit Thumbnails**: Dual Discord Webhook alerts (Primary + Automatic Backup Failover) display high-resolution fruit icons directly from the Blox Fruits Wiki (`Dragon`, `Kitsune`, `Magnet`, `Yeti`, `Gas`, `Tiger`, `T-Rex`, `Mammoth`, `Dough`, etc., plus dynamic MediaWiki API lookup for future fruits).
- **Auto-Save Config & Auto-ReExecute on Server Hop**: Saves settings automatically to `AegisFruitSniper/config.json` and re-executes automatically via `queue_on_teleport` across server hops.
