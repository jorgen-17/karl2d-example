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
- [ ] bullets leave barrel of gun and disapears when offscreen
- [ ] house walls
- [ ] targets
- [ ] bullet collisions: register hits and misses, update score
- [ ] aim gun with mouse pointer
- [ ] add timer that stops once all targets are neutralized
- [ ] menu to pause and restart level
- [ ] add textures to player and targets
- [ ] add room textures
- [ ] animate player
- [ ] top 10 scores tracking
- [ ] write scores to file
- [ ] level editor
- [ ] several shoot house levels
- [ ] enemies are stationary but shoot in a line when player intersects it
- [ ] enemies track player once they see him
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
