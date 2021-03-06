module Page.Home.Update exposing (update)

import Api
import Browser.Navigation as Nav
import Comp.ItemList
import Comp.SearchMenu
import Data.Flags exposing (Flags)
import Page exposing (Page(..))
import Page.Home.Data exposing (..)
import Util.Update


update : Nav.Key -> Flags -> Msg -> Model -> ( Model, Cmd Msg )
update key flags msg model =
    case msg of
        Init ->
            Util.Update.andThen1
                [ update key flags (SearchMenuMsg Comp.SearchMenu.Init)
                , doSearch flags
                ]
                model

        ResetSearch ->
            update key flags (SearchMenuMsg Comp.SearchMenu.ResetForm) model

        SearchMenuMsg m ->
            let
                nextState =
                    Comp.SearchMenu.update flags m model.searchMenuModel

                newModel =
                    { model | searchMenuModel = Tuple.first nextState.modelCmd }

                ( m2, c2 ) =
                    if nextState.stateChange then
                        doSearch flags newModel

                    else
                        ( newModel, Cmd.none )
            in
            ( m2, Cmd.batch [ c2, Cmd.map SearchMenuMsg (Tuple.second nextState.modelCmd) ] )

        ItemListMsg m ->
            let
                ( m2, c2, mitem ) =
                    Comp.ItemList.update flags m model.itemListModel

                cmd =
                    case mitem of
                        Just item ->
                            Page.set key (ItemDetailPage item.id)

                        Nothing ->
                            Cmd.none
            in
            ( { model | itemListModel = m2 }, Cmd.batch [ Cmd.map ItemListMsg c2, cmd ] )

        ItemSearchResp (Ok list) ->
            let
                m =
                    { model | searchInProgress = False, viewMode = Listing }
            in
            update key flags (ItemListMsg (Comp.ItemList.SetResults list)) m

        ItemSearchResp (Err _) ->
            ( { model | searchInProgress = False }, Cmd.none )

        DoSearch ->
            doSearch flags model


doSearch : Flags -> Model -> ( Model, Cmd Msg )
doSearch flags model =
    let
        mask =
            Comp.SearchMenu.getItemSearch model.searchMenuModel
    in
    ( { model | searchInProgress = True, viewMode = Listing }
    , Api.itemSearch flags mask ItemSearchResp
    )
