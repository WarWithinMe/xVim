# About xVim

* xVim is another [SIMBL](http://www.culater.net/software/SIMBL/SIMBL.php) plugin to provide vim key-binding for  Mac Apps. （See all currently supported appliction __[here](https://github.com/WarWithinMe/xVim/wiki/Supported-Application)__)

* Make sure you are checking xVim's github and stay updated.

* __You may use xVim under the terms of the MIT license.__

## How to use it

1. Install [__SIMBL__](http://www.culater.net/software/SIMBL/SIMBL.php). 

1. Download xVim (You should use the __master__ branch)

1. __Build__ xVim (you should build it with __xVim-Release Scheme__). After that, the bundle may have already been copied to ~/Library/Application Support/SIMBL/Plugins/

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
1. This plugin possibly won't work well with Dos line ending(CR/LF).
   
2. yYdDcCxX will copy the content to internal kill buffer. And pP will only paste something, if that buffer is not empty.  If you want to use the clipboard, use Ctrl+C (Copy), Ctrl+X (Cut), Ctrl+V (Paste)

## TODO
* Handle __replace mode__ properly.
* Add a text control to show command line.
