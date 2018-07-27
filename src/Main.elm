module Main exposing (..)

import Html as H
import List as L
import String as S
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import WebSocket


type alias Model =
    { username : String
    , players : List Player
    , stage : GameStage
    , games : List String
    , gameId : Maybe String
    , secretColor : String
    , answer : String
    , wsServer : String
    , error : String
    }


type alias Player =
    ( String, Maybe String )


main =
    H.programWithFlags
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


type GameStage
    = Frontdesk
    | Lobby
    | Arena
    | Debrief


type Msg
    = EditUsername String
    | Register
    | Registered String
    | RefreshGames
    | ListReceived (List String)
    | CreateGame
    | JoinGame String
    | LeaveGame
    | NewPlayer String
    | Error String
    | StartGame
    | GameStarted String
    | EditAnswer String
    | AnswerSubmitted String String
    | NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
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
        ( Nothing, ListReceived games ) ->
            ( { model | games = games }, Cmd.none )

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
            , Cmd.none
            )

        ( Just gameId, NewPlayer username ) ->
            ( { model
                | players = L.append model.players [ ( username, Nothing ) ]
              }
            , Cmd.none
            )

        ( _, RefreshGames ) ->
            ( model, WebSocket.send model.wsServer "list" )

        _ ->
            ( model, Cmd.none )


arenaUpdate : Msg -> Model -> ( Model, Cmd Msg )
arenaUpdate msg model =
    case msg of
        EditAnswer answer ->
            ( { model | answer = answer }
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

        date :: author :: "list" :: games ->
            ListReceived (games |> S.join "" |> S.split ",")

        [ date, author, "join", gameId ] ->
            NewPlayer author

        [ date, author, "create", gameId ] ->
            RefreshGames

        [ date, author, "start", secretColor ] ->
            GameStarted secretColor

        [ date, author, "submit", answer ] ->
            AnswerSubmitted author answer

        _ ->
            Error ("Bad message format: " ++ message)


view : Model -> H.Html Msg
view model =
    let
        content =
            case model.stage of
                Frontdesk ->
                    frontdeskView model

                Lobby ->
                    lobbyView model

                Arena ->
                    arenaView model

                Debrief ->
                    debriefView model

        error =
            if not (S.isEmpty model.error) then
                [ H.p [ class "error" ] [ H.text model.error ] ]
            else
                []
    in
    H.div [ class ("cont " ++ stageClass model.stage) ] (L.append content error)


stageClass : GameStage -> String
stageClass stage =
    case stage of
        Frontdesk ->
            "frontdesk"

        Lobby ->
            "lobby"

        Arena ->
            "arena"

        Debrief ->
            "debrief"


frontdeskView : Model -> List (H.Html Msg)
frontdeskView model =
    [ H.h1 [] [ H.text "Guess the Color" ]
    , H.div [ class "login-form round-list" ]
        [ H.input [ onInput EditUsername, value model.username, placeholder "Pick a username" ] []
        , H.button
            (L.append [ onClick Register, class "button" ]
                (if S.isEmpty model.username then
                    [ attribute "disabled" "1" ]
                 else
                    []
                )
            )
            [ H.text "Sign in" ]
        ]
    ]


lobbyView : Model -> List (H.Html Msg)
lobbyView model =
    case model.gameId of
        Nothing ->
            let
                gameItem gid =
                    H.li [] [ H.a [ href "#", onClick (JoinGame gid) ] [ H.text ("Join " ++ gid) ] ]
            in
            [ H.h2 [] [ H.text "Join a game" ]
            , H.p [] [ H.button [ onClick RefreshGames, class "button" ] [ H.text "Refresh list" ] ]
            , H.ul [ class "game-list round-list" ] (L.map gameItem model.games)
            , H.p [] [ H.button [ onClick CreateGame, class "button" ] [ H.text "Or create one" ] ]
            ]

        Just gameId ->
            let
                listItem ( username, answer ) =
                    H.li [] [ H.text (username ++ " is ready") ]

                playerList =
                    H.ul [ class "round-list" ] (L.map listItem (L.filter notMe model.players))

                alone =
                    L.length model.players == 1

                notMe ( username, answer ) =
                    username /= model.username

                placeholder =
                    H.p [] [ H.text "Let's wait for some players to join..." ]
            in
            [ H.h2 [] [ H.text gameId ]
            , if alone then
                placeholder
              else
                playerList
            , H.p [] [ H.button [ onClick StartGame, class "button" ] [ H.text "Go!" ] ]
            ]


arenaView : Model -> List (H.Html Msg)
arenaView model =
    let
        ( me, others ) =
            model.players
                |> L.partition (\( u, a ) -> u == model.username)

        done =
            case me of
                [ ( username, Just answer ) ] ->
                    True

                _ ->
                    False

        disabled =
            if done then
                [ attribute "disabled" "1" ]
            else
                []
    in
    [ H.h2 [ class "b-w"] [ H.text "What color is this?" ]
    , H.ul [ class "round-list"]
          (L.map
              (\( u, _ ) -> H.li [] [ H.text (u ++ " is done!") ])
              (others |> L.filter (\( u, a ) -> a /= Nothing))
          )
    , H.input (L.append disabled [ onInput EditAnswer, value model.answer ]) []
    , overrideBackground model.secretColor
    ]


debriefView : Model -> List (H.Html Msg)
debriefView model =
    [ H.h2 [class "b-w"] [H.text ("The answer was #" ++ model.secretColor)]
    , H.ul [ class "round-list" ] (L.map showAnswer model.players)
    , H.p [] [ H.button [ onClick LeaveGame, class"button" ] [ H.text "Home" ] ]
    , overrideBackground model.secretColor
    ]


overrideBackground hexcode =
    H.node "style" [] [ H.text (":root{--secret: #" ++ hexcode ++ "}") ]


showAnswer ( username, answer ) =
    case answer of
        Just colour ->
            H.li [ style [ ( "background-color", "#" ++ colour ) ] ]
                [ H.span
                  [class "b-w"]
                  [ H.text (username ++ " guessed #" ++ colour) ] ]

        Nothing ->
            H.li [] [ H.text (username ++ " had an issue") ]
