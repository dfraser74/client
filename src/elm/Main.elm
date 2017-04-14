port module Main exposing (..)


import Html exposing (..)
import Html.Lazy exposing (lazy, lazy2)
import Tuple exposing (first, second)
import Dict
import Json.Decode as Json
import Dom
import Task
import List.Extra as ListExtra

import Types exposing (..)
import Trees exposing (..)
import TreeUtils exposing (getTree, getParent, getIndex, (?))
import Coders exposing (nodeListToValue)
import Sha1 exposing (timeJSON)


main : Program Json.Value Model Msg
main =
  programWithFlags
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }


port activateCards : (Int, List (List String)) -> Cmd msg
port getText : String -> Cmd msg
port saveNodes : Json.Value -> Cmd msg




-- MODEL


type alias Model =
  { data : Trees.Model
  , viewState : ViewState
  }


defaultModel : Model
defaultModel =
  { data = Trees.defaultModel
  , viewState =
      { active = "0"
      , activePast = []
      , activeFuture = []
      , descendants = []
      , editing = Just "0"
      }
  }


init : Json.Value -> (Model, Cmd Msg)
init savedState =
  defaultModel ! []




-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
  let
    vs = model.viewState
    data = model.data
  in
  case msg of
    -- === Card Activation ===

    Activate id ->
      let
        activeTree_ = getTree id model.data.tree
      in
      case activeTree_ of
        Just activeTree ->
          { model
            | viewState = { vs | active = id }
          }
            ! []

        Nothing ->
          model ! []

    -- === Card Editing  ===

    OpenCard id str ->
      { model
        | viewState = { vs | active = id, editing = Just id }
      }
        ! []

    GetContentToSave id ->
      model ! [getText id]

    UpdateContent (id, str) ->
      { model
        | data = Trees.updatePending (Trees.Mod id str) model.data
        , viewState = { vs | active = id, editing = Nothing }
      }
        ! []
        |> andThen AttemptSave

    -- === Card Insertion  ===

    Insert pid pos ->
      let
        newId = "node-" ++ (timeJSON ())
      in
      { model
        | data = Trees.updatePending (Trees.Add newId pid pos) model.data
      }
        ! []
        |> andThen (OpenCard newId "")
        |> andThen (Activate newId)
        |> andThen AttemptSave

    InsertAbove id ->
      let
        idx =
          getIndex id model.data.tree ? 999999

        pid_ =
          getParent id model.data.tree |> Maybe.map .id

        insertMsg =
          case pid_ of
            Just pid ->
              Insert pid idx

            Nothing ->
              NoOp
      in
      update insertMsg model

    InsertChild id ->
      update (Insert id 999999) model
    
    -- === Ports ===

    AttemptSave ->
      model ! [saveNodes (model.data.pending |> nodeListToValue)]

    SaveResponses res ->
      let
        okIds =
          res
            |> List.filter .ok
            |> List.map .id

        newPending =
          data.pending
            |> List.filter (\(id, ptn) -> not <| List.member id okIds)

        modifiedNodes =
          res
            |> List.filter .ok
            |> List.filterMap
                (\r ->
                  data.pending
                    |> ListExtra.find (\(id, ptn) -> id == r.id)
                    |> Maybe.andThen (\(id, tn) -> Just (id, {tn | rev = Just r.rev }))
                )
            |> Dict.fromList

        newNodes =
          Dict.union modifiedNodes data.nodes
      in
      { model
        | data =
            { data
              | nodes = newNodes
              , pending = newPending
              }
                |> Trees.updateData
      }
        ! []

    HandleKey key ->
      case key of
        "mod+x" ->
          let _ = Debug.log "model" model in
          model ! []

        _ ->
          model ! []

    _ ->
      model ! []


andThen : Msg -> ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
andThen msg (model, prevMsg) =
  let
    newStep =
      update msg model
  in
  ( first newStep, Cmd.batch [prevMsg, second newStep] )


onlyIf : Bool -> Msg -> ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
onlyIf cond msg prevStep =
  if cond then
    prevStep
      |> andThen msg
  else
    prevStep




-- VIEW


view : Model -> Html Msg
view model =
  (lazy2 Trees.view model.viewState model.data)




-- SUBSCRIPTIONS


port keyboard : (String -> msg) -> Sub msg
port updateContent : ((String, String) -> msg) -> Sub msg
port saveResponses : (List Response -> msg) -> Sub msg


subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.batch
    [ keyboard HandleKey
    , updateContent UpdateContent
    , saveResponses SaveResponses
    ]




-- HELPERS

focus : String -> Cmd Msg
focus id =
  Task.attempt (\_ -> NoOp) (Dom.focus ("card-edit-" ++ id))


run : Msg -> Cmd Msg
run msg =
  Task.attempt (\_ -> msg ) (Task.succeed msg)


editMode : Model -> (String -> Msg) -> (Model, Cmd Msg)
editMode model editing = 
  case model.viewState.editing of
    Nothing ->
      model ! []

    Just uid ->
      update (editing uid) model


normalMode : Model -> Msg -> (Model, Cmd Msg)
normalMode model msg = 
  case model.viewState.editing of
    Nothing ->
      update msg model

    Just _ ->
      model ! []
