# rpnspire

![rpnspire logo](https://github.com/johannes-wolf/rpnspire/blob/main/doc/logo.png?raw=true)

<p align="center">
An RPN interface for the TI Nspire CX
</p>

https://raw.githubusercontent.com/johannes-wolf/rpnspire/main/doc/demo.mp4?raw=true

## Usage

The input field of rpnspire supports autocompletion for functions, variables and units. To trigger completion,
press <kbd>tab</kbd>. Completion uses characters left to the cursor as compeltions prefix. Typing `so<tab>` will
present you the first entry of a list of completion candidates starting with `so`. Pressing <kbd>tab</kbd> multiple times loops through all candidates. To accept a completion press a cursor key (<kbd>left</kbd> or <kbd>right</kbd>) or hit <kbd>enter</kbd> to directly evaluate.

<p align="center">
<img src="https://github.com/johannes-wolf/rpnspire/blob/main/doc/rpn-completion.gif" width="300px"></img>
</p>

Special cursor movement functions are available using bindings starting with <kbd>G</kbd> (e.G. <kbd>G</kbd><kbd>)</kbd> moves up to the next comma or parenthese).

### RPN-Mode

RPN-mode is the default mode of rpnspire. In RPN-mode, pressing an operator or function key submits the current input
and directly evaluates the operator or function pressed. You can enter RPN mode by hitting <kbd>M</kbd><kbd>r</kbd>.

Calling functions from RPN-mode is done by just entering the function name without parentheses.
To set the argument for variable argument functions, use infix syntax (see ALG mode).

<p align="center">
<img src="https://github.com/johannes-wolf/rpnspire/blob/main/doc/rpn-zeros.gif" width="300px"></img>
</p>

### ALG-Mode

ALG-mode is the infix mode of rpnspire. Hitting operator keys in ALG-mode will not evaluate them, but add them at the cursors
position. You can enter ALG mode by hitting <kbd>M</kbd><kbd>a</kbd>.
The input mode is (temporarily) set to ALG-mode as soon as the left side of the cursor is an un-balanced expression,
e.G if it is missing a closing paren or quote.

Example:
``` text
Unbalanced:
(4+x|)
    ^cursor

Balanced:
(4+x)|
     ^cursor
```

To use stack items in ALG expressions, hit <kbd>A</kbd><kbd>[0-9]</kbd> to enter a reference to the stack `@n`, where
n is the stack level. The stack reference will be replaced with the corresponding expression on push.

<p align="center">
<img src="https://github.com/johannes-wolf/rpnspire/blob/main/doc/rpn-ans.gif" width="300px"></img>
</p>

## Options

You can access rpnsprires option dialog by pressing <kbd>menu</kbd> and select `Options>Show...`.
The option menu is navigated using the number keys.

## Bindings

rpnspire uses key-sequences for its bindings. <kbd>A</kbd><kbd>r</kbd> means: Press `A` and then press `r`.
The current sequence of keys pressed (that are part of a binding) is displayed by a dialog at the
top of the screen. Bindings with an asterisk can be repeated by pressing the last key of the sequence again.

### Global

The global shortcuts work from everywhere, regardless of the currently focused view.

| Key                                      | Function                       |
|------------------------------------------|--------------------------------|
| <kbd>U</kbd>                             | Undo                           |
| <kbd>R</kbd>                             | Redo                           |
| <kbd>C</kbd>                             | Clear stack & input            |
| <kbd>E</kbd>                             | Edit selection or top          |
| <kbd>S</kbd><kbd>d</kbd><kbd>[0-9]</kbd> | Duplicate #n stack items       |
| <kbd>S</kbd><kbd>p</kbd><kbd>[0-9]</kbd> | Pick stack item #n             |
| <kbd>S</kbd><kbd>x</kbd><kbd>[0-9]</kbd> | Drop stack item #n             |
| <kbd>S</kbd><kbd>x</kbd><kbd>x</kbd>     | Clear stack                    |
| <kbd>S</kbd><kbd>r</kbd><kbd>[0-9]</kbd> | Roll stack #n times            |
| <kbd>S</kbd><kbd>r</kbd><kbd>r*</kbd>    | Roll stack                     |
| <kbd>S</kbd><kbd>l</kbd><kbd>[0-9]</kbd> | Create list from last #n items |
| <kbd>S</kbd><kbd>l</kbd><kbd>l*</kbd>    | Join two top items             |
| <kbd>V</kbd><kbd>backspace</kbd>         | Delete variable(s) interactive |
| <kbd>V</kbd><kbd>clear</kbd>             | Delete variables a-z           |
| <kbd>V</kbd><kbd>=</kbd>                 | Set variable interactive       |
| <kbd>M</kbd><kbd>a</kbd>                 | Set mode to ALG                |
| <kbd>M</kbd><kbd>r</kbd>                 | Set mode to RPN                |
| <kbd>M</kbd><kbd>m</kbd>                 | Toggle mode                    |

