# rpnspire

![rpnspire logo](https://github.com/johannes-wolf/rpnspire/blob/main/doc/logo.png?raw=true)

<p align="center">
An RPN interface for the TI Nspire CX
</p>

## Install

Use the latest build from the GitHub actions.
Releases <= alpha-20 are of an old version of rpn-spire.

## Build

Building rpnspire depends on `luabudler` (install from `npm`).

    make tns

## Usage

The input field of rpnspire supports autocompletion for functions, variables and units. To trigger completion,
press <kbd>tab</kbd>. Completion uses characters left to the cursor as compeltions prefix. Typing `so<tab>` will
present you the first entry of a list of completion candidates starting with `so`. Pressing <kbd>tab</kbd> multiple times loops through all candidates. To accept a completion press a cursor key (<kbd>left</kbd> or <kbd>right</kbd>) or hit <kbd>enter</kbd> to directly evaluate. Completions are sorted by use (see [config/stats.lua]).

<p align="center">
<img src="https://github.com/johannes-wolf/rpnspire/blob/main/doc/rpn-completion.gif" width="300px"></img>
</p>

### RPN-Mode

RPN-mode is the default mode of rpnspire. In RPN-mode, pressing an operator or function key submits the current input
and directly evaluates the operator or function pressed. If the cursor is not at the last position, input mode is set to non-rpn (alg) automatically.

Calling functions from RPN-mode is done by just entering the function name without parentheses.
To set the argument for variable argument functions, use parentheses.

<p align="center">
<img src="https://github.com/johannes-wolf/rpnspire/blob/main/doc/rpn-zeros.gif" width="300px"></img>
</p>

## Settings

See [config/config.lua].

## Bindings

See [config/bindings.lua].

rpnspire uses key-sequences for its bindings. <kbd>.</kbd><kbd>e</kbd> means: Press `.` and then press `e`.
The current sequence of keys pressed (that are part of a binding) is displayed by a dialog at the
top of the screen.

### Input
| Key                          | Function                                                |
|------------------------------|---------------------------------------------------------|
| <kbd>.</kbd><kbd>u</kbd>     | Undo                                                    |
| <kbd>.</kbd><kbd>r</kbd>     | Redo                                                    |
| <kbd>left</kbd>              | Move cursor left; if empty: roll up                     |
| <kbd>right</kbd>             | Move cursor right; if empty: roll down                  |
| <kbd>up</kbd>                | Focus stack                                             |
| <kbd>down</kbd>              | Swap stack 1 & 2                                        |
| <kbd>enter</kbd>             | Submit input; if empty: dup 1                           |
| <kbd>tab</kbd>               | Start completion for current input                      |
| <kbd>.</kbd><kbd>left</kbd>  | Go to beginning                                         |
| <kbd>.</kbd><kbd>right</kbd> | Go to end                                               |
|------------------------------|---------------------------------------------------------|
| <kbd>.</kbd><kbd>=</kbd>     | Store Y in X                                            |
| <kbd>.</kbd><kbd>s</kbd>     | Store                                                   |
| <kbd>.</kbd><kbd>x</kbd>     | Solve                                                   |
| <kbd>.</kbd><kbd>e</kbd>     | Edit last expression                                    |
| <kbd>.</kbd><kbd>l</kbd>     | Push list                                               |
| <kbd>.</kbd><kbd>,</kbd>     | Join X and Y as Vector or List (depending on type of Y) |
| <kbd>.</kbd><kbd>{</kbd>     | Push list                   |
|------------------------------|---------------------------------------------------------|
| <kbd>.</kbd><kbd>v</kbd>     | Display variables                                       |
| <kbd>.</kbd><kbd>m</kbd>     | Display apps/tool                                       |

### Stack
| Key                              | Function                                                        |
|----------------------------------|-----------------------------------------------------------------|
| <kbd>left</kbd>                  | Roll stack up (1)                                               |
| <kbd>right</kbd>                 | Roll stack down (1)                                             |
| <kbd>up</kbd>                    | Move selection up                                               |
| <kbd>down</kbd>                  | Move selection down, focus input if out of bounds               |
| <kbd>backspace</kbd>             | Delete selected item                                            |
| <kbd>enter</kbd>                 | Duplicate selected item                                         |
| <kbd>c</kbd>                     | Copy selected expression to input                               |
| <kbd>r</kbd>                     | Copy selected result to input                                   |
| <kbd>7</kbd>                     | Select bottom (oldest)                                          |
| <kbd>3</kbd>                     | Select top (newest)                                             |
| <kbd>tab</kbd>/<kbd>escape</kbd> | Focus input                                                     |

## Features
* [x] RPN interface supporting (nearly) all of the nspires operators
* [x] Stack manipulation functions (See global keybindings)
* [x] Undo and redo (<kbd>.</kbd><kbd>u/r</kbd>)
* [x] Autocompletion for functions, variables and units
* [x] Nested keyboard shortcuts

## What is not working
* It is not possible to call TI-Basic Apps from Lua
