#+vet explicit-allocators

package game

import k2 "../libs/karl2d/"

import "base:runtime"
import "core:fmt"
import "core:math"
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
PLAYER_START_HEALTH: int : 4
START_POS :: Vec2{132, 140}
SHOOT_DEBOUNCE :: 150
AI_SHOT_DELAY :: 250 // time between ai spotting player and taking the first shot

Vec2 :: k2.Vec2
Vec2i :: [2]int

Player :: struct {
    pos:      Vec2,
    dir:      Direction,
    move_dir: Vec2,
    gun_rect: k2.Rect,
    shot:     Debounced_Event,
    health:   int,
}

Bullet :: struct {
    pos:      Vec2,
    dir:      Vec2,
    collided: bool, // has collided with wall or target or player
    age:      int,
}

Score :: struct {
    hits:   int,
    misses: int,
}

Debounced_Event :: struct {
    triggered:      bool,
    last_triggered: time.Time,
}

// Counted in number of tiles
ROOM_TILE_WIDTH :: 15
ROOM_TILE_HEIGHT :: 10

// Pixel size of a tile
TILE_SIZE :: 16

Room :: struct {
    tiles:   [ROOM_TILE_WIDTH * ROOM_TILE_HEIGHT]Tile_Type,
    targets: [dynamic]Target,
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

Target_Type :: enum {
    Paper,
    Enemy,
}

Target :: struct {
    type:        Target_Type,
    id:          int,
    pos:         Vec2,
    dir:         Direction,
    collider:    k2.Rect,
    gun_rect:    k2.Rect,
    shot:        Debounced_Event,
    seen_player: Debounced_Event,
    health:      int,
}

target_start_health_lookup := [Target_Type]int {
    .Paper = 2,
    .Enemy = 4,
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
    elapsed_time:   f32, // time from start to end of level
    score:          Score,
    game_over:      bool,
    practice_round: bool,
    run:            bool,
    pause:          bool,
    debug_draw:     bool,
    show_controls:  bool,
}

@(private = "file")
g: ^Game_Memory

player_start :: proc() -> Player {
    return Player {
        pos = START_POS,
        dir = .North,
        move_dir = vec2_from_direction[.North],
        shot = Debounced_Event{triggered = false, last_triggered = time.now()},
        health = PLAYER_START_HEALTH,
    }
}

create_target :: proc(
    id: int,
    pos: Vec2,
    dir: Direction,
    type: Target_Type,
) -> Target {
    return Target {
        type = type,
        id = id,
        pos = pos,
        dir = dir,
        health = target_start_health_lookup[type],
    }
}

// odinfmt: disable
level_1 :: proc(practice_round: bool) -> Room {
    type : Target_Type = practice_round ? .Paper : .Enemy
    target1 := create_target(1, {102, 34}, .West, type)
    target2 := create_target(2, {34, 82}, .East, type)
    target3 := create_target(3, {70, 110}, .East, type)
    target4 := create_target(4, {162, 62}, .North, type)
    target5 := create_target(5, {162, 98}, .East, type)
    targets : [dynamic]Target
    append(&targets, target1)
    append(&targets, target2)
    append(&targets, target3)
    append(&targets, target4)
    append(&targets, target5)
    return Room {
        tiles = [ROOM_TILE_WIDTH * ROOM_TILE_HEIGHT]Tile_Type {
            .Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,
            .Grass ,.Wall  ,.Wall  ,.Wall  ,.Wall  ,.Wall  ,.Wall  ,.Wall  ,.Wall  ,.Wall  ,.Wall  ,.Wall  ,.Wall  ,.Wall  ,.Grass ,
            .Grass ,.Wall  ,.Ground,.Ground,.Ground,.Ground,.Ground,.Wall  ,.Ground,.Ground,.Ground,.Ground,.Ground,.Wall  ,.Grass ,
            .Grass ,.Wall  ,.Ground,.Ground,.Ground,.Ground,.Ground,.Wall  ,.Ground,.Wall  ,.Ground,.Ground,.Ground,.Wall  ,.Grass ,
            .Grass ,.Wall  ,.Wall  ,.Ground,.Wall  ,.Wall  ,.Wall  ,.Wall  ,.Ground,.Wall  ,.Ground,.Ground,.Ground,.Wall  ,.Grass ,
            .Grass ,.Wall  ,.Ground,.Ground,.Ground,.Ground,.Ground,.Wall  ,.Ground,.Wall  ,.Wall  ,.Ground,.Ground,.Wall  ,.Grass ,
            .Grass ,.Wall  ,.Ground,.Ground,.Ground,.Ground,.Ground,.Ground,.Ground,.Wall  ,.Ground,.Ground,.Ground,.Wall  ,.Grass ,
            .Grass ,.Wall  ,.Ground,.Ground,.Ground,.Ground,.Ground,.Wall  ,.Ground,.Wall  ,.Ground,.Ground,.Ground,.Wall  ,.Grass ,
            .Grass ,.Wall  ,.Wall  ,.Wall  ,.Wall  ,.Wall  ,.Wall  ,.Wall  ,.Ground,.Wall  ,.Wall  ,.Wall  ,.Wall  ,.Wall  ,.Grass ,
            .Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,.Grass ,
        },
        targets = targets
    }
}
// odinfmt: enable

clean_up :: proc() {
    if len(g.room.targets) > 0 {
        destroy_room(g.room)
    }

    for pidx := 0; pidx < len(g.bullets); pidx += 1 {
        unordered_remove(&g.bullets, pidx)
        pidx -= 1
    }
}

restart :: proc() {
    fmt.println("game.odin::restart")
    clean_up()
    g.player = player_start()
    g.room = level_1(g.practice_round)
    live_targets := 0
    for target in g.room.targets {
        if (target.type == .Paper || target.type == .Enemy) &&
           target.health > 0 {
            live_targets += 1
        }
    }
    g.live_targets = live_targets
    g.score = Score {
        hits   = 0,
        misses = 0,
    }
    g.elapsed_time = 0.0
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
    g.practice_round = true
    g.run = true
    g.debug_draw = false
    g.show_controls = true

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

    if !g.pause && !g.game_over && !g.show_controls {
        update_state()
    }

    draw()

    free_all(context.temp_allocator)

    return g.run
}

handle_input :: proc() {
    if g.show_controls && k2.key_went_down(.Enter) {
        g.show_controls = false
    }

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

    if k2.key_went_down(.Escape) && !g.game_over {
        g.pause = !g.pause
    }

    if k2.key_went_down(.Q) {
        g.run = false
    }

    if k2.mouse_button_is_held(.Left) &&
       event_has_debounced(g.player.shot.last_triggered, SHOOT_DEBOUNCE) {
        g.player.shot = Debounced_Event {
            triggered      = true,
            last_triggered = time.now(),
        }
    }

    if k2.key_went_down(.F2) {
        g.debug_draw = !g.debug_draw
    }

    if k2.key_went_down(.F3) {
        g.practice_round = !g.practice_round
        restart()
    }
}

event_has_debounced :: proc(
    last_triggered: time.Time,
    debounce_time: f64,
) -> bool {
    return(
        time.duration_milliseconds(time.since(last_triggered)) >
        debounce_time \
    )
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
    for &target in g.room.targets {
        r := k2.rect_from_pos_size(target.pos, {PLAYER_WIDTH, PLAYER_HEIGHT})
        target.collider = r

        // target || enemy is down so player can walk over them
        if (target.type == .Paper || target.type == .Enemy) &&
           target.health > 0 {
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

    gun_rect, bullet_pos := generate_gun_rect_bullet_pos(
        g.player.dir,
        g.player.pos,
    )
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
    if (g.player.shot.triggered) {
        // fmt.println("game.odin::update_state: player shot")
        bullet_dir := calc_bullet_dir(bullet_pos)
        bullet := Bullet {
            dir      = bullet_dir,
            pos      = bullet_pos,
            collided = false,
            age      = 0,
        }
        append(&g.bullets, bullet)
        g.player.shot.triggered = false
    }

    for &target in g.room.targets {
        if !g.practice_round {
            // add gun rect to target
            gun_rect, bullet_pos = generate_gun_rect_bullet_pos(
                target.dir,
                target.pos,
            )
            target.gun_rect = gun_rect

            if target.health > 0 {     // if target dead, dont shoot
                pc := calc_player_collider(g.player.pos)
                pc_center: Vec2 = {pc.x + pc.w / 2, pc.y + pc.h}
                point_0 := bullet_pos
                point_1 := pc_center
                _, pc_distance := line_k2rect_intersection(
                    point_0,
                    point_1,
                    pc,
                )
                blocked := false // line of sight from bullet_pos to pc_center blocked by a collider
                for collider in g.all_colliders {
                    hit, distance := line_k2rect_intersection(
                        point_0,
                        point_1,
                        collider,
                    )
                    if hit && distance <= pc_distance {
                        blocked = true
                    }
                }
                if !blocked {
                    if !target.seen_player.triggered {
                        target.seen_player.triggered = true
                        target.seen_player.last_triggered = time.now()
                        fmt.printfln("target%i has seen player", target.id)
                    }

                    if target.seen_player.triggered &&
                       !target.shot.triggered &&
                       event_has_debounced(
                           target.seen_player.last_triggered,
                           AI_SHOT_DELAY,
                       ) {
                        fmt.printfln(
                            "target%i seen player after delay",
                            target.id,
                        )
                        target.shot.triggered = true
                    }

                    if target.shot.triggered &&
                       event_has_debounced(
                           target.shot.last_triggered,
                           SHOOT_DEBOUNCE,
                       ) {
                        bullet_dir := linalg.normalize0(pc_center - bullet_pos)
                        bullet := Bullet {
                            dir      = bullet_dir,
                            pos      = bullet_pos,
                            collided = false,
                            age      = 0,
                        }
                        append(&g.bullets, bullet)
                        target.shot.last_triggered = time.now()
                    }

                } else {
                    target.seen_player.triggered = false
                    target.shot.triggered = false
                }
            }
        }
    }

    if g.live_targets > 0 {
        g.elapsed_time += frame_time
    }

    if !g.game_over && g.live_targets <= 0 {
        g.game_over = true
    }
}

line_k2rect_intersection :: proc(p0, p1: Vec2, rect: k2.Rect) -> (bool, f32) {
    rect_min: Vec2 = {rect.x, rect.y}
    rect_max: Vec2 = {rect.x + rect.w, rect.y + rect.h}

    d := p1 - p0
    t_min: f32 = 0.0
    t_max: f32 = 1.0

    // Check each axis (X and Y)
    for i in 0 ..< 2 {
        if d[i] == 0 {
            // Line is parallel to this axis
            if p0[i] < rect_min[i] || p0[i] > rect_max[i] do return false, 0
        } else {
            // Find intersection times with the two planes of this axis
            inv_d := 1.0 / d[i]
            t1 := (rect_min[i] - p0[i]) * inv_d
            t2 := (rect_max[i] - p0[i]) * inv_d

            // Ensure t1 is the entry point and t2 is the exit point
            entry := math.min(t1, t2)
            exit := math.max(t1, t2)

            t_min = math.max(t_min, entry)
            t_max = math.min(t_max, exit)

            // If entry occurs after exit, there is no intersection
            if t_min > t_max do return false, 0
        }
    }

    // t_min is the fractional distance along the segment [0, 1]
    // Actual distance is t_min * length of the segment
    actual_dist := t_min * linalg.length(d)
    return true, actual_dist
}

generate_gun_rect_bullet_pos :: proc(
    player_dir: Direction,
    player_pos: Vec2,
) -> (
    k2.Rect,
    Vec2,
) {
    gun_rect: k2.Rect
    gun_length: f32 = 8
    gun_thickness: f32 = 2
    bullet_pos: Vec2
    switch player_dir {
    case .North:
        gun_rect = k2.Rect {
            w = gun_thickness,
            h = gun_length,
            x = player_pos.x + PLAYER_WIDTH - gun_thickness,
            y = player_pos.y - gun_length,
        }
        bullet_pos = {gun_rect.x, gun_rect.y}
    case .South:
        gun_rect = k2.Rect {
            w = gun_thickness,
            h = gun_length,
            x = player_pos.x,
            y = player_pos.y + gun_length,
        }
        bullet_pos = {gun_rect.x, gun_rect.y + gun_length}
    case .East:
        gun_rect = k2.Rect {
            w = gun_length,
            h = gun_thickness,
            x = player_pos.x + 2,
            y = player_pos.y + (PLAYER_HEIGHT / 2),
        }
        bullet_pos = {gun_rect.x + gun_length, gun_rect.y}
    case .West:
        gun_rect = k2.Rect {
            w = gun_length,
            h = gun_thickness,
            x = player_pos.x - 2,
            y = player_pos.y + (PLAYER_HEIGHT / 2),
        }
        bullet_pos = {gun_rect.x, gun_rect.y}
    }
    return gun_rect, bullet_pos
}

check_bullet_collisions :: proc(bullet: ^Bullet) {
    bullet_rect := k2.Rect {
        x = bullet.pos.x - 0.5,
        y = bullet.pos.y - 0.5,
        w = 1,
        h = 1,
    }
    pc := calc_player_collider(g.player.pos)
    _, pc_overlapping := k2.rect_overlap(bullet_rect, pc)
    if (pc_overlapping) {
        bullet.collided = true
        g.player.health -= 1
        if g.player.health <= 0 {
            g.game_over = true
        }
    }

    for c in g.wall_colliders {
        _, overlapping := k2.rect_overlap(bullet_rect, c)

        if (overlapping) {
            bullet.collided = true
            g.score.misses += 1
        }
    }

    for &target in g.room.targets {
        _, overlapping := k2.rect_overlap(bullet_rect, target.collider)

        if (overlapping && target.health > 0) {
            bullet.collided = true
            target.health -= 1
            g.score.hits += 1
            if target.health <= 0 {
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
    for target in g.room.targets {
        color := target.health > 0 ? k2.RED : k2.BLACK
        k2.draw_rect(
            k2.rect_from_pos_size(target.pos, {PLAYER_WIDTH, PLAYER_HEIGHT}),
            color,
        )
        k2.draw_rect(target.gun_rect, k2.DARK_GRAY)
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
    if g.show_controls {
        k2.draw_rect(
            {50, 50, SCREEN_WIDTH - 90, SCREEN_HEIGHT - 90},
            CLEAR_COLOR,
        )
        k2.draw_text("Move: WASD", {60, 60}, 10, k2.WHITE)
        k2.draw_text("Aim with Mouse, Shoot with LMB", {60, 80}, 10, k2.WHITE)
        k2.draw_text("Score: (Hits: +1, Misses: -1)", {60, 100}, 10, k2.WHITE)
        k2.draw_text("Press Enter to start!", {60, 120}, 10, k2.WHITE)
    }

    if g.game_over {
        menu_width: f32 = SCREEN_WIDTH - 110
        menu_item_width: f32 = menu_width - 20
        menu_item_height: f32 = 10
        k2.draw_rect({50, 50, menu_width, SCREEN_HEIGHT - 130}, CLEAR_COLOR)
        menu_title := g.player.health > 0 ? "Level Cleared!" : "You Died!"
        k2.draw_text(menu_title, {90, 60}, 10, k2.WHITE)
        if ui_button(
            {60, 80, menu_item_width, menu_item_height},
            "Play Again",
            g.ui_camera,
        ) {
            restart()
        }
    }

    if g.pause {
        menu_width: f32 = SCREEN_WIDTH - 110
        menu_item_width: f32 = menu_width - 20
        menu_item_height: f32 = 10
        k2.draw_rect({50, 50, menu_width, SCREEN_HEIGHT - 90}, CLEAR_COLOR)
        k2.draw_text("Menu", {100, 60}, 10, k2.WHITE)
        if ui_button(
            {60, 80, menu_item_width, menu_item_height},
            "Resume",
            g.ui_camera,
        ) {
            g.pause = false
        }
        if ui_button(
            {60, 100, menu_item_width, menu_item_height},
            "Restart",
            g.ui_camera,
        ) {
            restart()
        }
        game_mode_title := g.practice_round ? "Live Fire" : "Practice Round"
        if ui_button(
            {60, 120, menu_item_width, menu_item_height},
            game_mode_title,
            g.ui_camera,
        ) {
            g.practice_round = !g.practice_round
            restart()
        }

    }

    target_title := g.practice_round ? "Targets:" : "Enemies:"
    targets_remaining := fmt.tprintf("%s %i", target_title, g.live_targets)
    k2.draw_text(targets_remaining, {10, 4}, 10, k2.WHITE)

    time := g.elapsed_time
    time_str := fmt.tprintf("Time: %.3f", time)
    k2.draw_text(time_str, {100, 4}, 10, k2.WHITE)

    if g.practice_round {
        score := g.score.hits - g.score.misses
        score_str := fmt.tprintf("Score: %v", score)
        k2.draw_text(score_str, {200, 4}, 10, k2.WHITE)
    } else {
        health := (f32(g.player.health) / f32(PLAYER_START_HEALTH)) * 100.0
        health_str := fmt.tprintf("Health: %.0f%%", health)
        k2.draw_text(health_str, {180, 4}, 10, k2.WHITE)
    }

    k2.present()
}

ui_button :: proc(r: k2.Rect, text: string, camera: k2.Camera) -> bool {
    in_rect := k2.point_in_rect(
        k2.screen_to_world(k2.get_mouse_position(), camera),
        r,
    )
    bg_color := k2.DARK_GRAY
    border_color := k2.WHITE
    text_color := k2.WHITE
    res := false

    if in_rect {
        bg_color = k2.GRAY
        text_color = k2.WHITE

        if k2.mouse_button_went_down(.Left) {
            res = true
            bg_color = k2.BLACK
        }
    }

    k2.draw_rect(r, bg_color)
    k2.draw_rect_outline(r, 1 / camera.zoom, border_color)

    text_width := k2.measure_text(text, r.h).x
    k2.draw_text(text, {r.x + r.w / 2 - text_width / 2, r.y}, r.h, k2.WHITE)
    return res
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
    delete(room.targets)
}

@(export)
game_destroy_state :: proc() {
    fmt.println("game.odin::game_destroy_state")
    destroy_room(g.room)
    delete(g.bullets)
    delete(g.all_colliders)
    delete(g.wall_colliders)
    free(g, g.allocator)
}

@(export)
game_shutdown :: proc() {
    fmt.println("game.odin::game_shutdown")
    k2.shutdown()
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

@(export)
game_force_restart :: proc() -> bool {
    // fmt.println("game.odin::game_force_restart")
    return k2.key_went_down(.F6)
}
