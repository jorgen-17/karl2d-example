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
START_POS :: Vec2{132, 140}

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
    pos:      Vec2,
    dir:      Vec2,
    collided: bool, // has collided with wall or interactible
    age:      int,
}

Score :: struct {
    hits:   int,
    misses: int,
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
    Grass,
    Wall,
    Ground,
}

tile_walkable_lookup := [Tile_Type]bool {
    .Grass  = true,
    .Ground = true,
    .Wall   = false,
}

tile_color_lookup := [Tile_Type]k2.Color {
    .Grass  = k2.GREEN,
    .Ground = k2.LIGHT_GRAY,
    .Wall   = k2.WHITE,
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
    type:     Interactable_Type,
    pos:      Vec2,
    collider: k2.Rect,
    health:   int,
}

interactible_start_health_lookup := [Interactable_Type]int {
    .Target = 2,
    .Enemy  = 4,
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
    allocator:      runtime.Allocator,
    player:         Player,
    bullets:        [dynamic]Bullet,
    all_colliders:  [dynamic]k2.Rect, // captures walls and target
    wall_colliders: [dynamic]k2.Rect, // only captures walls
    room:           Room,
    font:           k2.Font,
    game_camera:    k2.Camera,
    ui_camera:      k2.Camera,
    live_targets:   int,
    start_time:     time.Time,
    stop_time:      time.Time,
    score:          Score,
    game_over:      bool,
    run:            bool,
    pause:          bool,
    debug_draw:     bool,
}

@(private = "file")
g: ^Game_Memory

player_start :: proc() -> Player {
    return Player {
        pos = START_POS,
        dir = .North,
        move_dir = vec2_from_direction[.North],
        shot = false,
        last_shot = time.now(),
    }
}

create_target :: proc(pos: Vec2) -> Interactable {
    return Interactable {
        type = .Target,
        pos = pos,
        health = interactible_start_health_lookup[.Target],
    }
}

// odinfmt: disable
level_1 :: proc() -> Room {
    target1 := create_target({70, 34})
    target2 := create_target({34, 82})
    target3 := create_target({70, 110})
    target4 := create_target({162, 62})
    target5 := create_target({162, 98})
    interactibles : [dynamic]Interactable
    append(&interactibles, target1)
    append(&interactibles, target2)
    append(&interactibles, target3)
    append(&interactibles, target4)
    append(&interactibles, target5)
    return Room {
        tiles = [ROOM_TILE_WIDTH * ROOM_TILE_HEIGHT]Tile_Type {
            .Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,
            .Grass ,.Wall  ,.Wall  ,.Wall  ,.Wall  ,.Wall  ,.Wall  ,.Wall  ,.Wall  ,.Wall  ,.Wall  ,.Wall  ,.Wall  ,.Wall  ,.Grass ,
            .Grass ,.Wall  ,.Ground,.Ground,.Ground,.Wall  ,.Ground,.Ground,.Ground,.Ground,.Ground,.Ground,.Ground,.Wall  ,.Grass ,
            .Grass ,.Wall  ,.Ground,.Ground,.Ground,.Ground,.Ground,.Ground,.Ground,.Wall  ,.Ground,.Ground,.Ground,.Wall  ,.Grass ,
            .Grass ,.Wall  ,.Wall  ,.Wall  ,.Wall  ,.Wall  ,.Wall  ,.Ground,.Ground,.Wall  ,.Ground,.Ground,.Ground,.Wall  ,.Grass ,
            .Grass ,.Wall  ,.Ground,.Ground,.Ground,.Wall  ,.Ground,.Ground,.Ground,.Wall  ,.Wall  ,.Ground,.Ground,.Wall  ,.Grass ,
            .Grass ,.Wall  ,.Ground,.Ground,.Ground,.Ground,.Ground,.Ground,.Ground,.Wall  ,.Ground,.Ground,.Ground,.Wall  ,.Grass ,
            .Grass ,.Wall  ,.Ground,.Ground,.Ground,.Wall  ,.Ground,.Ground,.Ground,.Wall  ,.Ground,.Ground,.Ground,.Wall  ,.Grass ,
            .Grass ,.Wall  ,.Wall  ,.Wall  ,.Wall  ,.Wall  ,.Wall  ,.Wall  ,.Ground,.Wall  ,.Wall  ,.Wall  ,.Wall  ,.Wall  ,.Grass ,
            .Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,
        },
        interactables = interactibles
    }
}
// odinfmt: enable

