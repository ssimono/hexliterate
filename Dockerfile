FROM golang:1.10 AS golang

RUN go get github.com/joewalnes/websocketd

FROM node:6.14 AS node

RUN mkdir /app
WORKDIR /app
ADD ["package.json", "elm-package.json", "./"]
RUN npm install
RUN ./node_modules/.bin/elm-package install --yes
ADD [".", "./"]
RUN make

FROM debian:jessie-slim AS runner

ENV WSD_STATICDIR=/var/www
ENV WSD_PORT=8000
ENV WSD_PASSENV=GAME_FOLDER,TIMEOUT
ENV GAME_FOLDER=/var/data/

COPY --from=golang ["/go/bin/websocketd", "/usr/bin/"]
ADD ["./socket.sh", "./parsenv.sh", "./counter.sh", "/usr/bin/"]
COPY --from=node ["/app/dist", "/var/www"]

VOLUME ["/var/data/"]
EXPOSE 8000

CMD websocketd `parsenv.sh` socket.sh
