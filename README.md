# Metronome
FFXI Windower addon that tracks Dancer Step timers on enemies and displays it in the UI.

## How to Install

Download the addon and place the HasteInfo folder into your windower `addons` folder.
In game, run this command: `lua load metronome`

If you want it to load automatically when you log in, I highly recommend configuring it in the Plugin Manager addon, which you can get in the Windower launcher.
Plugin Manager details can be found at https://docs.windower.net/addons/pluginmanager/

## How It Works

Displays a UI only when targeting an enemy with a Step debuff on it. This UI will show you the timers for all the Step debuffs it has active.

### Assumptions

* All Steps from players other than you are sub DNC (unless Feather Step was used because that can only come from main DNC)
* Feather Step from other DNC do not get job point bonus to duration
* Max duration is 2 minutes, or 2:40 if full job point allocation to Step Duration

## TODO / Known Issues
* Check for miss and don't track debuff if missed step.
* Clear tracked enemy from the table upon its death.
* Listen for debuff removal events on enemies (such as from Erase) and untrack those debuffs.