restart :: proc() {
    fmt.println("game.odin::restart")
    g.player = player_start()
    g.room = level_1()
    live_targets := 0
    for inter in g.room.interactables {
        if (inter.type == .Target || inter.type == .Enemy) &&
           inter.health > 0 {
            live_targets += 1
        }
    }
    g.live_targets = live_targets
    g.score = Score {
        hits   = 0,
        misses = 0,
    }
    start_time := time.now()
    g.start_time = start_time
    g.stop_time = start_time
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
       (time.duration_milliseconds(time.since(g.player.last_shot)) > 150) {
        g.player.shot = true
        g.player.last_shot = time.now()
    }

    if k2.key_went_down(.F2) {
        g.debug_draw = !g.debug_draw
    }
}

update_state :: proc() {
    frame_time := k2.get_frame_time()
    // if (frame_time > 0.003) {
    //     fmt.printfln(
    //         "game.odin::update_state: frame_time_spike: %f",
    //         frame_time,
    //     )
    // }
    // work around for large frame time spikes that are yeeting the player outside of view
    frame_time = min(frame_time, 0.005)

    mouse_pos := k2.screen_to_world(k2.get_mouse_position(), g.game_camera)
    player_center := Vec2 {
        g.player.pos.x + (PLAYER_WIDTH / 2),
        g.player.pos.y + (PLAYER_HEIGHT / 2),
    }
    player_mouse_delta := mouse_pos - player_center
    if player_mouse_delta.y < 0 &&
       (abs(player_mouse_delta.y) > abs(player_mouse_delta.x)) {
        g.player.dir = .North
    }
    if player_mouse_delta.y > 0 &&
       (abs(player_mouse_delta.y) > abs(player_mouse_delta.x)) {
        g.player.dir = .South
    }
    if player_mouse_delta.x > 0 &&
       (abs(player_mouse_delta.x) > abs(player_mouse_delta.y)) {
        g.player.dir = .East
    }
    if player_mouse_delta.x < 0 &&
       (abs(player_mouse_delta.x) > abs(player_mouse_delta.y)) {
        g.player.dir = .West
    }
    // if k2.mouse_button_went_down(.Left) {
    //     fmt.printfln(
    //         "game.odin::update_state: player_center x:%f,y:%f",
    //         player_center.x,
    //         player_center.y,
    //     )
    //     fmt.printfln(
    //         "game.odin::update_state: mouse_pos x:%f,y:%f",
    //         mouse_pos.x,
    //         mouse_pos.y,
    //     )
    //     fmt.printfln(
    //         "game.odin::update_state: player_mouse_delta x:%f,y:%f",
    //         player_mouse_delta.x,
    //         player_mouse_delta.y,
    //     )
    // }

    // calculate colliders
    all_colliders := make([dynamic]k2.Rect, context.temp_allocator)
    wall_colliders := make([dynamic]k2.Rect, context.temp_allocator)
    for tile_type, tile_idx in g.room.tiles {
        if tile_walkable_lookup[tile_type] {
            continue
        }

        tile_pos := k2.Vec2 {
            f32(tile_idx % ROOM_TILE_WIDTH) * TILE_SIZE,
            f32(tile_idx / ROOM_TILE_WIDTH) * TILE_SIZE,
        }

        tile_rect := k2.rect_from_pos_size(tile_pos, {TILE_SIZE, TILE_SIZE})
        append(&all_colliders, tile_rect)
        append(&wall_colliders, tile_rect)
    }
    for &inter in g.room.interactables {
        r := k2.rect_from_pos_size(inter.pos, {PLAYER_WIDTH, PLAYER_HEIGHT})
        inter.collider = r

        // target || enemy is down so player can walk over them
        if (inter.type == .Target || inter.type == .Enemy) &&
           inter.health > 0 {
            append(&all_colliders, r)
        }
    }
    g.all_colliders = all_colliders
    g.wall_colliders = wall_colliders

    to_move := g.player.move_dir * frame_time * 50
    g.player.pos.x += to_move.x

    for c in all_colliders {
        pc := calc_player_collider(g.player.pos)
        overlap, overlapping := k2.rect_overlap(pc, c)

        if overlapping && overlap.w != 0 {
            sign: f32 = pc.x + pc.w / 2 < (c.x + c.w / 2) ? -1 : 1
            fix := overlap.w * sign
            g.player.pos.x += fix
        }
    }

    g.player.pos.y += to_move.y

    for c in all_colliders {
        pc := calc_player_collider(g.player.pos)
        overlap, overlapping := k2.rect_overlap(pc, c)

        if overlapping && overlap.h != 0 {
            sign: f32 = pc.y + pc.h / 2 < (c.y + c.h / 2) ? -1 : 1
            fix := overlap.h * sign
            g.player.pos.y += fix
        }
    }

    // helps debug player movedment
    // fmt.printfln(
    //     "game.odin::update_state: player moved to: x:%f,y:%f with direction: x:%f,y:%f",
    //     g.player.pos.x,
    //     g.player.pos.y,
    //     g.player.move_dir.x,
    //     g.player.move_dir.y,
    // )
    g.player.move_dir = Vec2{0, 0}

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

    // update bullet positions and age
    for &bullet in g.bullets {
        bullet.pos += bullet.dir * frame_time * 250
        bullet.age += 1

        check_bullet_collisions(&bullet)
    }

    // delete bullets they collided with something or after 600 frames
    for pidx := 0; pidx < len(g.bullets); pidx += 1 {
        p := &g.bullets[pidx]

        if p.collided || p.age >= 600 {
            g.score.misses += p.age >= 600 ? 1 : 0
            unordered_remove(&g.bullets, pidx)
            pidx -= 1
        }
    }

    // spawn new bullets if when player shoots
    if (g.player.shot) {
        fmt.println("game.odin::update_state: player shot")
        bullet_dir := calc_bullet_dir(bullet_pos)
        bullet := Bullet {
            dir      = bullet_dir,
            pos      = bullet_pos,
            collided = false,
            age      = 0,
        }
        append(&g.bullets, bullet)
        g.player.shot = false
    }

    if g.live_targets == 0 && g.start_time == g.stop_time {
        g.stop_time = time.now()
    }
}

