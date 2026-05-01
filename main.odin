package main

import game "./source/"

import "core:fmt"

main :: proc() {
    fmt.println("main.odin::main")
    init()
    for step() {}
    shutdown()
}

init :: proc() {
    fmt.println("main.odin::init")
    k2_state := game.game_startup(context.allocator)
    game.game_init_state(k2_state, context.allocator)
}

step :: proc() -> bool {
    // fmt.println("main.odin::step")
    return game.game_update()
}

shutdown :: proc() {
    fmt.println("main.odin::shutdown")
    game.game_destroy_state()
    game.game_shutdown()
}
