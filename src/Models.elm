module Models exposing (..)

import Color exposing (Color)


type alias Model =
    { username : String
    , players : List Player
    , stage : GameStage
    , games : List String
    , gameId : Maybe String
    , secretColor : Color
    , countdown : Int
    , answer : String
    , wsServer : String
    , error : String
    }


type alias Guess =
    Maybe (Result String Color)


type alias Player =
    ( String, Guess )


type GameStage
    = Frontdesk
    | Lobby
    | Arena
    | Debrief


type Msg
    = EditUsername String
    | Connected
    | Register
    | Registered String
    | RefreshGames
    | GameReceived String
    | CreateGame
    | JoinGame String
    | LeaveGame
    | NewPlayer String
    | Error String
    | StartGame
    | GameStarted Color
    | Countdown Int
    | EditAnswer String
    | AnswerSubmitted String String
    | NoOp
