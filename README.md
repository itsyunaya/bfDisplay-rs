# bfDisplay-rs 

[![Releases](https://img.shields.io/github/v/release/catboylei/bfDisplay-rs?style=flat-square&color=orange)](https://github.com/catboylei/bfDisplay-rs/releases)

[![Neovim](https://img.shields.io/badge/Neovim-plugin-57A143?style=flat-square&logo=neovim)](https://neovim.io/)
[![Built with Rust](https://img.shields.io/badge/built%20with-Rust-b7410e?style=flat-square&logo=rust)](https://www.rust-lang.org/)
[![TypeScriptToLua](https://img.shields.io/badge/Lua-via%20TSTL-2C2D72?style=flat-square&logo=lua)](https://github.com/TypeScriptToLua/TypeScriptToLua)

[![BF Compliant](https://img.shields.io/badge/Brainfuck-Spec%20compliant-ff69b4?style=flat-square)](https://brainfuck.org/)

A Neovim plugin for live brainfuck debugging, powered by a Rust backend via msgpack-RPC.

As you move your cursor through a .bf file, the plugin displays the state of the tape up to that point in the top split, 
showing cell indices, values, the pointer position, and a warning if an infinite loop is detected.

Also includes a simple interpreter that handles i/o, and configurable syntax highlighting.

![img.png](assets/readme.png)

After you have the plugin installed, just run nvim on a ```.bf```, ```.b```, or ```.brainfuck```  file to initiate the display

(you can disable the plugin autostarting on brainfuck files in the config)

**Disclaimers:**
- the lua code is "written" by compiling ts into lua through [TypeScriptToLua](https://github.com/TypeScriptToLua/TypeScriptToLua), and is completely unreadable.  
Id recommend looking at the ts source if you wanna look at source code, that is also why i am not shipping the compiled lua directly,
outside of releases for lazy.nvim. 
- this is still in early development, i have been solving every bug and oversight i found so far, but i probably still missed
some things

---

## Installation

You may either manually install the files, install them through lazy.nvim, or use the flake if you are on Nix

if you opt for a manual installation, the baseline is you need **BOTH** compiled files in your nvim plugins directory, 
as well as calling the plugin in your init.lua.


### Option 1 - lazy.nvim (recommended)

Add this to your lazy plugins: 
```lua
{ "catboylei/bfDisplay-rs", build = "bash lazy-install.sh", opts = {} }
```
Once that is added, run :Lazy in nvim to open the lazy gui, where you can rebuild, update or debug this plugin!

Note: the build step is necessary, it downloads the actual binaries from releases since 
lazy obviously does not natively support compiling rust

### Option 2 - Nix Flake

Add it to your flake inputs like so:
```nix
inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    #...
    bfdisplay-rs.url = "github:catboylei/bfdisplay-rs";
    #...
};
```

Use it either directly or through an overlay:
```nix
# direct
inputs.bfdisplay-rs.packages."${stdenv.hostPlatform.system}".default

# overlay
nixpkgs.overlays = [ inputs.bfdisplay-rs.overlays.default ];
# makes pkgs.bfdisplay-rs available
```

Then apply, e.g. in Nixvim:
```nix
programs.nixvim.extraPlugins = [ pkgs.bfdisplay-rs ];
programs.nixvim.extraConfigLua = ''require("bfDisplay-rs").setup()'';
```

### Option 3 - Manual Download

Go into [Releases](https://github.com/catboylei/bfDisplay-rs/releases), grab both a ```bfDisplay-rs.lua``` file and a ```bfDisplay``` compiled binary,
and simply place them in ```~/.config/nvim/lua/```

You then also need to make the binary executable manually:
```bash
chmod +x bfDisplay
```

Then add to ```init.lua```:
```lua
require("bfDisplay-rs").setup()
```

### Option 4 - Manual Compilation (requires tstl and cargo)

This is the better option if you wish to edit constants or other customizations, simply clone the repo and then run the Makefile:

```bash
git clone https://github.com/catboylei/bfDisplay-rs.git
# cd into the main directory
make build
```
The makefile only serves to run cargo & tstl, then cp the compiled files into the nvim directory.

Then add to ```init.lua```:
```lua
require("bfDisplay-rs").setup()
```
---

## Why Rust ? 

**Neovim (and its plugins) are single-threaded.** 

This means that plugins running in nvim, will run alongside it on the same thread. This essentially means that any calculations or
actions that a plugin may execute will freeze neovim for their duration.

This is usually not too much of an issue, but for interpreters or anything that takes a decent amount of computing power, 
this very quickly becomes an issue if you run any calculations on a regular basis (eg. recalculating the tape on cursor move)

On top of this, nvim plugins are typically written in lua. While lua is on the faster side of high-level languages, it is still an interpreted
language whose speed does NOT compare to a compiled binary.

To remedy these issues, this plugin delegates most of its calculations and logic to a rust binary, using it as a backend with
```vim.fn.rpcnotify``` to send information to it and then keep running nvim.

Important to note that this uses ```vim.fn.rpcnotify``` which is **non-blocking** and then handle the result later, as opposed to
```vim.fn.rpcrequest``` which blocks the thread until it gets an answer (defeats the entire point)

---

## Brainfuck spec compliance + specificities

- correctly passed all compliance tests from https://brainfuck.org/
- Tape has 30,000 cells, each holding an unsigned wrapping 8 bit integer
- Pointer wraps around when going under 0 or over 29,999
- Unmatched brackets are silently ignored\
*this allows the debugger to work correctly as code is being written and is intentional*
- Live approximative infinite loop detection (max step limit, default is 1,000,000) 
- Step limit of the interpreter is 1,000,000,000

---

## Commands

```lua
:Bfrs start -- Force start the plugin
:Bfrs stop -- Force stop the plugin
:Bfrs ping -- Check if the backend is reached
:Bfrs run <input> -- Display output with given input 
:Bfrs config -- Opens config file
:Bfrs default <new input> -- Change the default input for cell display
```
---

## Customization

This plugin comes with various customization constants, that you can edit by running :Bfrs config

They will default to the values listed here if the custom value is wrong.
```lua
return {
    ENABLED = true, -- whether the plugin setups at all
    AUTOSTART = true,  -- whether to autostart when opening a file with the below extensions
    PATTERNS = {"*.bf", "*.b", "*.brainfuck"}, -- file extensions (you can also use * for all)
    DISPLAY_ROWS = 1, -- amount of rows that the live cell display should show
    CELL_DISPLAY = true, -- whether the cell display should be rendered and calculated
    SYNTAX_HIGHLIGHT = true, -- whether syntax highlight should be rendered
    
    -- theme settings, use nil for user theme -- 
    OPERATOR_COLOR = nil, -- color for +-
    POINTER_COLOR = nil, -- color for <>
    IO_COLOR = nil, -- color for .,
    LOOP_COLOR = nil, -- color for []
    OTHER_COLOR = nil, -- color for every other character
}
```

### Home Manager Module

If you use [nixvim](https://github.com/nix-community/nixvim), you can configure the plugin through its
Home Manager module:

```nix
programs.nixvim = {
    enable = true;
    
    plugins.bfdisplay-rs = {
        enable = true;
        
        # contains all options
        settings = {
            enabled = true;
            autostart = true;
            patterns = [ "*.bf" "*.b" "*.brainfuck" ];
            displayRows = 1;
            cellDisplay = true;
            syntaxHighlight = true;
            
            # example for setting a colour
            operatorColor = "#ffceff";
            pointerColor = null;
            ioColor = null;
            loopColor = null;
            otherColor = null;
        };
    };
};
```

---
## Examples

Running rot13 from [brainfuck.org](https://brainfuck.org/rot13.b) with "~mlk zyx" as input:
![img.png](assets/img.png)
Running numwarp from [brainfuck.org](https://brainfuck.org/numwarp.b) with "6" as input:
![img_1.png](assets/img_1.png)

## Todos

- linter... ?
- default input for cell display
- step through debug :3
- comment backend
- more settings ig
