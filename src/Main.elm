module Main exposing (..)

import Html exposing (Html, button, div, hr, input, li, p, text, ul)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import WebSocket


type alias Model =
    { username : String
    , players : List String
    , stage : GameStage
    , secretColor : String
    , answer : String
    , answers : List ( String, String )
    , wsServer : String
    , error : String
    }


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
      , secretColor = ""
      , answer = ""
      , answers = []
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
            , WebSocket.send model.wsServer ("register " ++ model.username)
            )

        Registered username ->
            ( { model | username = username, stage = Lobby }
            , WebSocket.send model.wsServer "join"
            )

        _ ->
            ( model, Cmd.none )


lobbyUpdate : Msg -> Model -> ( Model, Cmd Msg )
lobbyUpdate msg model =
    case msg of
        NewPlayer name ->
            ( { model
                | players = List.append model.players [ name ]
              }
            , Cmd.none
            )

        StartGame ->
            ( model
            , WebSocket.send model.wsServer "start-game"
            )

        GameStarted secretColor ->
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

        AnswerSubmitted player answer ->
            let
                legit =
                    List.any (\p -> p == player) model.players
                        && not (List.member player (List.map (\( p, a ) -> p) model.answers))

                done =
                    legit && List.length model.players == List.length model.answers + 1
            in
            ( if legit then
                { model
                    | answers = List.append model.answers [ ( player, answer ) ]
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
            List.filter (\s -> String.length s > 0) (String.split " " message)
    in
    case parts of
        [ date, author, "registered" ] ->
            Registered author

        [ date, author, "join" ] ->
            NewPlayer author

        [ date, author, "start-game", secretColor ] ->
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
    let
        listItem player =
            li [] [ text (player ++ " is ready") ]

        notMe player =
            player /= model.username
    in
    [ p [] [ text ("Signed up as " ++ model.username) ]
    , ul [] (List.map listItem (List.filter notMe model.players))
    , button [ onClick StartGame ] [ text "START" ]
    ]


arenaView : Model -> List (Html Msg)
arenaView model =
    let
        done =
            List.any (\( p, a ) -> p == model.username) model.answers

        disabled =
            if done then
                [ attribute "disabled" "1" ]
            else
                []

        others =
            List.map (\( p, a ) -> p) (List.filter (\( p, a ) -> p /= model.username) model.answers)
    in
    [ p [] [ text "Will you guess?" ]
    , div
        [ style
            [ ( "background-color", "#" ++ model.secretColor )
            , ( "height", "100px" )
            ]
        ]
        [ ul [] (List.map (\p -> li [] [ text (p ++ " is done!") ]) others)
        ]
    , input (List.append disabled [ onInput EditAnswer, value model.answer ]) []
    ]


debriefView : Model -> List (Html Msg)
debriefView model =
    [ div
        [ style
            [ ( "background-color", "#" ++ model.secretColor )
            , ( "height", "100px" )
            ]
        ]
        [ text ("The answer was #" ++ model.secretColor) ]
    , hr [] []
    , ul [] (List.map showAnswer model.answers)
    ]


showAnswer ( player, answer ) =
    li [ style [ ( "background-color", "#" ++ answer ) ] ]
        [ text (player ++ " guessed #" ++ answer) ]
