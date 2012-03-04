# About xVim

## xVim for _xCode_ do not need [SIMBL](http://www.culater.net/software/SIMBL/SIMBL.php) any more

* xVim is a plugin to provide vim key-binding for  Mac Apps. （See all currently supported appliction __[here](https://github.com/WarWithinMe/xVim/wiki/Supported-Application)__)

* Make sure you are checking xVim's github and stay updated.

* __You may use xVim under the terms of the MIT license.__

* Consider this is a temporary plugin for you before [another XVim project](https://github.com/JugglerShu/XVim) reaches a stable stage.

## How to use it (for XCode only)

1. Download or fork xVim (Only use the __master__ branch)

1. __Build__ xVim with __xVim Scheme__. Confirm there's a __xVim.xcplugin__ in the location : ~/Library/Application Support/Developer/Shared/Xcode/Plug-ins

1. Relaunch __Xcode__, if you saw a block caret in __Xcode__. It means the plugin is working.

4. ### If you've been using the SIMBL version, make sure the xVim plugin in ~/Library/Application Support/SIMBL/Plugins is deleted !!! You can also remove SIMBL if you don't need it anymore.

## How to use it (for other apps)

1. Make sure you really want vim binding in other apps (since there're Chocolat, Vico, SubmlineText2, which already have vim inside them).

1. Install [__SIMBL__](http://www.culater.net/software/SIMBL/SIMBL.php). 

1. Download or fork xVim (Only use the __master__ branch)

1. __Build__ xVim with __xVim-SIMBL Scheme__. Confirm there's a __xVim.xcplugin__ in the location : ~/Library/Application Support/SIMBL/Plugins/

1. Check out the [wiki](https://github.com/WarWithinMe/xVim/wiki/Supported-Application) to see how to make it work in other app.

1. __Relaunch the app__, if you saw a block caret in your text editor. It probably means xVim is working fine.

## What I'm not going to implement
1. __Marker__
1. __Marco__
1. __Register__ (So you can't yank different text to different register)
1. __Folding__ (and basically any other thing that's not relevant to key-binding)

## What works so far
1. Insert Mode
2. Replace Mode
3. Visual Mode [since v0.2]
4. Normal Mode ([Check out the supported mode command here](https://github.com/WarWithinMe/xVim/wiki/Supported-Commands))
5. Simplified Key-map ([Read the wiki](https://github.com/WarWithinMe/xVim/wiki/Simplified-Key-map))
6. Big thanks to [fileability](https://github.com/fileability), [3 Ex commands](https://github.com/WarWithinMe/xVim/wiki/Supported-Commands) and search with `/?` works !!!

## NOTE
1. This plugin won't work with MS line ending(CR/LF).
   
2. yYdDcCxX will copy the content to internal kill buffer. And pP will only paste something, if that buffer is not empty.  If you want to use the clipboard, use Ctrl+C (Copy), Ctrl+X (Cut), Ctrl+V (Paste)

## TODO
* Handle __replace mode__ properly.
