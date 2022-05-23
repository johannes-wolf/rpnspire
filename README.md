# rpnspire

![rpnspire logo](https://github.com/johannes-wolf/rpnspire/blob/main/doc/logo.png?raw=true)

<p align="center">
    An RPN interface for the TI Nspire CX
</p>

https://raw.githubusercontent.com/johannes-wolf/rpnspire/main/doc/demo.mp4?raw=true

## Usage
### Global
Uppercase letters are used as global shortcuts, even if the input view is focused!

| Key                                      | Function                       |
|------------------------------------------|--------------------------------|
| <kbd>U</kbd>                             | Undo                           |
| <kbd>R</kbd>                             | Redo                           |
| <kbd>C</kbd>                             | Clear stack & input            |
| <kbd>E</kbd>                             | Edit last item                 |
| <kbd>S</kbd><kbd>d</kbd><kbd>[0-9]</kbd> | Duplicate #n stack items       |
| <kbd>S</kbd><kbd>p</kbd><kbd>[0-9]</kbd> | Pick stack item #n             |
| <kbd>S</kbd><kbd>x</kbd><kbd>[0-9]</kbd> | Drop stack item #n             |
| <kbd>S</kbd><kbd>x</kbd><kbd>x</kbd>     | Clear stack                    |
| <kbd>S</kbd><kbd>r</kbd><kbd>[0-9]</kbd> | Roll stack #n times            |
| <kbd>S</kbd><kbd>l</kbd><kbd>[0-9]</kbd> | Create list from last #n items |

### Input
| Key                            | Function                                                                |
|--------------------------------|-------------------------------------------------------------------------|
| <kbd>left</kbd>                | Move cursor left                                                        |
| <kbd>right</kbd>               | Move cursor right                                                       |
| <kbd>up</kbd>                  | Focus stack                                                             |
| <kbd>down</kbd>                | Swap stack 1 & 2                                                        |
| <kbd>ctrl</kbd><kbd>menu</kbd> | Show context menu (WIP)                                                 |
| <kbd>return</kbd>              | Insert special character/operator                                       |
| <kbd>tab</kbd>                 | Start completion for current input                                      |
| <kbd>G</kbd><kbd>left</kbd>    | Go to beginning                                                         |
| <kbd>G</kbd><kbd>right</kbd>   | Go to end                                                               |
| <kbd>G</kbd><kbd>(</kbd>       | Go to previous parenthese or comma or beginning                         |
| <kbd>G</kbd><kbd>)</kbd>       | Go to next parenthese or comma                                          |
| <kbd>G</kbd><kbd>.</kbd>       | Select text between parentheses and or commas (select current argument) |
| <kbd>I</kbd>                   | Insert special                                                          |

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
* [ ] Support for matrices (parser)
* [ ] Touchpad support (scrolling etc.)

## What is not working
* It is not possible to call TI-Basic Apps from Lua
