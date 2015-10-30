module SvgControls where

import Effects exposing (Effects, Never)
import Html 
import SvgButton
import SvgSlider
import Task
import List exposing (..)
import Dict exposing (..)
import Json.Decode as Json exposing ((:=))
import Util exposing (..)
import Svg 
import Svg.Attributes as SA 
import SvgThings
import Controls

-- json spec
type alias Spec = 
  { title: String
  , controls: List Controls.Spec
  }

jsSpec : Json.Decoder Spec
jsSpec = Json.object2 Spec 
  ("title" := Json.string)
  ("controls" := Json.list Controls.jsSpec) 


type alias Model =
  { title: String  
  , butts: Dict ID Controls.Model 
  , mahrect: SvgThings.Rect 
  , srect: SvgThings.SRect 
  , nextID: ID 
  , spec: Spec
  , mahsend : (String -> Task.Task Never ())
  }

type alias ID = Int

-- UPDATE

type Action
    = JsonMsg String 
    | CAction ID Controls.Action 
    | WinDims (Int, Int)

update : Action -> Model -> (Model, Effects Action)
update action model =
  case action of
    JsonMsg s -> 
      let t = Json.decodeString jsSpec s
       in case t of 
          Ok spec -> init model.mahsend spec model.mahrect 
          Err e -> ({model | title <- e}, Effects.none)
    CAction id act -> 
      let bb = get id model.butts in
      case bb of 
        Just bm -> 
          let wha = Controls.update act bm 
              updbutts = insert id (fst wha) model.butts
              newmod = { model | butts <- updbutts }
            in
              (newmod, Effects.map (CAction id) (snd wha))
        Nothing -> (model, Effects.none) 
    WinDims (x,y) -> 
      init model.mahsend model.spec (SvgThings.Rect 0 0 x y)
        
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

init: (String -> Task.Task Never ()) -> Spec -> SvgThings.Rect 
  -> (Model, Effects Action)
init sendf spec rect = 
  let rlist = SvgThings.hrects rect (List.length spec.controls)
      blist = List.map (\(a, b) -> Controls.init sendf a b) (zip spec.controls rlist)
      idxs = [0..(length spec.controls)]  
      buttz = zip idxs (List.map fst blist) 
      fx = Effects.batch 
             (List.map (\(i,a) -> Effects.map (CAction i) a)
                  (zip idxs (List.map snd blist)))
    in
     (Model spec.title (Dict.fromList buttz) rect (SvgThings.toSRect rect) (length spec.controls) spec sendf, fx)
      

-- VIEW

(=>) = (,)

view : Signal.Address Action -> Model -> Html.Html
view address model =
  let buttl = Dict.toList model.butts in 
  Html.div [] (
    [Html.text "meh", 
     Html.br [] [],
     Html.text model.title, 
     Html.text (toString (length buttl)),
     Html.br [] []] 
    ++ 
    [Svg.svg
      [ SA.width model.srect.w
      , SA.height model.srect.h
      , SA.viewBox (model.srect.x ++ " " 
                 ++ model.srect.y ++ " " 
                 ++ model.srect.w ++ " "
                 ++ model.srect.h)
      ]
      (List.map (viewSvgControls address) buttl)
    ])

viewSvgControls : Signal.Address Action -> (ID, Controls.Model) -> Svg.Svg 
viewSvgControls address (id, model) =
  Controls.view (Signal.forwardTo address (CAction id)) model


