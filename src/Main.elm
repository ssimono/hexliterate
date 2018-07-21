module Main exposing (..)

import Html exposing (Html, button, div, hr, input, li, p, text, ul)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import WebSocket


type alias Model =
    { username : String
    , players : List String
    , stage : GameStage
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
      , wsServer = ws_server
      , error = ""
      }
    , Cmd.none
    )


type GameStage
    = Frontdesk
    | Lobby
    | Arena


type Msg
    = EditUsername String
    | Register
    | Registered String
    | NewPlayer String
    | Error String
    | StartGame
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
            ( { model | stage = Arena }, Cmd.none )

        _ ->
            ( model, Cmd.none )


arenaUpdate : Msg -> Model -> ( Model, Cmd Msg )
arenaUpdate msg model =
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
    ]


arenaView : Model -> List (Html Msg)
arenaView model =
    [ ul [] (List.map (\player -> li [] [ text player, input [] [] ]) model.players) ]
