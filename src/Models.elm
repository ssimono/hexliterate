module Models exposing (..)

import Color exposing (Color)


type alias Model =
    { userId : Maybe Int
    , players : List Player
    , stage : GameStage
    , games : List String
    , gameId : Maybe String
    , gameMaster : Int
    , secretColor : Color
    , countdown : Int
    , answer : String
    , wsServer : String
    , error : String
    }


type alias Player =
    { id : Int
    , username : String
    , guess : Maybe (Result String Color)
    }


type GameStage
    = Frontdesk String
    | Lobby
    | Arena
    | Debrief


type Msg
    = EditUsername String
    | Connected
    | Register
    | Registered Player
    | RefreshGames
    | GameReceived String
    | CreateGame
    | JoinGame String
    | LeaveGame
    | NewPlayer Player
    | Error String
    | StartGame
    | GameStarted Color
    | Countdown Int
    | EditAnswer String
    | AnswerSubmitted Int String
    | NoOp


parsePlayer : String -> Result String Player
parsePlayer userdef =
    case String.split ":" userdef of
        [ user_id, username ] ->
            String.toInt user_id |> Result.map (\user_id -> Player user_id username Nothing)

        _ ->
            Result.Err "Cannot parse user"
