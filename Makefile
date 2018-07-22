PATH := $(shell pwd)/node_modules/.bin:$(PATH)

all: dist dist/bundle.js dist/index.html dist/debug.html node_modules

dist/bundle.js: src/*.elm
	elm make src/Main.elm --output dist/bundle.js

dist/%.html: src/%.html
	cp $< $@

dist:
	mkdir dist

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
	elm format src/*.elm
.PHONY: format
