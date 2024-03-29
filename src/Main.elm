import Browser
import Css exposing (..)
import Debug
import Dict
import Html.Styled exposing (..)
import Html.Styled.Events exposing (onMouseEnter, onMouseLeave)
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
  | Success Data

type alias Data =
  { periodicTable : PeriodicTable
  , highlight : HighlightTarget
  }

type HighlightTarget
  = NoHighlight
  | Element ElementPosition
  | Group Int
  | Period Int
  | Lanthanides
  | Actinides

type alias ElementPosition =
  (Int, Int)

type alias PeriodicTable =
  Dict.Dict ElementPosition ChemicalElement

type alias Period =
  List (Maybe ChemicalElement)

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

type Msg
  = Loaded (Result Http.Error (List ChemicalElement))
  | Highlight HighlightTarget

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Loaded (Err error) ->
      (Failure error, Cmd.none)

    Loaded (Ok elements) ->
      let
        periodicTable =
          List.foldl
            (\element dict -> Dict.insert (element.ypos, element.xpos) element dict)
            Dict.empty
            elements
      in
      (Success (Data periodicTable NoHighlight), Cmd.none)
    
    Highlight highlight ->
      case model of
        Success data ->
          (Success { data | highlight = highlight }, Cmd.none)

        _ ->
          (model, Cmd.none)

-- SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.none

-- VIEW

categoryColors : Dict.Dict String Color
categoryColors =
  Dict.fromList
    [ ("actinide", (rgb 242 196 206))
    , ("alkali metal", (rgb 255 175 175))
    , ("alkaline earth metal", (rgb 252 200 143))
    , ("diatomic nonmetal", (rgb 126 233 220))
    , ("lanthanide", (rgb 251 199 237))
    , ("metalloid", (rgb 241 246 149))
    , ("noble gas", (rgb 168 224 255))
    , ("polyatomic nonmetal", (rgb 162 241 178))
    , ("post-transition metal", (rgb 200 201 250))
    , ("transition metal", (rgb 221 251 177))
    ]

getCategoryColor : String -> Color
getCategoryColor category =
  Maybe.withDefault (rgb 233 233 233) (Dict.get category categoryColors)

phaseColors : Dict.Dict String Color
phaseColors =
  Dict.fromList
    [ ("Gas", (rgb 242 141 34))
    , ("Liquid", (rgb 76 129 230))
    , ("Solid", (rgb 0 0 0))
    ]

getPhaseColor : String -> Color
getPhaseColor phase =
  Maybe.withDefault (rgb 130 130 130) (Dict.get phase phaseColors)

view : Model -> Html Msg
view model =
  case model of
    Failure error ->
      text (Debug.toString error)

    Loading ->
      text "Loading..."
    
    Success data ->
      viewPeriodicTable data

viewPeriodicTable : Data -> Html Msg
viewPeriodicTable data =
  div
    [ css
        [ fontFamilies ["Arial"]
        , position relative
        , margin auto
        , width (px 1121)
        ]
    ]
    [ Html.Styled.table
        [ css
            [ fontSize (px 11)
            , tableLayout fixed
            , borderCollapse collapse
            ]
        ]
        (
          viewGroups data
          ::
          List.map
            (\row ->
              tr
                []
                (
                  viewPeriods data row
                  ::
                  List.map
                    (\col -> viewElement data (row, col))
                    (List.range 1 18)
                )
            )
            (List.range 1 10)
        )
    , viewHighlight data
    ]

axisStyle =
  cellBaseStyle
  ++
  [ backgroundColor (rgb 240 230 230)
  , textAlign center
  ]

viewGroups : Data -> Html Msg
viewGroups data =
  tr
    []
    (
      td [] []
      ::
      List.map
        (\group ->
          let
            styles =
              axisStyle
              ++
              case data.highlight of
                Group g ->
                  if group == g then
                    []
                  else
                    [ hideOpacity ]
                
                NoHighlight ->
                  []
                
                Element _ ->
                  []

                _ ->
                  [ hideOpacity ]
          in
          td
            [ css (styles ++ [ position relative ])
            , onMouseEnter (Highlight (Group group))
            , onMouseLeave (Highlight NoHighlight)
            ]
            (
              [ text (String.fromInt group) ]
              ++
              if group == 1 then
                [ div [ css [ position absolute, top (px 1), left (px 8) ] ] [ text "Group ►" ] ]
              else
                []
            )
        )
        (List.range 1 18)
    )

viewPeriods : Data -> Int -> Html Msg
viewPeriods data row =
  let
      styles =
        axisStyle
        ++
        case data.highlight of
          Period p ->
            if row == p then
              []
            else
              [ hideOpacity ]
          
          NoHighlight ->
            []
          
          Element _ ->
            []
          
          _ ->
            [ hideOpacity ]
  in
  if row <= 8 then
    td
      [ css (styles ++ [ position relative ])
      , onMouseEnter (Highlight (Period row))
      , onMouseLeave (Highlight NoHighlight)
      ]
      (
        [ text (String.fromInt row) ]
        ++
        if row == 1 then
          [ div [ css [ position absolute, top (px 1), left (px 7) ] ] [ text "Period ▼"] ]
        else
          []
      )
  else
    td [] []