### Input
| Key                              | Function                                                                |
|----------------------------------|-------------------------------------------------------------------------|
| <kbd>left</kbd>                  | Move cursor left                                                        |
| <kbd>right</kbd>                 | Move cursor right                                                       |
| <kbd>up</kbd>                    | Focus stack                                                             |
| <kbd>down</kbd>                  | Swap stack 1 & 2                                                        |
| <kbd>ctrl</kbd><kbd>menu</kbd>   | Show context menu (WIP)                                                 |
| <kbd>return</kbd>                | Insert special character/operator                                       |
| <kbd>tab</kbd>                   | Start completion for current input                                      |
| <kbd>G</kbd><kbd>left</kbd>      | Go to beginning                                                         |
| <kbd>G</kbd><kbd>right</kbd>     | Go to end                                                               |
| <kbd>G</kbd><kbd>(</kbd>         | Go to previous parenthese or comma or beginning                         |
| <kbd>G</kbd><kbd>)</kbd>         | Go to next parenthese or comma                                          |
| <kbd>G</kbd><kbd>.</kbd>         | Select text between parentheses and or commas (select current argument) |
| <kbd>I</kbd>                     | Insert special                                                          |
| <kbd>A</kbd><kbd>[0-9]</kbd>     | Insert stack reference (Ans)                                            |

### Stack
| Key                               | Function                                                        |
|-----------------------------------|-----------------------------------------------------------------|
| <kbd>left</kbd>                   | Roll stack up (1)                                               |
| <kbd>right</kbd>                  | Roll stack down (1)                                             |
| <kbd>up</kbd>                     | Move selection up                                               |
| <kbd>down</kbd>                   | Move selection down, focus input if out of bounds               |
| <kbd>clear</kbd>                  | Clear the stack                                                 |
| <kbd>backspace</kbd>/<kbd>x</kbd> | Delete selected item                                            |
| <kbd>enter</kbd>                  | Duplicate selected item                                         |
| <kbd>=</kbd>                      | Duplicate selected item and reevaluate                          |
| <kbd>c</kbd><kbd>left</kbd>       | Copy selected expression to input                               |
| <kbd>c</kbd><kbd>right</kbd>      | Copy selected result to input                                   |
| <kbd>i</kbd><kbd>left</kbd>       | Insert selected expression into input                           |
| <kbd>i</kbd><kbd>right</kbd>      | Insert selected result into input                               |
| <kbd>3</kbd>                      | Select bottom (oldest)                                          |
| <kbd>7</kbd>                      | Select top (newest)                                             |
| <kbd>5</kbd>                      | Show expression and result fullsreen (exit with <kbd>tab</kbd>) |
| <kbd>tab</kbd>/<kbd>escape</kbd>  | Focus input                                                     |

## Features
* [x] RPN interface supporting (nearly) all of the nspires operators
* [x] Stack manipulation functions (See global keybindings)
* [x] Undo and redo (<kbd>U/R</kbd>)
* [x] Autocompletion for functions, variables and units
* [x] A fast numblock driven menu system
* [x] Nested keyboard shortcuts
* [x] Writing glue for all of the nspires functions
* [x] Correct handling of unicode charactes in the input entry
* [x] Error handling
* [x] Theming support 🔥 

## Not implemented yet
* [ ] Touchpad support (scrolling etc.)

## What is not working
* It is not possible to call TI-Basic Apps from Lua
