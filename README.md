# rpnspire
An RPN interface for the TI Nspire CX

![Demo Video](doc/demo.gif)

## Features
* [x] RPN interface supporting all of the nspires operators
* [x] Stack manipulation functions (`@pick, @roll, @dup, @swap, @del`)
* [x] Unlimmited* undo and redo (`U` - undo, `R` - redo)
* [x] Autocompletion for functions, variables and units
* [x] A fast numblock driven menu system
* [x] Theming support 🔥 

## Not implemented yet
- [ ] Error handling
- [ ] Writing glue for all of the nspires functions
- [ ] Parsing infix expressions into postfix
- [ ] Correct handling of unicode charactes in the input entry
- [ ] Touchpad support (scrolling etc.)

## What is not working
* It is not possible (yet?) to call TI-Basic Apps from Lua
