module Views exposing (view)

import Color exposing (Color)
import ColorUtils as Cu
import Html as H
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Html.Keyed as HKeyed
import List as L
import Models exposing (..)
import String as S


view : Model -> H.Html Msg
view model =
    let
        content =
            case model.stage of
                Frontdesk username ->
                    frontdeskView username model

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
        Frontdesk _ ->
            "frontdesk"

        Lobby ->
            "lobby"

        Arena ->
            "arena"

        Debrief ->
            "debrief"


frontdeskView : String -> Model -> List (H.Html Msg)
frontdeskView username model =
    [ H.h1 [] [ H.text "Guess the Color" ]
    , H.div [ class "login-form round-list" ]
        [ H.input [ onInput EditUsername, value username, placeholder "Pick a username" ] []
        , H.button
            (L.append [ onClick Register, class "button" ]
                (if S.isEmpty username then
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
                    ( gid
                    , H.li [ onClick (JoinGame gid) ] [ H.text ("Join " ++ gid) ]
                    )
            in
            [ H.h2 [] [ H.text "Join a game" ]
            , H.p [] [ H.button [ onClick RefreshGames, class "button" ] [ H.text "Refresh list" ] ]
            , HKeyed.ul [ class "game-list round-list" ] (L.map gameItem model.games)
            , H.p [] [ H.button [ onClick CreateGame, class "button" ] [ H.text "Or create one" ] ]
            ]

        Just gameId ->
            let
                listItem player =
                    H.li [] [ H.text (player.username ++ " is ready") ]

                playerList =
                    H.ul [ class "round-list" ] (L.map listItem (L.filter notMe model.players))

                alone =
                    L.length model.players == 1

                notMe player =
                    Just player.id /= model.userId

                placeholder =
                    H.p [] [ H.text "Let's wait for some players to join..." ]

                gameMaster =
                    model.players
                        |> L.filter (\p -> p.id == model.gameMaster)
                        |> L.head
                        |> Maybe.withDefault (Player 0 "???" Nothing)
            in
            [ H.h2 [] [ H.text gameId ]
            , if alone then
                placeholder
              else
                playerList
            , if Just gameMaster.id == model.userId then
                H.p [] [ H.button [ onClick StartGame, class "button" ] [ H.text "Go!" ] ]
              else
                H.p [] [ H.text ("Waiting for " ++ gameMaster.username ++ " to start the game...") ]
            ]


arenaView : Model -> List (H.Html Msg)
arenaView model =
    let
        ( me, others ) =
            model.players
                |> L.partition (\p -> Just p.id == model.userId)

        done =
            case List.map .guess me |> List.head of
                Just (Just (Ok answer)) ->
                    True

                _ ->
                    False

        spectator =
            L.length me == 0

        disabled =
            if done then
                [ attribute "disabled" "1" ]
            else
                []

        currentAnswer =
            "#" ++ model.answer ++ S.repeat (6 - S.length model.answer) "_"

        colorInput =
            H.input
                (L.append disabled
                    [ onInput EditAnswer
                    , value model.answer
                    , id "color-input"
                    ]
                )
                []
    in
    [ H.h2 [ class "b-w" ] [ H.text "What color is this?" ]
    , H.h3 [ class "b-w" ] [ H.text currentAnswer ]
    , H.p []
        [ cond (not spectator) colorInput
        , if spectator then
            H.p [ class "b-w" ] [ H.text "Game has already started, you're watching as a spectator" ]
          else if done then
            H.p [ class "b-w" ] [ H.text "Good job! Let's wait for the others" ]
          else if model.countdown <= 5 then
            H.p [ class "b-w" ] [ H.text ("Game ends in " ++ toString model.countdown) ]
          else
            H.text ""
        ]
    , H.ul [ class "b-w news" ]
        (L.map
            (\p -> H.li [] [ H.text (p.username ++ " is done!") ])
            (others |> L.filter (\p -> p.guess /= Nothing))
        )
    , overrideBackground (Cu.col2hex model.secretColor)
    ]


debriefView : Model -> List (H.Html Msg)
debriefView model =
    let
        secretHex =
            Cu.col2hex model.secretColor

        parsePlayer : Player -> ( List ( String, Color ), List String ) -> ( List ( String, Color ), List String )
        parsePlayer player ( valid, invalid ) =
            case player.guess of
                Just (Ok color) ->
                    ( ( player.username, color ) :: valid
                    , invalid
                    )

                Just (Err problem) ->
                    ( valid
                    , (player.username ++ " had a problem") :: invalid
                    )

                Nothing ->
                    ( valid
                    , (player.username ++ " had no idea") :: invalid
                    )

        ( validPlayers, invalidPlayers ) =
            List.foldr parsePlayer ( [], [] ) model.players

        sortedPlayers =
            L.sortBy (\( u, c ) -> -1 * Cu.accuracy model.secretColor c) validPlayers

        validItem rank ( username, color ) =
            H.li [ style [ ( "background-color", "#" ++ Cu.col2hex color ) ], class "b-w" ]
                [ H.span
                    []
                    [ H.text ((rank + 1 |> toString) ++ ". " ++ username ++ " guessed #" ++ Cu.col2hex color) ]
                ]

        invalidItem reason =
            H.li [ class "b-w" ] [ H.text reason ]
    in
    [ H.h2 [ class "b-w" ] [ H.text ("The answer was #" ++ secretHex) ]
    , H.ol [ class "round-list" ] (L.indexedMap validItem sortedPlayers)
    , H.ul [ class "b-w" ] (L.map invalidItem invalidPlayers)
    , H.p [] [ H.button [ onClick LeaveGame, class "button" ] [ H.text "Home" ] ]
    , overrideBackground secretHex
    ]


overrideBackground hexcode =
    H.node "style" [] [ H.text (":root{--secret: #" ++ hexcode ++ "}") ]


cond : Bool -> H.Html Msg -> H.Html Msg
cond predicate node =
    if predicate then
        node
    else
        H.text ""
