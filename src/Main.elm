import Html exposing (Html, button, div, text, input, hr, ul, li)
import Html.Events exposing (onClick, onInput)
import Html.Attributes exposing (..)

init = { players = []
       , editedPlayer = ""
       , state = Lobby
       }

main =
  Html.beginnerProgram { model = init, view = view, update = update }

type GameState
  = Lobby
  | Arena

type Msg
  = EditPlayer String
  | NewPlayer
  | StartGame

update msg model =
  case msg of
    EditPlayer name ->
      { model | editedPlayer = name }

    NewPlayer ->
      { model
      | players = List.append model.players [model.editedPlayer]
      , editedPlayer = ""
      }

    StartGame ->
      { model | state = Arena }

lobbyView model =
  div []
    [ input [ onInput EditPlayer, value model.editedPlayer ] []
    , button [ onClick NewPlayer ] [ text "Sign up" ]
    , div [] [ text (String.join ", " model.players) ]
    , hr [] []
    , button [ onClick StartGame ] [ text "Start game" ]
    ]

arenaView model =
  div []
    [ ul [] (List.map (\player -> li [] [ text player, input [] [] ]) model.players) ]

view model =
  case model.state of
    Lobby -> lobbyView model
    Arena-> arenaView model
