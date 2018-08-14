module ColorUtils exposing (accuracy, col2hex)

import Color exposing (Color)
import List as L
import Models exposing (Player)
import String as S


col2hex : Color -> String
col2hex color =
    let
        rgb =
            Color.toRgb color
    in
    [ rgb.red, rgb.green, rgb.blue ] |> L.map (int2hex >> S.padLeft 2 '0') |> S.join ""


accuracy : Color -> Color -> Float
accuracy mainColor playerColor =
    1.0 / colorDistance mainColor playerColor


int2hex : Int -> String
int2hex value =
    if value < 10 then
        toString value
    else if value < 16 then
        case value of
            10 ->
                "a"

            11 ->
                "b"

            12 ->
                "c"

            13 ->
                "d"

            14 ->
                "e"

            15 ->
                "f"

            _ ->
                "?"
    else
        int2hex (value // 16) ++ int2hex (value % 16)


colorDistance : Color -> Color -> Float
colorDistance c1 c2 =
    let
        diff color1 color2 prop =
            abs (prop color1 - prop color2)

        vector =
            L.map (diff (Color.toRgb c1) (Color.toRgb c2)) [ .red, .green, .blue ]

        -- Weight each channel to make it closer to human perception
        -- https://en.wikipedia.org/wiki/Color_difference
        weightedVector =
            L.map2 (*) vector [ 2, 4, 3 ]
    in
    vector |> L.map (\n -> n ^ 2) |> L.foldr (+) 0 |> toFloat |> sqrt
