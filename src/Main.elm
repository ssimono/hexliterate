module Main exposing (..)

import Html exposing (Html, button, div, h2, h3, hr, input, li, p, text, ul)
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
        ( Nothing, RefreshGames ) ->
            ( model, WebSocket.send model.wsServer "list" )

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

        ( Just gameId, NewPlayer username ) ->
            ( { model
                | players = List.append model.players [ ( username, Nothing ) ]
              }
            , Cmd.none
            )

        ( Just gameId, StartGame ) ->
            ( model
            , WebSocket.send model.wsServer "start"
            )

        ( Just gameId, GameStarted secretColor ) ->
            ( { model | stage = Arena, secretColor = secretColor }
            , Cmd.none
            )

        _ ->
            ( model, Cmd.none )


arenaUpdate : Msg -> Model -> ( Model, Cmd Msg )
arenaUpdate msg model =
    case msg of
        EditAnswer answer ->
            ( { model | answer = answer }
            , if String.length answer == 6 then
                WebSocket.send model.wsServer ("submit " ++ answer)
              else
                Cmd.none
            )

        AnswerSubmitted username answer ->
            let
                player =
                    model.players
                        |> List.filter (\( u, a ) -> u == username)
                        |> List.head

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
                                |> List.filter (\( u, a ) -> u /= username)
                                |> List.all (\( u, a ) -> a /= Nothing)
                           )
            in
            ( if legit then
                { model
                    | players =
                        model.players
                            |> List.map
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
            String.split " " message |> List.filter (\s -> not (String.isEmpty s))
    in
    case parts of
        [ date, author, "registered" ] ->
            Registered author

        date :: author :: "list" :: games ->
            ListReceived (games |> String.join "" |> String.split ",")

        [ date, author, "join", gameId ] ->
            NewPlayer author

        [ date, author, "create", gameId ] ->
            JoinGame gameId

        [ date, author, "start", secretColor ] ->
            GameStarted secretColor

        [ date, author, "submit", answer ] ->
            AnswerSubmitted author answer

        _ ->
            Error ("Bad message format: " ++ message)


view : Model -> Html Msg
view model =
    let
        content =
            case model.stage of
                Frontdesk ->
                    frontedeskView model

                Lobby ->
                    lobbyView model

                Arena ->
                    arenaView model

                Debrief ->
                    debriefView model

        error =
            if not (String.isEmpty model.error) then
                [ p [ class "error" ] [ text model.error ] ]
            else
                []
    in
    div [] (List.append content error)


frontedeskView : Model -> List (Html Msg)
frontedeskView model =
    [ input [ onInput EditUsername, value model.username, placeholder "Pick a username" ] []
    , button
        (List.append [ onClick Register ]
            (if String.isEmpty model.username then
                [ attribute "disabled" "1" ]
             else
                []
            )
        )
        [ text "Sign up" ]
    ]


lobbyView : Model -> List (Html Msg)
lobbyView model =
    case model.gameId of
        Nothing ->
            let
                gameItem gid =
                    li [] [ Html.a [ href "#", onClick (JoinGame gid) ] [ text ("Join " ++ gid) ] ]
            in
            [ h2 [] [ text "Join a game" ]
            , p [] [ button [ onClick RefreshGames ] [ text "Refresh list" ] ]
            , ul [] (List.map gameItem model.games)
            , p [] [ button [ onClick CreateGame ] [ text "Or create one" ] ]
            ]

        Just gameId ->
            let
                listItem ( username, answer ) =
                    li [] [ text (username ++ " is ready") ]

                notMe ( username, answer ) =
                    username /= model.username
            in
            [ h3 [] [ text gameId ]
            , p [] [ text ("Signed up as " ++ model.username) ]
            , ul [] (List.map listItem (List.filter notMe model.players))
            , button [ onClick StartGame ] [ text "Go!" ]
            ]


arenaView : Model -> List (Html Msg)
arenaView model =
    let
        ( me, others ) =
            model.players
                |> List.partition (\( u, a ) -> u == model.username)

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
    [ p [] [ text "Will you guess?" ]
    , div
        [ style
            [ ( "background-color", "#" ++ model.secretColor )
            , ( "height", "100px" )
            ]
        ]
        [ ul []
            (List.map
                (\( u, _ ) -> li [] [ text (u ++ " is done!") ])
                (others |> List.filter (\( u, a ) -> a /= Nothing))
            )
        ]
    , input (List.append disabled [ onInput EditAnswer, value model.answer ]) []
    ]


debriefView : Model -> List (Html Msg)
debriefView model =
    [ div
        [ style
            [ ( "background-color", "#" ++ model.secretColor )
            , ( "margin", "10px" )
            ]
        ]
        [ text ("The answer was #" ++ model.secretColor)
        , hr [] []
        , ul [] (List.map showAnswer model.players)
        , button [ onClick LeaveGame ] [ text "Home" ]
        ]
    ]


showAnswer ( username, answer ) =
    case answer of
        Just colour ->
            li [ style [ ( "background-color", "#" ++ colour ) ] ]
                [ text (username ++ " guessed #" ++ colour) ]

        Nothing ->
            li [] [ text (username ++ " had an issue") ]