cellBaseStyle : List Style
cellBaseStyle =
  [ width (px 58)
  , maxWidth (px 58)
  , height (px 58)
  , maxHeight (px 58)
  , padding (px 0)
  , border3 (px 1) solid (rgb 255 255 255)
  ]

cell : String -> List (Attribute Msg) -> List (Html Msg) -> Html Msg
cell category =
  let
    bgColor = getCategoryColor category

    styles =
      cellBaseStyle
      ++
      [ backgroundColor bgColor
      , hover
          [ backgroundColor (rgba bgColor.red bgColor.green bgColor.blue 0.6) ]
      ]
  in
  styled td styles

hideOpacity = opacity (num 0.2)

cellStyles : Data -> ElementPosition -> List Style
cellStyles data position =
  let
      (row, col) = position
  in
  case data.highlight of
    NoHighlight ->
      []
    
    Group group ->
      if col /= group then
        [ hideOpacity ]
      else if col /= 3 && row > 8 then
        [ hideOpacity ]
      else if col == 3 && List.member row [6,7] then
        [ hideOpacity ]
      else
        []
    
    Period period ->
      case Dict.get position data.periodicTable of
        Nothing ->
          if row == period then
            []
          else
            [ hideOpacity ]
        
        Just e ->
          if e.period == period then
            []
          else
            [ hideOpacity ]
    
    Lanthanides ->
      if position == (6, 3) || row == 9 then
        []
      else
        [ hideOpacity ]
    
    Actinides ->
      if position == (7, 3) || row == 10 then
        []
      else
        [ hideOpacity ]
    
    _ ->
      []

viewElement : Data -> ElementPosition -> Html Msg
viewElement data position =
  case Dict.get position data.periodicTable of
    Nothing ->
      case position of
        (6, 3) ->
          cell "lanthanide" 
            [ css (cellStyles data position)
            , onMouseEnter (Highlight Lanthanides)
            , onMouseLeave (Highlight NoHighlight)
            ]
            [ p
                [ css [ textAlign center ] ]
                [ text "57 - 71" ]
            , p
                [ css
                    [ textAlign center
                    , letterSpacing (px -0.5)
                    ]
                ]
                [ text "Lanthanides" ]
            ]
        
        (7, 3) ->
          cell "actinide"
            [ css (cellStyles data position)
            , onMouseEnter (Highlight Actinides)
            , onMouseLeave (Highlight NoHighlight)
            ]
            [ p
                [ css [ textAlign center ] ]
                [ text "89 - 103" ]
            , p
                [ css [ textAlign center ] ]
                [ text "Actinides" ]
            ]
        
        _ ->
          td [] []
    
    Just e ->
      cell e.category
        [ css (cellStyles data position)
        , onMouseEnter (Highlight (Element position))
        , onMouseLeave (Highlight NoHighlight)
        ]
        [ p
            [ css [ margin2 (px 1) (px 2) ] ]
            [ text (String.fromInt e.number) ]
        , p
            [ css
                [ margin2 (px -4) (px 0)
                , fontWeight bold
                , fontSize (px 20)
                , textAlign center
                , color (getPhaseColor e.phase)
                ]
            ]
            [ text e.symbol ]
        , p
            [ css <|
                [ margin (px 0)
                , textAlign center
                ]
                ++
                (if String.length e.name > 11 then
                  [ letterSpacing (px -1.4) ]
                else if String.length e.name > 9 then
                  [ letterSpacing (px -0.7) ]
                else
                  []
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

viewHighlight : Data -> Html Msg
viewHighlight data =
  let
    highlightDiv = styled div
      [ position absolute
      , left (px 257)
      , top (px 80)
      , width (px 134)
      , height (px 134)
      ]
  in
  case data.highlight of
    Element position ->
      case Dict.get position data.periodicTable of
        Nothing ->
          highlightDiv [] []
        
        Just e ->
          let
              bgColor = getCategoryColor e.category
          in
          highlightDiv
            [ css
                [ border3 (px 1) solid (rgb 0 0 0)
                , borderRadius (px 6)
                , backgroundColor bgColor
                ]
            ]
            [ p
                [ css [ margin2 (px 4) (px 4) ] ]
                [ text (String.fromInt e.number) ]
            , p
                [ css
                    [ margin3 (px 2) (px 0) (px 0)
                    , fontWeight bold
                    , fontSize (px 56)
                    , textAlign center
                    , color (getPhaseColor e.phase)
                    ]
                ]
                [ text e.symbol ]
            , p
                [ css
                    (
                      [ margin (px 0)
                      , textAlign center
                      ]
                    )
                ]
                [ text e.name ]
            , p
                [ css
                    [ margin (px 4)
                    , textAlign center
                    ]
                ]
                [ text (Round.round 3 e.atomicMass) ]
            ]
    _ ->
      highlightDiv [] []

-- HTTP

loadPeriodicTable : Cmd Msg
loadPeriodicTable =
  Http.get
    -- https://github.com/v-do/Periodic-Table-JSON/tree/predicted-solids
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