check_bullet_collisions :: proc(bullet: ^Bullet) {
    bullet_rect := k2.Rect {
        x = bullet.pos.x - 0.5,
        y = bullet.pos.y - 0.5,
        w = 1,
        h = 1,
    }

    for c in g.wall_colliders {
        _, overlapping := k2.rect_overlap(bullet_rect, c)

        if (overlapping) {
            bullet.collided = true
            g.score.misses += 1
        }
    }

    for &inter in g.room.interactables {
        _, overlapping := k2.rect_overlap(bullet_rect, inter.collider)

        if (overlapping && inter.health > 0) {
            bullet.collided = true
            inter.health -= 1
            g.score.hits += 1
            if inter.health == 0 {
                g.live_targets -= 1
            }
        }
    }
}

calc_bullet_dir :: proc(bullet_pos: Vec2) -> Vec2 {
    mouse_pos := k2.screen_to_world(k2.get_mouse_position(), g.game_camera)
    mouse_bullet_delta := mouse_pos - bullet_pos
    norm_mouse_bullet_delta := linalg.normalize0(mouse_bullet_delta)
    // fmt.printfln(
    //     "game.odin::calc_bullet_dir: mouse_pos x:%f,y:%f",
    //     mouse_pos.x,
    //     mouse_pos.y,
    // )
    // fmt.printfln(
    //     "game.odin::calc_bullet_dir: mouse_bullet_delta x:%f,y:%f",
    //     mouse_bullet_delta.x,
    //     mouse_bullet_delta.y,
    // )
    // fmt.printfln(
    //     "game.odin::calc_bullet_dir: norm_mouse_bullet_delta x:%f,y:%f",
    //     norm_mouse_bullet_delta.x,
    //     norm_mouse_bullet_delta.y,
    // )
    return norm_mouse_bullet_delta
}

