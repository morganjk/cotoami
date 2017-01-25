module Components.Timeline exposing (..)

import Html exposing (..)
import Html.Keyed
import Html.Attributes exposing (..)
import Html.Events exposing (on, onClick, onMouseDown, onFocus, onBlur, onInput, keyCode)
import Dom
import Dom.Scroll
import Http
import Task
import Process
import Time
import Markdown
import Markdown.Config exposing (defaultElements, defaultOptions)
import Json.Decode as Decode
import Json.Encode as Encode
import Keyboard exposing (..)
import Keys exposing (ctrl, meta, enter)
import Exts.Maybe exposing (isJust, isNothing)
import Utils exposing (isBlank)
import App.Types exposing (Session)


type alias Coto =
    { id : Maybe Int
    , postId : Maybe Int
    , content : String
    }


type alias Model =
    { editingNewCoto : Bool
    , newCotoContent : String
    , postIdCounter : Int
    , cotos : List Coto
    }


initModel : Model
initModel =
    { editingNewCoto = False
    , newCotoContent = ""
    , postIdCounter = 0
    , cotos = []
    }


type Msg
    = NoOp
    | CotosFetched (Result Http.Error (List Coto))
    | ImageLoaded
    | CotoClick Int
    | EditorFocus
    | EditorBlur
    | EditorInput String
    | EditorKeyDown KeyCode
    | Post
    | CotoPosted (Result Http.Error Coto)
    

update : Msg -> Model -> Bool -> ( Model, Cmd Msg )
update msg model ctrlDown =
    case msg of
        NoOp ->
            model ! []
            
        CotosFetched (Ok cotos) ->
            ( { model | cotos = cotos }, scrollToBottom )
            
        ImageLoaded ->
            model ! [ scrollToBottom ]
            
        CotosFetched (Err _) ->
            ( model, Cmd.none )
            
        CotoClick cotoId ->
            ( model, Cmd.none )

        EditorFocus ->
            ( { model | editingNewCoto = True }, Cmd.none )

        EditorBlur ->
            ( { model | editingNewCoto = False }, Cmd.none )

        EditorInput content ->
            ( { model | newCotoContent = content }, Cmd.none )

        EditorKeyDown key ->
            if key == enter.keyCode && ctrlDown && (not (isBlank model.newCotoContent)) then
                post model
            else
                ( model, Cmd.none )
                
        Post ->
            post model
                
        CotoPosted (Ok savedCoto) ->
            { model 
            | cotos = 
                List.map 
                    (\c -> if c.postId == savedCoto.postId then savedCoto else c) 
                    model.cotos 
            } ! []
          
        CotoPosted (Err _) ->
            ( model, Cmd.none )
          

post : Model -> ( Model, Cmd Msg )
post model =
    let
        postId = model.postIdCounter + 1
        newCoto = Coto Nothing (Just postId) model.newCotoContent
    in
        { model 
        | cotos = newCoto :: model.cotos
        , postIdCounter = postId
        , newCotoContent = ""
        } ! 
        [ scrollToBottom
        , postCoto newCoto
        ]


scrollToBottom : Cmd Msg
scrollToBottom =
    Process.sleep (1 * Time.millisecond)
    |> Task.andThen (\x -> (Dom.Scroll.toBottom "timeline"))
    |> Task.attempt handleScrollResult 


handleScrollResult : Result Dom.Error () -> Msg
handleScrollResult result =
    case result of
        Ok _ ->
            NoOp

        Err _ ->
            NoOp


fetchCotos : Cmd Msg
fetchCotos =
    Http.send CotosFetched (Http.get "/api/cotos" (Decode.list decodeCoto))


postCoto : Coto -> Cmd Msg
postCoto coto =
    Http.send 
        CotoPosted 
        (Http.post "/api/cotos" (Http.jsonBody (encodeCoto coto)) decodeCoto)
        
        
decodeCoto : Decode.Decoder Coto
decodeCoto =
    Decode.map3 Coto
        (Decode.maybe (Decode.field "id" Decode.int))
        (Decode.maybe (Decode.field "postId" Decode.int))
        (Decode.field "content" Decode.string)


