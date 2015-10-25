module MultiSvgButt where

import Effects exposing (Effects, Never)
import Html 
import SvgButton
import Task
import List exposing (..)
import Dict exposing (..)
import Json.Decode as Json exposing ((:=))
import Util exposing (..)
import Svg 
import Svg.Attributes as SA 

--import Svg.Attributes exposing (viewBox)
--import Html.Attributes exposing (width, height)

-- json spec
type alias Spec = 
  {
    title: String,
    buttons: List SvgButton.Spec
  }

jsSpec : Json.Decoder Spec
jsSpec = Json.object2 Spec 
  ("title" := Json.string)
  ("buttons" := Json.list SvgButton.jsSpec)


type alias Model =
    {
      title: String, 
      butts: Dict ID SvgButton.Model,
      nextID: ID,
      mahsend : (String -> Task.Task Never ())
    }

type alias ID = Int

-- UPDATE

type Action
    = JsonMsg String 
    | BAction ID SvgButton.Action 

update : Action -> Model -> (Model, Effects Action)
update action model =
  case action of
    JsonMsg s -> 
      let t = Json.decodeString jsSpec s
       in case t of 
          Ok spec -> init model.mahsend spec 
          Err e -> ({model | title <- e}, Effects.none)
    BAction id act -> 
      let bb = get id model.butts in
      case bb of 
        Just bm -> 
          let wha = SvgButton.update act bm 
              updbutts = insert id (fst wha) model.butts
              newmod = { model | butts <- updbutts }
            in
              (newmod, Effects.map (BAction id) (snd wha))
        Nothing -> (model, Effects.none) 
        
find: a -> List (a, b) -> Maybe b
find a ablist =
  case ablist of 
    ((av,b)::rest) -> 
      if (a == av) 
        then Just b
        else (find a rest)
    [] -> Nothing

replace: a -> b -> List (a,b) -> List (a,b)
replace a b ablist =
  case ablist of 
    ((av,bv)::rest) -> 
      if (a == av) 
        then (a,b) :: rest 
        else (av,bv) :: (replace a b rest)
    [] -> [(a,b)]

init: (String -> Task.Task Never ()) -> Spec -> (Model, Effects Action)
init sendf spec = 
  let blist = List.map (SvgButton.init sendf) spec.buttons
      idxs = [0..(length spec.buttons)]  
      buttz = zip idxs (List.map fst blist) 
      fx = Effects.batch 
             (List.map (\(i,a) -> Effects.map (BAction i) a)
                  (zip idxs (List.map snd blist)))
    in
     (Model spec.title (Dict.fromList buttz) (length spec.buttons) sendf, fx)
      

-- VIEW

(=>) = (,)

view : Signal.Address Action -> Model -> Html.Html
view address model =
  let buttl = Dict.toList model.butts in 
  Html.div [] (
    [Html.text "meh", 
     Html.text model.title, 
     Html.text (toString (length buttl)),
     Html.br [] []] 
    ++ 
    [Svg.svg
      [ SA.width "200", SA.height "200", SA.viewBox "0 0 200 200" ]
      (List.map (viewSvgButton address) buttl)])

viewSvgButton : Signal.Address Action -> (ID, SvgButton.Model) -> Svg.Svg 
viewSvgButton address (id, model) =
  SvgButton.view (Signal.forwardTo address (BAction id)) model


