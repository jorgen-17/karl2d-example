pull down karl2s submodule:
```bash
git submodule update --init --recursive
```

hot reload:
```bash
./build_hot_reload.sh
./game_hot_reload.bin
# make a change to the code and then build again:
./build_hot_reload.sh
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
