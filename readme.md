dependencies:
```bash
# pull down karl2d submodule
git submodule update --init --recursive
# optional install fswatch if you want file watching
sudo apt get fswatch
# or maybe `brew install fswatch` on macos
```


hot reload:
```bash
./build_hot_reload.sh
./game_hot_reload.bin
# make a change to the code and then build again:
./build_hot_reload.sh
# or watch source files for changes and automatically compiles them:
./watch_hot_reload.sh
```

run on desktop:
```bash
odin run .
```

web build:
```bash
odin run ./libs/karl2d/build_web/ -- .
```

to run web build:
```bash
# build_web builds into ./bin/web/
cd ./bin/web/
# run simple webserver to serve the files
python3 -m http.server
# launch web browser on localhost:8000
firefox localhost:8000
```
