# Issues

## Need to fix:
- [x] memory leaks:
```
game.odin::game_destroy_state
game.odin::game_shutdown
[DEBUG] --- [2026-05-03 15:10:54] [audio_backend_alsa.odin:133:alsa_shutdown()] Shutdown audio backend alsa
/home/jorge/Projects/odin/karl2d-example/source/game.odin(177:5): Leaked 512 bytes
```
- [x] pressing q to quit crashes the game, doesnt properly exit
- [ ] bad free of pointer
```
/home/jorge/Projects/odin/karl2d-example/source/game.odin(982:5) Tracking allocator error: Bad free of pointer 383395368
```
- [ ] bullets keep flying past game over/restart
- [ ] live fire game mode does not seem beatable, two enemies in right side of house kill you before you can shoot
