# MyJailbreak warden queue

This plugin replaces the MyJailbreak command `!warden` with a queue for warden, this means all players will be able to become warden in turn.

## Commands
*For all commands replace `sm_` with `!` or `/` to use them as chat commands*

| Command | Action |
| ------: | :----- |
| `sm_w`, `sm_warden` | Join the warden queue or become warden |
| `sm_uw`, `sm_unwarden`, `sm_lwq` | Leave the warden queue or step down as warden |
| `sm_vwq`, `sm_viewwardenqueue` | Print out warden queue |

**Admin commands**

| Command | Action |
| ------: | :----- |
| `sm_wrq` | Remove player from warden queue |

## Cvars

| CVar | Description |
| ---- | :---------- |
| `sm_wardenqueue_enable` | `0`/`1` - Disable/Enable this plugin |
| `sm_wardenqueue_removetemporary` | `0/1` - False/True -> Do remove the second warden of a round from the queue |
| `sm_wardenqueue_emptyrandom` | `0/1` - False/True -> Whether to set a random guard as warden if queue is empty |
| `sm_wardenqueue_vipflag` | Flag for VIP |

## Notes
This plugin forces the following cvars to a value of `0` in order to ensure it works smoothly:
- `sm_warden_choose_random`
- `sm_warden_stay`
- `sm_warden_become`
- `sm_warden_choice`

_This plugin was created for [GFLClan](https://gflclan.com/)_

## Some links
- [My jailbreak](https://github.com/shanapu/MyJailbreak)
- [LICENSE](./LICENSE)
