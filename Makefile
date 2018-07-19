PATH := $(shell pwd)/node_modules/.bin:$(PATH)

all: dist dist/bundle.js dist/index.html

dist/bundle.js: src/*.elm
	elm make src/Main.elm --output dist/bundle.js

dist/index.html: src/index.html
	cp src/index.html dist/index.html

dist:
	mkdir dist
