# Hats

_**English** | [Русский](README.ru.md)_

![Hats](images/hats.png)

AMX Mod X plugin for Counter-Strike.

The plugin allows the player to wear hats on their heads. The main feature of this modification is the player's ability to choose a skin or a submodel of a headgear on his own and set which of them will be available exclusively to VIP players.

## Commands
* `amx_givehat <player's name> <hat id> <skin/submodel id>` — put on/take off the hat to the player by the player's name (available for users with the "l" flag and in the server console)
* `amx_removehats` — remove hats from each player (available for users with the "l" flag and in the server console)
* `hats` — console command to call the hat selection menu
* `say /hats` или `say_team /hats` — chat command to call the hat selection menu

## Configuration
The plugin automatically determines the number of skins/submodels, as well as the names of the used submodels. All you need to do is specify the name of the .mdl file and the expected name of the hat in the menu with the tag. Hat registration format:
"__mdl__" "__v__`tag`__name__"

where:
* __mdl__ — model file name
* __v__ — access for VIP players (for regular players, you can leave it blank)
* `tag` — tag (you can leave it blank if you don't want to use skins/submodels)
* __name__ — name of the hat in the menu.

### Tags:
* _s_ — only skins will be read
* _b_ — only submodels will be read
* _c_ — a universal type that does not exclude the possibility of having skins and submodels in the hat at the same time (use it if you are in doubt about choosing a tag or want to combine skins and submodels)
* _t_ — skin or submodel will be set according to the player's team.

### Examples:
* _"Headcrab.mdl" "Headcrab"_ — headcrab hat without additions
* _"santa_hat_v2.mdl" "sSanta"_ — Santa hat with all skins
* _"pony_v2.mdl" "cPony"_ — pony hat with skins and submodels
* _"pony_antagonist.mdl" "vcPony Antagonist"_ — pony VIP hat with skins and submodels.

The configuration is done in the file:
_amxmodx/configs/HatList.txt_.

## Requirements
- [Reapi](https://github.com/s1lentq/reapi)

## Authors
- [Psycrow](https://github.com/Psycrow101)