encodeCoto : Coto -> Encode.Value
encodeCoto coto =
    Encode.object 
        [ ("coto", 
            (Encode.object 
                [ ("postId", 
                    case coto.postId of
                        Nothing -> Encode.null 
                        Just postId -> Encode.int postId
                  )
                , ("content", Encode.string coto.content)
                ]
            )
          )
        ]
      
      
view : Model -> Maybe Session -> Maybe Int -> Html Msg
view model session activeCotoId =
    div [ id "timeline-column", class (timelineClass model) ]
        [ timelineDiv model session activeCotoId
        , div [ id "new-coto" ]
            [ div [ class "toolbar", hidden (not model.editingNewCoto) ]
                [ (case session of
                      Nothing -> 
                          span [ class "user anonymous" ]
                              [ i [ class "material-icons" ] [ text "perm_identity" ]
                              , text "Anonymous"
                              ]
                      Just session -> 
                          span [ class "user session" ]
                              [ img [ class "avatar", src session.avatarUrl ] []
                              , span [ class "name" ] [ text session.displayName ]
                              ]
                  )
                , div [ class "tool-buttons" ]
                    [ button 
                        [ class "button-primary"
                        , disabled (isBlank model.newCotoContent)
                        , onMouseDown Post 
                        ]
                        [ text "Post"
                        , span [ class "shortcut-help" ] [ text "(Ctrl + Enter)" ]
                        ]
                    ]
                ]
            , textarea
                [ class "coto"
                , placeholder "Write your idea in Markdown"
                , value model.newCotoContent
                , onFocus EditorFocus
                , onBlur EditorBlur
                , onInput EditorInput
                , onKeyDown EditorKeyDown
                ]
                []
            ]
        ]


timelineDiv : Model -> Maybe Session -> Maybe Int  -> Html Msg
timelineDiv model session activeCotoId =
    Html.Keyed.node
        "div"
        [ id "timeline" ]
        (List.map 
            (\coto -> 
                ( getKey coto
                , div
                    [ classList 
                        [ ( "coto", True )
                        , ( "active", isActive coto activeCotoId )
                        , ( "posting", (isJust session) && (isNothing coto.id) )
                        ]
                    , (case coto.id of
                        Nothing -> onClick NoOp
                        Just cotoId -> onClick (CotoClick cotoId)
                      )
                    ] 
                    [ a 
                        [ class "open-coto"
                        , title "Open coto view"
                        ] 
                        [ i [ class "material-icons" ] [ text "open_in_new" ] ]
                    , markdown coto.content 
                    ]
                )
            ) 
            (List.reverse model.cotos)
        )


getKey : Coto -> String
getKey coto =
    case coto.id of
        Just cotoId -> toString cotoId
        Nothing -> 
            case coto.postId of
                Just postId -> toString postId
                Nothing -> ""
        

isActive : Coto -> Maybe Int -> Bool
isActive coto activeCotoId =
    case coto.id of
        Nothing -> False
        Just cotoId -> (Maybe.withDefault -1 activeCotoId) == cotoId
    
        
markdown : String -> Html Msg
markdown content =
    div [ class "content" ]
        <| Markdown.customHtml 
            { defaultOptions
            | softAsHardLineBreak = True
            }
            { defaultElements
            | link = customLinkElement
            , image = customImageElement
            }
            content


customLinkElement : Markdown.Config.Link -> List (Html Msg) -> Html Msg
customLinkElement link =
    a <|
        [ href link.url
        , title (Maybe.withDefault "" link.title)
        , target "_blank"
        , rel "noopener noreferrer"
        ]


customImageElement : Markdown.Config.Image -> Html Msg
customImageElement image =
    img
        [ src image.src
        , alt image.alt
        , title (Maybe.withDefault "" image.title)
        , onLoad ImageLoaded
        ]
        []
  

timelineClass : Model -> String
timelineClass model =
    if model.editingNewCoto then
        "editing"
    else
        ""


onKeyDown : (Int -> msg) -> Attribute msg
onKeyDown tagger =
    on "keydown" (Decode.map tagger keyCode)


onLoad : msg -> Attribute msg
onLoad message =
  on "load" (Decode.succeed message)
  
  