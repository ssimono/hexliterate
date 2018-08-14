PATH := $(shell pwd)/node_modules/.bin:$(PATH)
ASSETS := $(subst src/,dist/,$(shell find src/assets -type f))

all: dist dist/bundle.js dist/index.html dist/debug.html ${ASSETS} node_modules

dist/bundle.js: src/*.elm
	elm make src/Main.elm --output dist/bundle.js

dist/%.html: src/%.html
	cp $< $@

dist/assets/%: src/assets/% dist/assets
	cp $< $@

dist dist/assets:
	mkdir -p dist/assets

node_modules: package.json
	npm install

up:
	GAME_FOLDER="$(shell pwd)/games" websocketd\
	  --passenv GAME_FOLDER\
	  --staticdir="$(shell pwd)/dist"\
	  --port=8000\
	  "$(shell pwd)/socket.sh"
.PHONY: up

format:
	elm format --yes src/*.elm
.PHONY: format
