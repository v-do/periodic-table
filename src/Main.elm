import Browser
import Css exposing (..)
import Debug
import Dict
import Html.Styled exposing (..)
import Html.Styled.Attributes exposing (css)
import Http
import Json.Decode as Decode exposing (Decoder, field, float, int, list, nullable, string)
import Json.Decode.Pipeline exposing (required, optional, hardcoded)
import Round

main =
  Browser.element
    { init = init
    , update = update
    , subscriptions = subscriptions
    , view = view >> toUnstyled
    }

-- MODEL

type Model
  = Failure Http.Error
  | Loading
  | Success PeriodicTable

type alias PeriodicTable = List Period

type alias Period = List (Maybe ChemicalElement)

type alias ChemicalElement = 
  { name : String
  , appearance : Maybe String
  , atomicMass : Float
  , boilingPoint : Maybe Float
  , category : String
  , color : Maybe String
  , density : Maybe Float
  , discoveredBy : Maybe String
  , meltingPoint : Maybe Float
  , molarHeat : Maybe Float
  , namedBy : Maybe String
  , number : Int
  , period : Int
  , phase : String
  , source : String
  , spectralImage : Maybe String
  , summary : String
  , symbol : String
  , xpos : Int
  , ypos : Int
  , shells : List Int
  , electronConfiguration : String
  , electronAffinity : Maybe Float
  , electronegativityPauling: Maybe Float
  , ionizationEnergies: List Float
  }

init : () -> (Model, Cmd Msg)
init _ =
  (Loading, loadPeriodicTable)

-- UPDATE

type Msg = Loaded (Result Http.Error (List ChemicalElement))

update msg model =
  case msg of
    Loaded (Err error) ->
      (Failure error, Cmd.none)

    Loaded (Ok elements) ->
      let
        periodicTableDict =
          List.foldl
            (\element dict -> Dict.insert (element.ypos, element.xpos) element dict)
            Dict.empty
            elements

        periodicTable =
          List.map
            (\row ->
              List.map
                (\col -> Dict.get (row, col) periodicTableDict)
                (List.range 1 18)
            )
            (List.range 1 10)
      in
        (Success periodicTable, Cmd.none)

-- SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.none

-- VIEW

view model =
  div
    [ css [ fontFamilies ["Arial"] ] ]
    [ h2 
        [ css [ textAlign center ] ]
        [ text "Periodic Table" ]
    , case model of
        Failure error ->
          div [] [ text (Debug.toString error)]
    
        Loading ->
          text "Loading..."
    
        Success periodicTable ->
          viewPeriodicTable periodicTable
    ]

viewPeriodicTable : PeriodicTable -> Html Msg
viewPeriodicTable periodicTable =
  Html.Styled.table
    [ css
        [ fontSize (px 11)
        , borderCollapse collapse
        , margin auto
        ]
    ]
    (List.map viewPeriod periodicTable)

viewPeriod : Period -> Html Msg
viewPeriod period =
  tr
    []
    (List.map viewElement period)

viewElement : Maybe ChemicalElement -> Html Msg
viewElement element =
  case element of
      Nothing ->
        td
          [ css
              [ border2 (px 0) solid
              , width (px 56)
              , height (px 56)
              , padding (px 0)
              ]
          ]
          []
      
      Just e ->
        td
          [ css
              [ border2 (px 1) solid
              , width (px 56)
              , height (px 56)
              , padding (px 0)
              ]
          ]
          [ p
              [ css [ margin (px 1) ] ]
              [ text (String.fromInt e.number) ]
          , p
              [ css
                  [ margin2 (px -4) (px 0)
                  , fontWeight bold
                  , fontSize (px 20)
                  , textAlign center
                  ]
              ]
              [ text e.symbol ]
          , p
              [ css
                  (
                    [ margin (px 0)
                    , textAlign center
                    ]
                    ++
                    ( if String.length e.name > 9 then
                      [ letterSpacing (px -1) ]
                    else
                      []
                    )
                  )
              ]
              [ text e.name ]
          , p
              [ css
                  [ margin (px 0)
                  , textAlign center
                  ]
              ]
              [ text (Round.round 3 e.atomicMass) ]
          ]

-- HTTP

loadPeriodicTable : Cmd Msg
loadPeriodicTable =
  Http.get
    -- https://github.com/Bowserinator/Periodic-Table-JSON
    { url = "/data/Periodic-Table-JSON/PeriodicTableJSON.json"
    , expect = Http.expectJson Loaded periodicTableDecoder
    }

-- JSON

periodicTableDecoder : Decoder (List ChemicalElement)
periodicTableDecoder =
  field "elements" (list elementDecoder)

elementDecoder : Decoder ChemicalElement
elementDecoder =
  Decode.succeed ChemicalElement
    |> required "name" string
    |> required "appearance" (nullable string)
    |> required "atomic_mass" float
    |> required "boil" (nullable float)
    |> required "category" string
    |> required "color" (nullable string)
    |> required "density" (nullable float)
    |> required "discovered_by" (nullable string)
    |> required "melt" (nullable float)
    |> required "molar_heat" (nullable float)
    |> required "named_by" (nullable string)
    |> required "number" int
    |> required "period" int
    |> required "phase" string
    |> required "source" string
    |> required "spectral_img" (nullable string)
    |> required "summary" string
    |> required "symbol" string
    |> required "xpos" int
    |> required "ypos" int
    |> required "shells" (list int)
    |> required "electron_configuration" string
    |> required "electron_affinity" (nullable float)
    |> required "electronegativity_pauling" (nullable float)
    |> required "ionization_energies" (list float)
