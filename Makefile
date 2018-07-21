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