draw :: proc() {
    k2.clear(CLEAR_COLOR)

    k2.set_camera(g.game_camera)
    k2.draw_rect({0, 0, SCREEN_WIDTH, SCREEN_HEIGHT}, GRASS_COLOR)

    draw_room(g.room)
    for interactible in g.room.interactables {

        color := interactible.health > 0 ? k2.RED : k2.BLACK
        k2.draw_rect(
            k2.rect_from_pos_size(
                interactible.pos,
                {PLAYER_WIDTH, PLAYER_HEIGHT},
            ),
            color,
        )
    }

    player_rect := k2.rect_from_pos_size(
        g.player.pos,
        {PLAYER_WIDTH, PLAYER_HEIGHT},
    )
    k2.draw_rect(player_rect, k2.BLUE)
    k2.draw_rect(g.player.gun_rect, k2.DARK_GRAY)

    if (g.debug_draw) {
        // draw colliders
        for collider in g.all_colliders {
            k2.draw_rect(collider, k2.YELLOW)
        }
    }

    for bullet in g.bullets {
        k2.draw_circle(bullet.pos, 1, k2.LIGHT_YELLOW)
    }

    k2.set_camera(g.ui_camera)
    if g.game_over {
        k2.draw_text("Game Over!", {4, 4}, 25, k2.RL_RED)
        k2.draw_text("Press Enter to play again", {4, 30}, 15, k2.BLACK)
    }

    if g.pause {
        k2.draw_text("Pause", {50, 50}, 25, k2.BLACK)
    }

    targets_remaining := fmt.tprintf("Targets: %i", g.live_targets)
    k2.draw_text(targets_remaining, {10, 4}, 10, k2.WHITE)

    time := get_time_elapsed()
    time_str := fmt.tprintf("Time: %.3f", time)
    k2.draw_text(time_str, {100, 4}, 10, k2.WHITE)

    score := g.score.hits - g.score.misses
    score_str := fmt.tprintf("Score: %v", score)
    k2.draw_text(score_str, {200, 4}, 10, k2.WHITE)

    k2.present()
}

get_time_elapsed :: proc() -> f64 {
    if g.live_targets > 0 {
        return time.duration_seconds(time.since(g.start_time))
    }

    return time.duration_seconds(time.diff(g.start_time, g.stop_time))
}

draw_room :: proc(room: Room) {
    for x in 0 ..< (ROOM_TILE_WIDTH + 1) {
        for y in 0 ..< (ROOM_TILE_HEIGHT + 1) {
            tile_type_lookup :: proc(room: Room, x, y: int) -> Tile_Type {
                if x < 0 ||
                   y < 0 ||
                   x >= ROOM_TILE_WIDTH - 1 ||
                   y >= ROOM_TILE_HEIGHT - 1 {
                    return .Grass
                }

                return room.tiles[y * ROOM_TILE_WIDTH + x]
            }

            // mask := 0
            //
            // if tile_type(x - 1, y - 1) == .Path {
            //     mask |= 1 // TL
            // }
            // if tile_type(x, y - 1) == .Path {
            //     mask |= 2 // TR
            // }
            // if tile_type(x, y) == .Path {
            //     mask |= 4 // BR
            // }
            // if tile_type(x - 1, y) == .Path {
            //     mask |= 8 // BL
            // }
            //
            // txty := DUAL_GRID_MASK_TO_TXTY[mask]
            // tx := txty.x
            // ty := txty.y

            // tile_rect := k2.Rect {
            //     x = f32(x) * TILE_SIZE,
            //     y = f32(y) * TILE_SIZE,
            //     w = TILE_SIZE,
            //     h = TILE_SIZE,
            // }

            // Note the half-tile offset here: This is what "undoes" the half-tile offset that dual
            // tile grids need.
            pos := k2.Vec2 {
                f32(x) * TILE_SIZE, //- TILE_SIZE / 2,
                f32(y) * TILE_SIZE, // - TILE_SIZE / 2,
            }

            tile_type := tile_type_lookup(room, x, y)
            tile_color := tile_color_lookup[tile_type]

            tile_rect := k2.rect_from_pos_size(pos, {TILE_SIZE, TILE_SIZE})
            k2.draw_rect(tile_rect, tile_color)
            // if g.debug_draw {
            //     fmt.printfln(
            //         "drawing tile: idx:%i, idy:%i, pos.x:%f, pos.y:%f tile_type:%i",
            //         x,
            //         y,
            //         tile_rect.x,
            //         tile_rect.y,
            //         tile_type,
            //     )
            // }

            // k2.draw_texture_rect(tileset_path_texture, tile_rect, pos)
        }
    }
}

calc_player_collider :: proc(player_pos: Vec2) -> k2.Rect {
    return {
        player_pos.x,
        player_pos.y + (PLAYER_HEIGHT / 2),
        PLAYER_WIDTH,
        PLAYER_HEIGHT / 2,
    }
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
