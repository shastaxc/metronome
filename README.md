# Metronome
FFXI Windower addon that tracks Dancer Step timers on enemies and displays it in the UI.

## How to Install

Download the addon and place the HasteInfo folder into your windower `addons` folder.
In game, run this command: `lua load metronome`

If you want it to load automatically when you log in, I highly recommend configuring it in the Plugin Manager addon, which you can get in the Windower launcher.
Plugin Manager details can be found at https://docs.windower.net/addons/pluginmanager/

## How It Works

Displays a UI only when targeting an enemy with a Step debuff on it. This UI will show you the timers for all the Step debuffs it has active.

![image](https://github.com/shastaxc/metronome/assets/7599524/764d5374-c709-4695-909b-bb4193791755)

By default, the UI will only display if your main or sub job is DNC. It can be configured to display for all jobs with the following command:
```
//met jobs
```

Other configuration options can be found by using the help command:
```
//met help
```

### Assumptions

* All Steps from players other than you are sub DNC (unless Feather Step was used because that can only come from main DNC)
* Feather Step from other DNC do not get job point bonus to duration

## TODO / Known Issues
* None
