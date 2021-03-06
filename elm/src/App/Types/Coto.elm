module App.Types.Coto
    exposing
        ( ElementId
        , CotoId
        , CotonomaKey
        , Coto
        , summaryMaxlength
        , updateContent
        , checkWritePermission
        , Cotonoma
        , toCoto
        , cotonomaNameMaxlength
        , validateCotonomaName
        , revisedBefore
        , CotonomaStats
        )

import Date exposing (Date)
import App.Types.Amishi exposing (Amishi)
import App.Types.Session exposing (Session)
import Util.StringUtil exposing (isBlank)


type alias ElementId =
    String


type alias CotoId =
    String


type alias CotonomaKey =
    String


type alias Coto =
    { id : CotoId
    , content : String
    , summary : Maybe String
    , amishi : Maybe Amishi
    , postedIn : Maybe Cotonoma
    , postedAt : Date
    , asCotonoma : Bool
    , cotonomaKey : Maybe CotonomaKey
    }


summaryMaxlength : Int
summaryMaxlength =
    200


updateContent : String -> Coto -> Coto
updateContent content coto =
    { coto | content = content }


checkWritePermission : Session -> { r | amishi : Maybe Amishi } -> Bool
checkWritePermission session coto =
    (Maybe.map (\amishi -> amishi.id) coto.amishi) == (Just session.id)


type alias Cotonoma =
    { id : String
    , key : CotonomaKey
    , name : String
    , pinned : Bool
    , cotoId : CotoId
    , owner : Maybe Amishi
    , postedAt : Date
    , updatedAt : Date
    , timelineRevision : Int
    , graphRevision : Int
    }


toCoto : Cotonoma -> Coto
toCoto cotonoma =
    Coto
        cotonoma.cotoId
        cotonoma.name
        Nothing
        cotonoma.owner
        Nothing
        cotonoma.postedAt
        True
        (Just cotonoma.key)


cotonomaNameMaxlength : Int
cotonomaNameMaxlength =
    50


validateCotonomaName : String -> Bool
validateCotonomaName string =
    not (isBlank string) && (String.length string) <= cotonomaNameMaxlength


revisedBefore : Cotonoma -> Bool
revisedBefore cotonoma =
    (cotonoma.timelineRevision > 0) || (cotonoma.graphRevision > 0)


type alias CotonomaStats =
    { key : CotonomaKey
    , cotos : Int
    , connections : Int
    }
