#+vet explicit-allocators

package game

import k2 "../libs/karl2d/"

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:time"

WINDOW_SIZE :: 1000
GRID_WIDTH :: 20
CELL_SIZE :: 16
CANVAS_SIZE :: GRID_WIDTH * CELL_SIZE
TICK_RATE :: 0.25
Vec2i :: [2]int
MAX_SNAKE_LENGTH :: GRID_WIDTH * GRID_WIDTH
START_SNAKE_LENGTH :: 3

Game_Memory :: struct {
    allocator:      runtime.Allocator,
    start_head_pos: Vec2i,
    snake:          [MAX_SNAKE_LENGTH]Vec2i,
    snake_length:   int,
    tick_timer:     f32,
    move_direction: Vec2i,
    game_over:      bool,
    food_pos:       Vec2i,
    font:           k2.Font,
    food_sprite:    k2.Texture,
    head_sprite:    k2.Texture,
    body_sprite:    k2.Texture,
    tail_sprite:    k2.Texture,
    food_eaten_at:  time.Time,
    started_at:     time.Time,
    prev_time:      time.Time,
    some_number:    int,
    run:            bool,
    debug_draw:     bool,
}

@(private = "file")
g: ^Game_Memory

place_food :: proc() {
    fmt.println("game.odin::place_food")
    occupied: [GRID_WIDTH][GRID_WIDTH]bool

    for i in 0 ..< g.snake_length {
        occupied[g.snake[i].x][g.snake[i].y] = true
    }

    free_cells := make([dynamic]Vec2i, context.temp_allocator)

    for x in 0 ..< GRID_WIDTH {
        for y in 0 ..< GRID_WIDTH {
            if !occupied[x][y] {
                append(&free_cells, Vec2i{x, y})
            }
        }
    }

    if len(free_cells) > 0 {
        random_cell_index := rand.int31_max(i32(len(free_cells)))
        g.food_pos = free_cells[random_cell_index]
    }
}

restart :: proc() {
    fmt.println("game.odin::restart")
    start_head_pos := Vec2i{GRID_WIDTH / 2, GRID_WIDTH / 2}
    g.snake[0] = start_head_pos
    g.snake[1] = start_head_pos - {0, 1}
    g.snake[2] = start_head_pos - {0, 2}
    g.snake_length = START_SNAKE_LENGTH
    g.move_direction = {0, 1}
    g.game_over = false
    place_food()
}

@(export)
game_startup :: proc(allocator: runtime.Allocator) -> (k2_state: rawptr) {
    fmt.println("game.odin::game_startup")
    return k2.init(
        WINDOW_SIZE,
        WINDOW_SIZE,
        "Snake",
        allocator = allocator,
        options = {window_mode = .Windowed_Resizable},
    )
}

