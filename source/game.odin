#+vet explicit-allocators

package game

import k2 "../libs/karl2d/"

import "base:runtime"
import "core:fmt"
import "core:math/linalg"
import "core:time"

CLEAR_COLOR :: k2.Color{6, 6, 8, 255}
WALL_COLOR :: k2.WHITE
GRASS_COLOR :: k2.GREEN
GROUND_COLOR :: k2.GRAY
HIGHLIGHT_COLOR :: k2.Color{149, 224, 204, 255}

// We zoom the game up to fit this size
SCREEN_WIDTH :: 240
SCREEN_HEIGHT :: 180
WINDOW_WIDTH :: SCREEN_WIDTH * 4
WINDOW_HEIGHT :: SCREEN_HEIGHT * 4
STATUS_BAR_HEIGHT :: 20

PLAYER_WIDTH: f32 : 8
PLAYER_HEIGHT: f32 : 16
START_POS :: Vec2{30, 100}

Vec2 :: k2.Vec2
Vec2i :: [2]int

Player :: struct {
    pos:       Vec2,
    dir:       Direction,
    move_dir:  Vec2,
    gun_rect:  k2.Rect,
    shot:      bool,
    last_shot: time.Time,
}

Bullet :: struct {
    pos: Vec2,
    dir: Vec2,
    age: f32,
}

// Counted in number of tiles
ROOM_TILE_WIDTH :: 15
ROOM_TILE_HEIGHT :: 10

// Pixel size of a tile
TILE_SIZE :: 16

Room :: struct {
    tiles:         [ROOM_TILE_WIDTH * ROOM_TILE_HEIGHT]Tile_Type,
    // background_objects: [dynamic]Background_Object,
    // foreground_objects: [dynamic]Foreground_Object,
    interactables: [dynamic]Interactable,
}

Tile_Type :: enum {
    Ground,
    Wall,
}

tile_walkable_lookup := [Tile_Type]bool {
    .Ground = true,
    .Wall   = false,
}

Interactable_Type :: enum {
    Target,
    Enemy,
    // Ammo,
    // Med_Kit,
    // Door,
    // The_Object,
}

Interactable :: struct {
    type:   Interactable_Type,
    pos:    Vec2,
    health: int,
}

Direction :: enum {
    East,
    West,
    North,
    South,
}

vec2_from_direction := [Direction]Vec2 {
    .East  = {1, 0},
    .West  = {-1, 0},
    .North = {0, -1},
    .South = {0, 1},
}

Game_Memory :: struct {
    allocator:   runtime.Allocator,
    player:      Player,
    bullets:     [dynamic]Bullet,
    room:        Room,
    font:        k2.Font,
    game_camera: k2.Camera,
    ui_camera:   k2.Camera,
    started_at:  time.Time,
    stop_time:   time.Time,
    game_over:   bool,
    run:         bool,
    pause:       bool,
    debug_draw:  bool,
}

@(private = "file")
g: ^Game_Memory

restart :: proc() {
    fmt.println("game.odin::restart")
    g.player = Player {
        pos       = START_POS,
        dir       = .North,
        move_dir  = vec2_from_direction[.North],
        shot      = false,
        last_shot = time.now(),
    }

    g.started_at = time.now()
    g.stop_time = time.now()
    g.game_over = false
    g.pause = false
}

@(export)
game_startup :: proc(allocator: runtime.Allocator) -> (k2_state: rawptr) {
    fmt.println("game.odin::game_startup")
    return k2.init(
        WINDOW_WIDTH,
        WINDOW_HEIGHT,
        "shoot_house",
        allocator = allocator,
        options = {window_mode = .Windowed_Resizable},
    )
}

@(export)
game_init_state :: proc(k2_state: rawptr, allocator: runtime.Allocator) {
    fmt.println("game.odin::init_game")
    g = new(Game_Memory, allocator)
    g.allocator = allocator
    g.player = {
        pos       = START_POS,
        dir       = .North,
        move_dir  = vec2_from_direction[.North],
        shot      = false,
        last_shot = time.now(),
    }
    g.started_at = time.now()
    g.stop_time = time.now()
    g.game_over = false
    g.run = true
    g.debug_draw = false

    restart()
}

@(export)
game_update :: proc() -> bool {
    if !k2.update() {
        return false
    }

    handle_input()

    g.game_camera = {
        zoom   = f32(k2.get_screen_height()) / SCREEN_HEIGHT,
        target = {0, -STATUS_BAR_HEIGHT},
    }

    g.ui_camera = {
        zoom = f32(k2.get_screen_height()) / SCREEN_HEIGHT,
    }

    k2.set_scissor_rect(
        k2.Rect {
            0,
            0,
            SCREEN_WIDTH * g.game_camera.zoom,
            SCREEN_HEIGHT * g.game_camera.zoom,
        },
    )

    if g.game_over {
        if k2.key_went_down(.Enter) {
            restart()
        }
    }

    if !g.pause {
        update_state()
    }

    draw()

    free_all(context.temp_allocator)

    return true
}

