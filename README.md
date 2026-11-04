# roblox

Roblox project synced into Studio with [Rojo](https://rojo.space).

## Setup
1. Install tools: `aftman install` (or install Rojo manually).
2. Install the Rojo plugin in Roblox Studio.
3. Run `./scripts/sync.sh` (Mac/Linux) or `.\scripts\sync.ps1` (Windows). This starts
   `rojo serve` and auto-pulls new commits from `main` every 5 seconds.
4. In Studio, click **Connect** in the Rojo plugin (once per session).

After that, anything pushed to `main` appears in Studio automatically.

## Layout
- `src/server` -> ServerScriptService.Server
- `src/client` -> StarterPlayer.StarterPlayerScripts.Client
- `src/shared` -> ReplicatedStorage.Shared

## Pet Dynasty development status
- **Phase 1 (foundation)**: data saving with session locking, Coin service, remotes, config, HUD.
  - `src/shared/Config/*` - economy, rarities, variants, default save data (tune numbers here).
  - `src/server/Services/*` - DataService, CoinService, RateLimiter.
  - `src/client/Controllers/*` - DataController (mirrors server data), HUDController.
- In Studio, enable **Game Settings > Security > Enable Studio Access to API Services** to test saving.
  Without it the game runs with temporary, unsaved data.
