# About xVim

* xVim is another [SIMBL](http://www.culater.net/software/SIMBL/SIMBL.php) plugin to provide vim key-binding for Xcode and possibly other application that uses NSTextView.

* There's a [viXcode](https://github.com/robertkrimen/viXcode) plugin, but I don't think it's good enough, so I decided to make another one. The README.md is borrowed from viXcode.

* Most of the functionality is not completed, so make sure you are checking xVim's github and stay updated. Also, feel free to contribute as your name will sure appear at the beginning of the source file.

* __You may use xVim under the terms of the MIT license.__

## How to use it

1. Install SIMBL first. Google is always your best friend if you have no idea what SIMBL is.

2. Download xVim (currently you should use the **noKeyMapSupport** branche)

3. If your XCode is not of v4.2, you may have to edit the xVim-Info.plist,
   change the *MaxBundleVersion* and *MinBundleVersion* of *SIMBLTargetApplications* to cater to your Xcode's version.

4. Build xVim (you may want to build it with Release mode), after building xVim, the bundle may have already been copied to ~/Library/Application Support/SIMBL/Plugins/

5. Relaunch XCode, if you saw a block caret in your text editor. It probably means xVim is working fine.

## What I'm not going to implement
1. __Search and Replace__ (I think it's easier to use the built-in support of the editor, but if I have spare time, maybe I will think of implementing it.)
1. __Marker__
1. __Marco__
1. __Register__ (So you can't yank different text to different register)
1. __Folding__ (and basically any other thing that's not relevant to key-binding)

## What works so far
##### Commands in normal mode（ <span># Means you can enter a number, e.g. <code>12l</code> to move right 12 times</span>）
<table>
<col align="center" />
<col align="left" />
<thead>
</thead>
<tbody>
<tr>
	<td align="center"><code>#h</code></td>
	<td align="left">Moves caret left</td>
</tr>
<tr>
	<td align="center"><code>#j</code></td>
	<td align="left">Moves caret down</td>
</tr>

<tr>
	<td align="center"><code>#k</code></td>
	<td align="left">Moves caret up</td>
</tr>
<tr>
	<td align="center"><code>#l</code></td>
	<td align="left">Moves caret right</td>
</tr>

<tr>
	<td align="center"><code>&nbsp;i</code></td>
	<td align="left">Enters insert mode</td>
</tr>
<tr>
	<td align="center"><code>&nbsp;I</code></td>
	<td align="left">Enters insert mode at the start of the indentation of current line</td>
</tr>

<tr>
	<td align="center"><code>&nbsp;a</code></td>
	<td align="left">Enters insert mode after the current character</td>
</tr>
<tr>
	<td align="center"><code>&nbsp;A</code></td>
	<td align="left">Enters insert mode at the end of line</td>
</tr>

<tr>
	<td align="center"><code>&nbsp;o</code></td>
	<td align="left">Opens a new line below, auto indents, and enters insert mode</td>
</tr>
<tr>
	<td align="center"><code>&nbsp;O</code></td>
	<td align="left">Opens a new line above, auto indents, and enters insert mode</td>
</tr>

<tr>
	<td align="center"><code>&nbsp;r</code></td>
	<td align="left">Enters single replace mode (insert mode with overtype enabled).</td>
</tr>
<tr>
	<td align="center"><code>&nbsp;R</code></td>
	<td align="left">Enters replace mode (insert mode with overtype enabled).</td>
</tr>

<tr>
	<td align="center"><code>&nbsp;0</code></td>
	<td align="left">Move to start of current line</td>
</tr>
<tr>
	<td align="center"><code>&nbsp;$</code></td>
	<td align="left">Move to end of current line</td>
</tr>
<tr>
	<td align="center"><code>&nbsp;^</code></td>
	<td align="left">Move to the start of indentation on current line.</td>
</tr>
<tr>
	<td align="center"><code>&nbsp;_</code></td>
	<td align="left">The same as <code>^</code></td>
</tr>

<tr>
	<td align="center"><code>&nbsp;H</code></td>
	<td align="left">Goto first visible line</td>
</tr>
<tr>
	<td align="center"><code>&nbsp;M</code></td>
	<td align="left">Goto the middle of the screen</td>
</tr>
<tr>
	<td align="center"><code>&nbsp;L</code></td>
	<td align="left">Goto last visible line</td>
</tr>
<tr>
	<td align="center"><code>#G</code></td>
	<td align="left">Goto last line, or line number (e.g. 12G goes to line 12), 0G means goto last line.</td>
</tr>

<tr>
	<td align="center"><code>#u</code></td>
	<td align="left">undo</td>
</tr>
<tr>
	<td align="center"><code>#U</code></td>
	<td align="left">redo</td>
</tr>

<tr>
	<td align="center"><code>#J</code></td>
	<td align="left">Join this line with the one(s) under it.</td>
</tr>

<tr>
	<td align="center"><code>#x</code></td>
	<td align="left">Delete character under caret, and put the deleted chars into clipboard.</td>
</tr>
<tr>
	<td align="center"><code>#X</code></td>
	<td align="left">Delete character before caret (backspace), and put the deleted chars into clipboard</td>
</tr>

<tr>
	<td align="center"><code>#p</code></td>
	<td align="left">Paste text after the caret</td>
</tr>
<tr>
	<td align="center"><code>#P</code></td>
	<td align="left">Paste text</td>
</tr>

<tr>
	<td align="center"><code>#w</code></td>
	<td align="left">Moves to the start of the next word</td>
</tr>
<tr>
	<td align="center"><code>#b</code></td>
	<td align="left">Moves (back) to the start of the current (or previous) word.</td>
</tr>
<tr>
	<td align="center"><code>#e</code></td>
	<td align="left">Moves to the end of the current (or next) word.</td>
</tr>
<tr>
	<td align="center"><code>#WBE</code></td>
	<td align="left">Similar to wbe commands, but words are separated by white space, so ABC+X(Y) is considered a single word.</td>
</tr>

<tr>
	<td align="center"><code>gg</code></td>
	<td align="left">Goto first line in file</td>
</tr>
<tr>
	<td align="center"><code>zz</code></td>
	<td align="left">Scroll view so current line is in the middle</td>
</tr>

<tr>
	<td align="center"><code>#y#y</code></td>
	<td align="left">Yank whole lines, acts like <code>#Y</code></td>
</tr>
<tr>
	<td align="center"><code>#d#d</code></td>
	<td align="left">Yank and delete who lines</td>
</tr>
<tr>
	<td align="center"><code>#c#c</code></td>
	<td align="left">Yank and delete who lines, then enter insert mode</td>
</tr>

</tbody>
</table>
##### Supported motions: [ydc] + ([iav] + ) [wW]
##### Going to support:  [ydc] + ([iav] + ) [{[(<'">)]}]
example usage: "diw" to delete a word. 

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
