module Data.Priority exposing
    ( Priority(..)
    , all
    , fromString
    , toName
    )


type Priority
    = High
    | Low


fromString : String -> Maybe Priority
fromString str =
    let
        s =
            String.toLower str
    in
    case s of
        "low" ->
            Just Low

        "high" ->
            Just High

        _ ->
            Nothing


toName : Priority -> String
toName lang =
    case lang of
        Low ->
            "Low"

        High ->
            "High"


all : List Priority
all =
    [ Low, High ]