handle_input :: proc() {
    if k2.key_is_held(.W) || k2.gamepad_button_is_held(0, .Left_Face_Up) {
        g.player.move_dir.y -= 1
    }

    if k2.key_is_held(.S) || k2.gamepad_button_is_held(0, .Left_Face_Down) {
        g.player.move_dir.y += 1
    }

    if k2.key_is_held(.A) || k2.gamepad_button_is_held(0, .Left_Face_Left) {
        g.player.move_dir.x = -1
    }

    if k2.key_is_held(.D) || k2.gamepad_button_is_held(0, .Left_Face_Right) {
        g.player.move_dir.x += 1
    }
    g.player.move_dir = linalg.normalize0(g.player.move_dir)

    if k2.key_is_held(.Escape) && !g.game_over {
        g.pause = !g.pause
    }

    if k2.key_is_held(.Q) {
        shutdown()
    }

    if (k2.key_went_down(.Space) || k2.mouse_button_is_held(.Left)) &&
       (time.duration_milliseconds(time.since(g.player.last_shot)) > 100) {
        g.player.shot = true
        g.player.last_shot = time.now()
    }
}

update_state :: proc() {
    frame_time := k2.get_frame_time()
    if (frame_time > 0.003) {
        fmt.printfln(
            "game.odin::update_state: frame_time_spike: %f",
            frame_time,
        )
    }
    // work around for large frame time spikes that are yeeting the player outside of view
    frame_time = min(frame_time, 0.005)

    if g.player.move_dir.x > 0 {
        g.player.dir = .East
    } else if g.player.move_dir.x < 0 {
        g.player.dir = .West
    } else if g.player.move_dir.y > 0 {
        g.player.dir = .South
    } else if g.player.move_dir.y < 0 {
        g.player.dir = .North
    }

    if (g.player.move_dir.x != 0 || g.player.move_dir.y != 0) {
        g.player.pos += g.player.move_dir * frame_time * 50
        fmt.printfln(
            "game.odin::update_state: player moved to: x:%f,y:%f with direction: x:%f,y:%f",
            g.player.pos.x,
            g.player.pos.y,
            g.player.move_dir.x,
            g.player.move_dir.y,
        )
        g.player.move_dir = Vec2{0, 0}
    }

    gun_rect: k2.Rect
    gun_length: f32 = 8
    gun_thickness: f32 = 2
    bullet_pos: Vec2
    switch g.player.dir {
    case .North:
        gun_rect = k2.Rect {
            w = gun_thickness,
            h = gun_length,
            x = g.player.pos.x + PLAYER_WIDTH - gun_thickness,
            y = g.player.pos.y - gun_length,
        }
        bullet_pos = {gun_rect.x, gun_rect.y}
    case .South:
        gun_rect = k2.Rect {
            w = gun_thickness,
            h = gun_length,
            x = g.player.pos.x,
            y = g.player.pos.y + gun_length,
        }
        bullet_pos = {gun_rect.x, gun_rect.y + gun_length}
    case .East:
        gun_rect = k2.Rect {
            w = gun_length,
            h = gun_thickness,
            x = g.player.pos.x + 2,
            y = g.player.pos.y + (PLAYER_HEIGHT / 2),
        }
        bullet_pos = {gun_rect.x + gun_length, gun_rect.y}
    case .West:
        gun_rect = k2.Rect {
            w = gun_length,
            h = gun_thickness,
            x = g.player.pos.x - 2,
            y = g.player.pos.y + (PLAYER_HEIGHT / 2),
        }
        bullet_pos = {gun_rect.x, gun_rect.y}
    }
    g.player.gun_rect = gun_rect

    // delete bullets after 600 frames
    for pidx := 0; pidx < len(g.bullets); pidx += 1 {
        p := &g.bullets[pidx]

        if p.age >= 600 {
            unordered_remove(&g.bullets, pidx)
            pidx -= 1
        }
    }

    // update bullet positions and age
    for &bullet in g.bullets {
        bullet.pos += bullet.dir * frame_time * 250
        bullet.age += 1
    }

    if (g.player.shot) {
        fmt.println("game.odin::update_state: player shot")
        bullet := Bullet {
            dir = vec2_from_direction[g.player.dir],
            pos = bullet_pos,
            age = 0,
        }
        append(&g.bullets, bullet)
        g.player.shot = false
    }
}

draw :: proc() {
    k2.clear(CLEAR_COLOR)

    k2.set_camera(g.game_camera)

    player_rect := k2.Rect {
        x = g.player.pos.x,
        y = g.player.pos.y,
        w = PLAYER_WIDTH,
        h = PLAYER_HEIGHT,
    }
    k2.draw_rect(player_rect, k2.WHITE)
    k2.draw_rect(g.player.gun_rect, k2.GRAY)

    for bullet in g.bullets {
        k2.draw_circle(bullet.pos, 1, k2.LIGHT_YELLOW)
    }

    k2.draw_circle(Vec2{50, 50}, 5, k2.RED)
    k2.draw_circle(Vec2{150, 150}, 5, k2.BLUE)

    if g.game_over {
        k2.draw_text("Game Over!", {4, 4}, 25, k2.RL_RED)
        k2.draw_text("Press Enter to play again", {4, 30}, 15, k2.BLACK)
    }

    if g.pause {
        k2.draw_text("Pause", {50, 50}, 25, k2.BLACK)
    }

    score := 0
    score_str := fmt.tprintf("Score: %v", score)
    k2.draw_text(score_str, {4, WINDOW_WIDTH - 14}, 10, k2.RL_GRAY)

    k2.present()
}

calc_player_collider :: proc(player_pos: Vec2) -> k2.Rect {
    return {player_pos.x - 5, player_pos.y - 6, 10, 6}
}

shutdown :: proc() {
    game_destroy_state()
    game_shutdown()
}

destroy_room :: proc(room: Room) {
    delete(room.interactables)
}

@(export)
game_destroy_state :: proc() {
    fmt.println("game.odin::game_destroy_state")
    destroy_room(g.room)
    delete(g.bullets)
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
