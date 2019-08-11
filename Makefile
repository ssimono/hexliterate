PATH := $(shell pwd)/node_modules/.bin:$(PATH)
ASSETS := $(subst src/,dist/,$(shell find src/assets -type f))

all: dist dist/bundle.js dist/index.html dist/debug.html ${ASSETS}

dist/bundle.js: node_modules src/*.elm
	elm make src/Main.elm --output dist/bundle.js

dist/%.html: src/%.html
	cp $< $@

dist/assets/%: src/assets/% dist/assets
	cp $< $@

dist dist/assets:
	mkdir -p dist/assets

node_modules: package.json
	npm install

db.db: sql/schema.sql
	[ -f db.db ] && mv db.db backup_$(shell date -Iseconds).db || true
	sqlite3 db.db < sql/schema.sql

up: db.db
	websocketd\
	  --staticdir="$(shell pwd)/dist"\
	  --port=8000\
	  "$(shell pwd)/socket.sh"
.PHONY: up

format:
	elm format --yes src/*.elm
.PHONY: format