@(export)
game_init_state :: proc(k2_state: rawptr, allocator: runtime.Allocator) {
    fmt.println("game.odin::init_game")
    g = new(Game_Memory, allocator)
    g.allocator = allocator
    g.snake_length = START_SNAKE_LENGTH
    g.snake = [MAX_SNAKE_LENGTH]Vec2i{}
    g.tick_timer = TICK_RATE
    g.move_direction = {0, 1}
    g.food_sprite = k2.load_texture_from_bytes(#load("../assets/food.png"))
    g.head_sprite = k2.load_texture_from_bytes(#load("../assets/head.png"))
    g.body_sprite = k2.load_texture_from_bytes(#load("../assets/body.png"))
    g.tail_sprite = k2.load_texture_from_bytes(#load("../assets/tail.png"))
    g.food_eaten_at = time.now()
    g.started_at = time.now()
    g.prev_time = time.now()
    g.game_over = false
    g.run = true
    g.debug_draw = false
    g.some_number = 100

    restart()

    fmt.println("game.odin::init_game::end")
}

@(export)
game_update :: proc() -> bool {
    // fmt.println("game.odin::game_update")
    if !k2.update() {
        return false
    }

    if k2.key_is_held(.Up) || k2.gamepad_button_is_held(0, .Left_Face_Up) {
        g.move_direction = {0, -1}
    }

    if k2.key_is_held(.Down) || k2.gamepad_button_is_held(0, .Left_Face_Down) {
        g.move_direction = {0, 1}
    }

    if k2.key_is_held(.Left) || k2.gamepad_button_is_held(0, .Left_Face_Left) {
        g.move_direction = {-1, 0}
    }

    if k2.key_is_held(.Right) ||
       k2.gamepad_button_is_held(0, .Left_Face_Right) {
        g.move_direction = {1, 0}
    }

    dt := k2.get_frame_time()

    if g.game_over {
        if k2.key_went_down(.Enter) {
            restart()
        }
    } else {
        g.tick_timer -= dt
    }

    if g.tick_timer <= 0 {
        next_part_pos := g.snake[0]
        g.snake[0] += g.move_direction
        head_pos := g.snake[0]

        if head_pos.x < 0 ||
           head_pos.y < 0 ||
           head_pos.x >= GRID_WIDTH ||
           head_pos.y >= GRID_WIDTH {
            g.game_over = true
        }

        for i in 1 ..< g.snake_length {
            cur_pos := g.snake[i]

            if cur_pos == head_pos {
                g.game_over = true
            }

            g.snake[i] = next_part_pos
            next_part_pos = cur_pos
        }

        if head_pos == g.food_pos {
            g.snake_length += 1
            g.snake[g.snake_length - 1] = next_part_pos
            place_food()
            g.food_eaten_at = time.now()
        }

        g.tick_timer = TICK_RATE + g.tick_timer
    }

    k2.clear({76, 53, 83, 255})

    camera := k2.Camera {
        zoom = k2.get_window_scale() * (f32(WINDOW_SIZE) / CANVAS_SIZE),
    }

    k2.set_camera(camera)

    food_pos := k2.Vec2{f32(g.food_pos.x), f32(g.food_pos.y)} * CELL_SIZE
    k2.draw_texture(g.food_sprite, food_pos)

    for i in 0 ..< g.snake_length {
        part_sprite := g.body_sprite
        dir: Vec2i

        if i == 0 {
            part_sprite = g.head_sprite
            dir = g.snake[i] - g.snake[i + 1]
        } else if i == g.snake_length - 1 {
            part_sprite = g.tail_sprite
            dir = g.snake[i - 1] - g.snake[i]
        } else {
            dir = g.snake[i - 1] - g.snake[i]
        }

        origin := k2.rect_middle(k2.get_texture_rect(part_sprite))
        rotation := math.atan2(f32(dir.y), f32(dir.x))

        part_pos := k2.Vec2 {
            f32(g.snake[i].x) * CELL_SIZE + origin.x,
            f32(g.snake[i].y) * CELL_SIZE + origin.y,
        }

        k2.draw_texture(
            part_sprite,
            part_pos,
            origin = origin,
            rotation = rotation,
        )
    }

    if g.game_over {
        k2.draw_text("Game Over!", {4, 4}, 25, k2.RL_RED)
        k2.draw_text("Press Enter to play again", {4, 30}, 15, k2.BLACK)
    }

    score := g.snake_length - START_SNAKE_LENGTH
    score_str := fmt.tprintf("Score: %v", score)
    k2.draw_text(score_str, {4, CANVAS_SIZE - 14}, 10, k2.RL_GRAY)
    k2.present()

    free_all(context.temp_allocator)

    return true
}

@(export)
game_destroy_state :: proc() {
    fmt.println("game.odin::game_destroy_state")
    k2.destroy_texture(g.head_sprite)
    k2.destroy_texture(g.food_sprite)
    k2.destroy_texture(g.body_sprite)
    k2.destroy_texture(g.tail_sprite)

    free(g, g.allocator)
}

@(export)
game_shutdown :: proc() {
    fmt.println("game.odin::game_shutdown")
    k2.shutdown()
}

@(export)
game_should_run :: proc() -> bool {
    // fmt.println("game.odin::game_should_run")
    // when ODIN_OS != .JS {
    //     return false
    // }

    return g.run
}

@(export)
game_memory :: proc() -> ^Game_Memory {
    fmt.println("game.odin::game_memory")
    return g
}

@(export)
game_memory_size :: proc() -> int {
    fmt.println("game.odin::game_memory_size")
    return size_of(Game_Memory)
}

@(export)
game_hot_reloaded :: proc(memory: ^Game_Memory, k2_state: ^k2.State) {
    fmt.println("game.odin::game_hot_reloaded")
    k2.set_internal_state(k2_state)
    g = memory

    restart()
    // Here you can also set your own global variables. A good idea is to make
    // your global variables into pointers that point to something inside `g`.
}

// i guess only force restart supported only hot reloads if there is a new dll???
// @(export)
// game_force_reload :: proc() -> bool {
//     // fmt.println("game.odin::game_force_reload")
//     return k2.key_went_down(.F5)
// }

@(export)
game_force_restart :: proc() -> bool {
    // fmt.println("game.odin::game_force_restart")
    return k2.key_went_down(.F6)
}
