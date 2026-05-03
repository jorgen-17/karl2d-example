# shoot_house
game where the player clears structures of enemies with his rifle

## design:
top down 2d shooter

## rules:
1. 1 point per shot on target.
2. -1 for each miss.
3. clock goes until last target is neutralized.
4. score gets divided by elapsed time so that quicker times grant higher scores.
5. player and enemies die after getting hit 4 times.

## levels:
1. shoot house with paper targets. two shots to neutralize each target.
2. real house with enemies that shoot back.

## features:
- [x] player movement
- [x] gun faces where player faces.
- [x] bullets leave barrel of gun and despawn after 600 frames
- [x] house walls
- [x] targets, make them turn black when dead
- [x] player collisions: cant walk through walls or live targets/enemies
- [x] bullet collisions: bullets cant go through walls and take away health from targets/enemies
- [x] aim gun with mouse pointer, character also faces where the mouse is
- [x] keep track of score (hits and misses) and display on top bar
- [x] add timer that stops once all targets are neutralized and display on top bar
- [x] shows targets remaining on top bar
- [x] menu to pause and restart level
- [x] add gameover menu for when you finish the level that lets you restart
- [x] add instructions on how to play the game
- [ ] add textures to player and targets
- [ ] add room textures
- [ ] animate player
- [ ] top 10 scores tracking
- [ ] write scores to file
- [ ] shoot vs no-shoot targets (to train not shooting civillians)
- [ ] level editor
- [ ] several shoot house levels
- [ ] enemies are stationary but shoot after delay if their gun intersects with player gun
- [ ] enemies track player once they see him
- [ ] civillian npcs that you cant shoot
- [ ] several real houses levels
- [ ] limited ammo capacity, invetory with magazines, each mag keeps track of how many bullets it has
- [ ] can pick up bullets from caches
- [ ] can pick up health kits to recover damage from 1 bullet
- [ ] enemies drop weapons
    - [ ] player can switch to them
    - [ ] can pick up mags from dead enemies inventory
    - [ ] ammo and mags are specific to each firearm like real life
- [ ] draw cursor
- [ ] switch shoulders
- [ ] room is dark unless you have seen inside it with visual cone
- [ ] lighting
    - [ ] flashlights
    - [ ] point lights in room
