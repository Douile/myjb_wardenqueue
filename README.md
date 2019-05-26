# GFL-Clan MyJailbreak warden queue

**Status**: Testing

_Please ignore my horrible use of git submodules on this repo :)_

## Commands
*For all commands replace `sm_` with `!` or `/` to use them as chat commands*

| Command | Action |
| ------: | :----- |
| `sm_w`, `sm_warden` | Join the warden queue or become warden |
| `sm_uw`, `sm_unwarden` | Leave the warden queue or step down as warden |
| `sm_lq`, `sm_listqueue` | Print out warden queue |

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

## Some links
- [Trello](https://trello.com/c/hihjTVpq/31-warden-queue-for-jb)
- [Forum post](https://gflclan.com/forums/topic/36417-csgo-jb-a-few-minor-requests/)
- [My jailbreak](https://github.com/shanapu/MyJailbreak)
- [LICENSE](./LICENSE)
