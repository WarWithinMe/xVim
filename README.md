# About xVim

* xVim is another [SIMBL](http://www.culater.net/software/SIMBL/SIMBL.php) plugin to provide vim key-binding for Xcode and possibly other application that uses NSTextView.

* There's a [viXcode](https://github.com/robertkrimen/viXcode) plugin, but I don't think it's good enough, so I decided to make another one. The README.md is borrowed from viXcode.

* Most of the functionality is not completed, so make sure you are checking xVim's github and stay updated. Also, feel free to contribute as your name will sure appear at the beginning of the source file.

* __You may use xVim under the terms of the MIT license.__

## How to use it

1. Install __SIMBL__. (Google is always your best friend if you have no idea what SIMBL is.)

2. Download xVim (currently you should use the __noKeyMapSupport__ branch)

3. __Confirm your Xcode version before build__. (only v828 aka Xcode 4.2 has been tested) <p>If you have a different version of Xcode, edit xVim-Info.plist. *MaxBundleVersion* and *MinBundleVersion* of *SIMBLTargetApplications* to cater to your Xcode's version.

4. __Build__ xVim (you may want to build it with __Release  mode__), after building xVim, the bundle may have already been copied to ~/Library/Application Support/SIMBL/Plugins/

5. __Relaunch Xcode__, if you saw a block caret in your text editor. It probably means xVim is working fine.

## What I'm not going to implement
1. __Search and Replace__ (I think it's easier to use the built-in support of the editor, but if I have spare time, maybe I will think of implementing it.)
1. __Marker__
1. __Marco__
1. __Register__ (So you can't yank different text to different register)
1. __Folding__ (and basically any other thing that's not relevant to key-binding)

## What works so far
1. Insert Mode
2. Replace Mode
3. Normal Mode ([Check out the normal mode command here](https://github.com/WarWithinMe/xVim/wiki/Normal-Mode-Command))
4. Simplified Key-map ([Read the wiki](https://github.com/WarWithinMe/xVim/wiki/Simplified-Key-map))

## NOTE
1. This plugin possibly won't work well with Dos line ending(CR/LF).

2. If you have some code block folded in Xcode, xVim will not work fine.
   The bug is unreproducable so far, so I have no idea how to fix it.
   
3. Those things may be different from vim:
   1). yYdDcCxX will copy the content to internal kill buffer. And pP will only paste something, if that buffer is not empty.
       If you want to use the clipboard, use Ctrl+C (Copy), Ctrl+X (Cut), Ctrl+V (Paste)
       
   2). You can force another type by using "v", "V" or CTRL-V just after the motion operator __in vim__. But xVim only supports "v" and it behave differently from vim.

## Something I don't know how to implement
<table>
<tbody>
<tr>
	<td align="center"><code>#.</code></td>
	<td align="left">Repeat last change/insert command (doesn't repeat motions or other things).</td>
</tr>
</tbody>
</table>

## TODO
* Handle __replace mode__ properly.
* Implement __motion commands__
* Implement __simplified key mapping__
* Implement __visual mode__, __ex mode__
* Add a text control to show command line.
