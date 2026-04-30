package main

import k2 "./libs/karl2d/"
import game "./source/"

import "core:fmt"

main :: proc() {
    fmt.println("main.odin::main")
    init()
    for step() {}
    game.game_shutdown()
}


init :: proc() {
    fmt.println("main.odin::init")
    game.game_init_window()
    game.game_init_game()
}

step :: proc() -> bool {
    // fmt.println("main.odin::step")
    return game.step_game()
}
