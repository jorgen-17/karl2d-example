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
