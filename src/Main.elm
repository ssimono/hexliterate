module Main exposing (..)

import Dom exposing (focus)
import Html
import List as L
import Models exposing (..)
import Regex exposing (contains, regex)
import String as S
import Task exposing (attempt)
import Views exposing (view)
import WebSocket


main =
    Html.programWithFlags
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


init ws_server =
    ( { username = ""
      , players = []
      , stage = Frontdesk
      , gameId = Nothing
      , games = []
      , secretColor = ""
      , answer = ""
      , wsServer = ws_server
      , error = ""
      }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg previousModel =
    let
        model =
            { previousModel | error = "" }
    in
    case msg of
        Error message ->
            ( { model | error = message }, Cmd.none )

        NoOp ->
            ( model, Cmd.none )

        LeaveGame ->
            let
                ( initial, _ ) =
                    init model.wsServer
            in
            ( { initial
                | username = model.username
                , stage = Lobby
              }
            , WebSocket.send model.wsServer "list"
            )

        _ ->
            case model.stage of
                Frontdesk ->
                    frontdeskUpdate msg model

                Lobby ->
                    lobbyUpdate msg model

                Arena ->
                    arenaUpdate msg model

                Debrief ->
                    debriefUpdate msg model


frontdeskUpdate : Msg -> Model -> ( Model, Cmd Msg )
frontdeskUpdate msg model =
    case msg of
        EditUsername username ->
            ( { model | username = username }, Cmd.none )

        Register ->
            ( model
            , "register " ++ model.username |> WebSocket.send model.wsServer
            )

        Registered username ->
            ( { model | username = username, stage = Lobby }
            , WebSocket.send model.wsServer "list"
            )

        _ ->
            ( model, Cmd.none )


lobbyUpdate : Msg -> Model -> ( Model, Cmd Msg )
lobbyUpdate msg model =
    case ( model.gameId, msg ) of
        ( Nothing, GameReceived game ) ->
            ( { model | games = game :: model.games }, Cmd.none )

        ( Nothing, CreateGame ) ->
            ( model
            , WebSocket.send model.wsServer "create"
            )

        ( Nothing, JoinGame gameId ) ->
            ( { model | gameId = Just gameId }
            , WebSocket.send model.wsServer ("join " ++ gameId)
            )

        ( Just gameId, StartGame ) ->
            ( model
            , WebSocket.send model.wsServer "start"
            )

        ( Just gameId, GameStarted secretColor ) ->
            ( { model | stage = Arena, secretColor = secretColor }
            , Dom.focus "color-input" |> Task.attempt (\_ -> NoOp)
            )

        ( Just gameId, NewPlayer username ) ->
            ( { model
                | players = L.append model.players [ ( username, Nothing ) ]
              }
            , Cmd.none
            )

        ( _, RefreshGames ) ->
            ( { model | games = [] }, WebSocket.send model.wsServer "list" )

        _ ->
            ( model, Cmd.none )


arenaUpdate : Msg -> Model -> ( Model, Cmd Msg )
arenaUpdate msg model =
    case msg of
        EditAnswer answer ->
            ( { model
                | answer =
                    if Regex.contains (regex "^[a-fA-F0-9]{0,6}$") answer then
                        answer
                    else
                        model.answer
              }
            , if S.length answer == 6 then
                WebSocket.send model.wsServer ("submit " ++ answer)
              else
                Cmd.none
            )

        AnswerSubmitted username answer ->
            let
                player =
                    model.players
                        |> L.filter (\( u, a ) -> u == username)
                        |> L.head

                legit =
                    case player of
                        Nothing ->
                            False

                        Just ( name, Just answer ) ->
                            False

                        Just ( name, Nothing ) ->
                            True

                done =
                    legit
                        && (model.players
                                |> L.filter (\( u, a ) -> u /= username)
                                |> L.all (\( u, a ) -> a /= Nothing)
                           )
            in
            ( if legit then
                { model
                    | players =
                        model.players
                            |> L.map
                                (\( u, a ) ->
                                    if u == username then
                                        ( u, Just answer )
                                    else
                                        ( u, a )
                                )
                    , stage =
                        if done then
                            Debrief
                        else
                            Arena
                }
              else
                model
            , Cmd.none
            )

        _ ->
            ( model, Cmd.none )


debriefUpdate : Msg -> Model -> ( Model, Cmd Msg )
debriefUpdate msg model =
    ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    WebSocket.listen model.wsServer handleSocket


handleSocket message =
    let
        parts =
            S.split " " message |> L.filter (\s -> not (S.isEmpty s))
    in
    case parts of
        [ date, author, "registered" ] ->
            Registered author

        [ date, author, "gameitem", gameId ] ->
            GameReceived gameId

        [ date, author, "join", gameId ] ->
            NewPlayer author

        [ date, author, "create", gameId ] ->
            RefreshGames

        [ date, author, "start", secretColor ] ->
            GameStarted secretColor

        [ date, author, "submit", answer ] ->
            AnswerSubmitted author answer

        date :: author :: "bad-message" :: details ->
            Error ("Bad message: " ++ S.join " " details)

        _ ->
            Error ("Bad message format: " ++ message)
