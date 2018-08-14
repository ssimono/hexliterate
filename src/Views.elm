module Views exposing (view)

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

        currentAnswer =
            "#" ++ model.answer ++ S.repeat (6 - S.length model.answer) "_"
    in
    [ H.h2 [ class "b-w" ] [ H.text "What color is this?" ]
    , H.h3 [ class "b-w" ] [ H.text currentAnswer ]
    , H.p []
        [ H.input
            (L.append disabled
                [ onInput EditAnswer
                , value model.answer
                , id "color-input"
                ]
            )
            []
        , if done then
            H.p [ class "b-w" ] [ H.text "Good job! Let's wait for the others" ]
          else if model.countdown <= 5 then
            H.p [ class "b-w" ] [ H.text ("Game ends in " ++ toString model.countdown) ]
          else
            H.text ""
        ]
    , H.ul [ class "b-w news" ]
        (L.map
            (\( u, _ ) -> H.li [] [ H.text (u ++ " is done!") ])
            (others |> L.filter (\( u, a ) -> a /= Nothing))
        )
    , overrideBackground (Cu.col2hex model.secretColor)
    ]


debriefView : Model -> List (H.Html Msg)
debriefView model =
    let
        secretHex =
            Cu.col2hex model.secretColor

        parsePlayer ( username, answer ) ( valid, invalid ) =
            case answer of
                Just (Ok color) ->
                    ( ( username, color ) :: valid
                    , invalid
                    )

                Just (Err problem) ->
                    ( valid
                    , (username ++ " had a problem") :: invalid
                    )

                Nothing ->
                    ( valid
                    , (username ++ " had no idea") :: invalid
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
