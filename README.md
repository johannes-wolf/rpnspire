# rpnspire
An RPN interface for the TI Nspire CX

https://raw.githubusercontent.com/johannes-wolf/rpnspire/main/doc/demo.mp4

## Usage
### Global
Uppercase letters are used as global shortcuts, even if the input view is focused!

| Key          | Function             |
|--------------|----------------------|
| <kbd>U</kbd> | Undo                 |
| <kbd>R</kbd> | Redo                 |
| <kbd>L</kbd> | Roll stack           |
| <kbd>C</kbd> | Clear stack & input  |
| <kbd>E</kbd> | Edit last item (ALG) |

### Input
| Key                            | Function                           |
|--------------------------------|------------------------------------|
| <kbd>left</kbd>                | Move cursor left                   |
| <kbd>right</kbd>               | Move cursor right                  |
| <kbd>up</kbd>                  | Focus stack                        |
| <kbd>down</kbd>                | Swap stack 1 & 2                   |
| <kbd>ctrl</kbd><kbd>menu</kbd> | Show context menu (WIP)            |
| <kbd>return</kbd>              | Insert special character/operator  |
| <kbd>tab</kbd>                 | Start completion for current input |

### Stack
| Key                            | Function                                                        |
|--------------------------------|-----------------------------------------------------------------|
| <kbd>left</kbd>                | Roll stack up                                                   |
| <kbd>right</kbd>               | Roll stack down                                                 |
| <kbd>up</kbd>                  | Move selection up                                               |
| <kbd>down</kbd>                | Move selection down, focus input if out of bounds               |
| <kbd>backspace</kbd>           | Delete item                                                     |
| <kbd>enter</kbd>               | Duplicate item                                                  |
| <kbd>=</kbd>                   | Duplicate and reevaluate                                        |
| <kbd>r</kbd>                   | Duplicate result                                                |
| <kbd>c</kbd>                   | Copy result to input                                            |
| <kbd>s</kbd>                   | Swap selection with previous                                    |
| <kbd>3</kbd>                   | Select bottom (oldest)                                          |
| <kbd>7</kbd>                   | Select top (newest)                                             |
| <kbd>5</kbd>                   | Show expression and result fullsreen (exit with <kbd>tab</kbd>) |
| <kbd>ctrl</kbd><kbd>menu</kbd> | Show context menu (WIP)                                         |
| <kbd>tab</kbd>                 | Focus input                                                     |

### Special functions
| Name      | Function                               |
|-----------|----------------------------------------|
| @swap     | Swap 1 & 2                             |
| @roll     | Roll                                   |
| @dup      | Duplicate 1                            |
| @dup2     | Duplicate 1 & 2                        |
| @dup3     | Duplicate 1, 2 & 3                     |
| @pick     | Pick 1                                 |
| @pick2    | Pick 2                                 |
| @pick3    | Pick 3                                 |
| @del      | Pop 1                                  |
| *History* |                                        |
| @undo     | Undo                                   |
| *Misc*    |                                        |
| @label    | Set last expression text to @1         |
| @postfix  | Push last expression as postfix string |
| *Macro*   |                                        |
| @mcall    | Call macro @1                          |


## Features
* [x] RPN interface supporting (nearly) all of the nspires operators
* [x] Stack manipulation functions (`@pick, @roll, @dup, @swap, @del`)
* [x] Unlimmited* undo and redo (`U` - undo, `R` - redo)
* [x] Autocompletion for functions, variables and units
* [x] A fast numblock driven menu system
- [x] Support for lists
- [x] Writing glue for all of the nspires functions
* [x] Theming support 🔥 

## Not implemented yet
- [ ] Error handling
- [ ] Support for matrixes (parser)
- [ ] Correct handling of unicode charactes in the input entry
- [ ] Touchpad support (scrolling etc.)

## What is not working
* It is not possible to call TI-Basic Apps from Lua
