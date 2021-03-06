{-# LANGUAGE FlexibleInstances, MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE JavaScriptFFI, GHCForeignImportPrim #-}
{-# LANGUAGE ExistentialQuantification, DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE BangPatterns #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  Data.Geometry.Structure.Feature
-- Copyright   :  (c) Artem Chirkin
-- License     :  MIT
--
-- Maintainer  :  Artem Chirkin <chirkin@arch.ethz.ch>
-- Stability   :  experimental
-- Portability :
--
--
-----------------------------------------------------------------------------

module Data.Geometry.Structure.Feature
    ( ScenarioJSON (..)
    , FeatureCollection (..)
    , SomeJSONInput (..)
    , HexColor (..), getScProp
    , Feature (..), feature, setFeature
    , GeoJsonGeometryND (..), GeoJsonGeometry (..)
    , FeatureGeometryType (..), featureGeometryType
    , getGeoJSONGeometry, getSizedGeoJSONGeometry
    , boundingBox2D, filterGeometryTypes
    , ParsedFeatureCollection (..), smartProcessFeatureCollection, smartProcessGeometryInput
    , ScenarioProperties (..), defaultScenarioProperties
    ) where


import Control.Applicative ((<|>))
import GHC.TypeLits (KnownNat, SomeNat (..), someNatVal)
---- import GHCJS.Foreign (isTruthy)
--import GHCJS.Marshal.Pure (PToJSVal (..))
import JsHs.Types (JSVal)
import Data.Proxy (Proxy(..))
import JsHs.JSString (JSString, append)
import JsHs.Array as JS
import JsHs.Types.Prim (jsNull, jsIsNullOrUndef)
import JsHs.WebGL (GLfloat)
import Data.Geometry
import qualified Data.Geometry.Structure.PointSet as PS
import Data.Geometry.Structure.LineString (LineString (), MultiLineString ())
import Data.Geometry.Structure.LinearRing (LinearRing ())
import Data.Geometry.Structure.Point (Point (), MultiPoint ())
import Data.Geometry.Structure.Polygon (Polygon (), MultiPolygon ())
import Data.Coerce
import Data.Maybe (fromMaybe)


import Program.Settings


----------------------------------------------------------------------------------------------------
-- Base Types
----------------------------------------------------------------------------------------------------

-- | GeoJSON Feature
newtype Feature = Feature JSVal
instance LikeJS "Object" Feature where
  asJSVal = js_deleteTimestamp

foreign import javascript unsafe "delete $1['properties']['timestamp']; $r = $1;"
  js_deleteTimestamp :: Feature -> JSVal
foreign import javascript unsafe "$1['features'].forEach(function(e){delete e['properties']['timestamp'];}); $r = $1;"
  js_deleteFcTimestamp :: FeatureCollection -> JSVal
foreign import javascript unsafe "$1['geometry']['features'].forEach(function(e){delete e['properties']['timestamp'];}); $r = $1;"
  js_deleteGiTimestamp :: ScenarioJSON -> JSVal

-- | GeoJSON FeatureCollection
newtype FeatureCollection = FeatureCollection JSVal
instance LikeJS "Object" FeatureCollection where
  asJSVal = js_deleteFcTimestamp

instance LikeJSArray "Object" FeatureCollection where
    type ArrayElem FeatureCollection = Feature
    {-# INLINE toJSArray #-}
    toJSArray = js_FCToJSArray
    {-# INLINE fromJSArray #-}
    fromJSArray = js_JSArrayToFC

-- | JSON Scenario
--   Has structure:
--   [root]
--     - geometry:   FeatureCollection
--     - srid:       Maybe Int
--     - lon:        Maybe Float
--     - lat:        Maybe Float
--     - alt:        Maybe Float
--     - ScID:       Int (scenario id)
--     - properties: Arbitrary key-value collection
newtype ScenarioJSON = ScenarioJSON JSVal
instance LikeJS "Object" ScenarioJSON where
  asJSVal = js_deleteGiTimestamp

data SomeJSONInput = SJIExtended ScenarioJSON | SJIGeoJSON FeatureCollection
instance LikeJS "Object" SomeJSONInput where
  asJSVal (SJIExtended gi) = asJSVal gi
  asJSVal (SJIGeoJSON fc) = asJSVal fc

  asLikeJS jsv = case (getProp "type" jsv :: Maybe JSString) of
    Just "FeatureCollection" -> SJIGeoJSON (coerce jsv :: FeatureCollection)
    _ -> SJIExtended (coerce jsv :: ScenarioJSON)

foreign import javascript unsafe "$1['geometry']"
  sjFeatureCollection :: ScenarioJSON -> FeatureCollection
sjSRID :: ScenarioJSON -> Maybe Int
sjSRID (ScenarioJSON js) = getProp "srid" js
sjLon :: ScenarioJSON -> Maybe Float
sjLon (ScenarioJSON js) = getProp "lon" js
sjLat :: ScenarioJSON -> Maybe Float
sjLat (ScenarioJSON js) = getProp "lat" js
sjAlt :: ScenarioJSON -> Maybe Float
sjAlt (ScenarioJSON js) = getProp "alt" js

sjBlockColor :: ScenarioJSON -> Maybe HexColor
sjBlockColor (ScenarioJSON js) = asLikeJS $ getScProp "defaultBlockColor" js
sjActiveColor :: ScenarioJSON -> Maybe HexColor
sjActiveColor (ScenarioJSON js) = asLikeJS $ getScProp "defaultActiveColor" js
sjLineColor :: ScenarioJSON -> Maybe HexColor
sjLineColor (ScenarioJSON js) = asLikeJS $ getScProp "defaultLineColor" js
sjStaticColor :: ScenarioJSON -> Maybe HexColor
sjStaticColor (ScenarioJSON js) = asLikeJS $ getScProp "defaultStaticColor" js
sjMapZoomLevel :: ScenarioJSON -> Maybe Int
sjMapZoomLevel (ScenarioJSON js) = asLikeJS $ getScProp "mapZoomLevel" js
sjUseMapLayer :: ScenarioJSON -> Maybe Bool
sjUseMapLayer (ScenarioJSON js) = asLikeJS $ getScProp "useMapLayer" js
sjForcedArea :: ScenarioJSON -> Maybe (LinearRing 2 Float)
sjForcedArea (ScenarioJSON js) = asLikeJS $ getScProp "forcedArea" js



foreign import javascript unsafe "($2.hasOwnProperty('properties') && $2['properties'] &&\
                                 \ $2['properties'].hasOwnProperty($1)) ? $2['properties'][$1] : null"
    getScProp :: JSString -> JSVal -> JSVal


-- | HexColor

newtype HexColor = HexColor (Vector4 GLfloat)
instance LikeJS "Object" HexColor where
  asJSVal (HexColor v) = js_convertRGBAToHex $ asJSVal v

  asLikeJS val = if isHexColor val
                 then HexColor (asLikeJS (js_convertHexToRGBA val) :: Vector4 GLfloat)
                 else HexColor (vector4 0 0 0 0)

instance {-# OVERLAPPING #-} LikeJS "Object" (Maybe HexColor) where
  asJSVal Nothing = jsNull
  asJSVal (Just color) = js_convertRGBAToHex $ asJSVal color

  asLikeJS val = if isHexColor val
                 then Just $ asLikeJS val
                 else Nothing

isHexColor :: JSVal -> Bool
isHexColor = asLikeJS . js_isHexColor

foreign import javascript unsafe "($1 && ($1.match(/^(#[A-Fa-f0-9]{3,8})$/) !== null))"
    js_isHexColor ::  JSVal -> JSVal

foreign import javascript unsafe "if ($1.match(/^(#[A-Fa-f0-9]{3,8})$/) !== null)\
                                 \ { var a = [0,0,0,1]; var d = $1.length > 5 ? 2 : 1;\
                                 \   $r = a.map(function(e,i){ if (i*d+1 < $1.length)\
                                 \   { return (parseInt($1.substr(i*d+1,d),16) / (Math.pow(16, d) - 1));\
                                 \   } else {return e;} })\
                                 \ } else { $r = null; }"
    js_convertHexToRGBA :: JSVal -> JSVal

foreign import javascript unsafe "($1).reduce(function(a, x){return a.concat(('00').concat((Math.round(x*255)).toString(16)).substr(-2));}, '#')"
    js_convertRGBAToHex :: JSVal -> JSVal

----------------------------------------------------------------------------------------------------
-- Some Functions
----------------------------------------------------------------------------------------------------

data ScenarioProperties = ScenarioProperties
    { defaultBlockColor  :: !HexColor
    , defaultActiveColor :: !HexColor
    , defaultStaticColor :: !HexColor
    , defaultLineColor   :: !HexColor
    , mapZoomLevel       :: !Int
    , useMapLayer        :: !Bool
    , forcedArea         :: !(Maybe (LinearRing 2 Float))
    }

defaultScenarioProperties :: ScenarioProperties
defaultScenarioProperties = ScenarioProperties
    { defaultBlockColor = HexColor (vector4 0.75 0.75 0.7 1)
    , defaultActiveColor = HexColor (vector4 1 0.6 0.6 1)
    , defaultStaticColor = HexColor (vector4 0.5 0.5 0.55 1)
    , defaultLineColor = HexColor (vector4 0.8 0.4 0.4 1)
    , mapZoomLevel = 15
    , useMapLayer = True
    , forcedArea = Nothing
    }

data ParsedFeatureCollection n x = ParsedFeatureCollection
  { pfcPoints     :: JS.Array Feature
  , pfcLines      :: JS.Array Feature
  , pfcPolys      :: JS.Array Feature
  , pfcDeletes    :: JS.Array Int
  , pfcErrors     :: JS.Array JSString
  , pfcMin        :: Vector n x
  , pfcMax        :: Vector n x
  , pfcDims       :: Int
  , pfcLonLatAlt  :: Maybe (Vector 3 Float)
  , pfcSRID       :: Maybe Int
  , pfcScenarioProperties :: ScenarioProperties
  }


-- | This function returns geometry in metric coordinates.
--   i.e. it transforms all coordinates from WGS'84 if possible.
--   Also it provides origin lon+lat+alt if it is possible to infer them.
smartProcessGeometryInput :: Int -- ^ maximum geomId in current City
                          -> Vector n x -- ^ default vector to substitute
                          -> SomeJSONInput
                          -> ParsedFeatureCollection n x
smartProcessGeometryInput n defVals input = case input of
    SJIGeoJSON fc -> smartProcessFeatureCollection n defVals "Unknown" Nothing fc
    SJIExtended gi -> parsedFeatureCollection
                          { pfcSRID = newSRID
                          , pfcLonLatAlt = newLonLatAlt
                          , pfcScenarioProperties = ScenarioProperties pfcBlockColor pfcActiveColor pfcStaticColor pfcLineColor pfcMapZoomLevel pfcUseMapLayer pfcForcedArea
                          }
                        where
                          explicitOLonLatAlt = vector3 <$> sjLon gi <*> sjLat gi <*> sjAlt gi
                          parsedFeatureCollection = smartProcessFeatureCollection n defVals cs explicitOLonLatAlt (sjFeatureCollection gi)
                          cs = case (sjSRID gi, explicitOLonLatAlt) of
                                (Just 4326, _) -> "WGS84"
                                (Nothing, Nothing) -> "Unknown"
                                _ -> "Metric"
                          newSRID = case sjSRID gi of
                            Just 4326 -> Nothing
                            Just i    -> Just i
                            Nothing   -> Nothing
                          newLonLatAlt = case explicitOLonLatAlt of
                            Just xxx -> Just xxx
                            Nothing  -> pfcLonLatAlt parsedFeatureCollection
                          pfcBlockColor = fromMaybe (defaultBlockColor defaultScenarioProperties) $ sjBlockColor gi
                          pfcActiveColor = fromMaybe (defaultActiveColor defaultScenarioProperties) $ sjActiveColor gi
                          pfcStaticColor = fromMaybe (defaultStaticColor defaultScenarioProperties) $ sjStaticColor gi
                          pfcLineColor = fromMaybe (defaultLineColor defaultScenarioProperties) $ sjLineColor gi
                          pfcMapZoomLevel = fromMaybe (mapZoomLevel defaultScenarioProperties) $ sjMapZoomLevel gi
                          pfcUseMapLayer = fromMaybe (useMapLayer defaultScenarioProperties) $ sjUseMapLayer gi
                          -- transform linear ring to the local coordinate system
                          pfcForcedArea = case (,) <$> newLonLatAlt <*> (sjSRID gi <|> pfcSRID parsedFeatureCollection) of
                                Just (lla, 4326) -> js_linearRingWgs84ToMetric lla <$> sjForcedArea gi
                                _ -> sjForcedArea gi

smartProcessFeatureCollection :: Int -- ^ maximum geomId in current City
                              -> Vector n x -- ^ default vector to substitute
                              -> JSString -- ^ determine conversion
                              -> Maybe (Vector3 Float)
                              -> FeatureCollection
                              -> ParsedFeatureCollection n x
smartProcessFeatureCollection n defVals cs originLonLatAlt fc = ParsedFeatureCollection points lins polys deletes errors cmin cmax cdims mLonLatAlt mSRID defaultScenarioProperties
  where
    providedLonLatAlt = asJSVal originLonLatAlt
    mLonLatAlt = asLikeJS jsLonLatAlt :: Maybe (Vector 3 x) -- if SRID = 4326 and originLonLatAlt is provided, then mLonLatAlt == originLonLatAlt
    mSRID = 4326 <$ mLonLatAlt
    (points, lins, polys, deletes, errors, cmin, cmax, cdims, jsLonLatAlt) = js_smartProcessFeatureCollection fc providedLonLatAlt cs defVals n


foreign import javascript unsafe "var a = gm$smartProcessFeatureCollection($1, $2, $3, $4, $5);$r1=a[0];$r2=a[1];$r3=a[2];$r4=a[3];$r5=a[4];$r6=a[5];$r7=a[6];$r8=a[7];$r9=a[8];"
    js_smartProcessFeatureCollection
      :: FeatureCollection -> JSVal -> JSString -> Vector n x -> Int
      -> (JS.Array Feature, JS.Array Feature, JS.Array Feature, JS.Array Int, JS.Array JSString, Vector n x, Vector n x, Int, JSVal)

foreign import javascript unsafe "$2.map(gm$createWGS84toUTMTransform($1[0], $1[1]))"
    js_linearRingWgs84ToMetric
      :: Vector 3 Float -> LinearRing 2 Float -> LinearRing 2 Float


foreign import javascript unsafe "var r = gm$boundNestedArray(($1['geometry'] && $1['geometry']['coordinates']) ? $1['geometry']['coordinates'] : []);\
                          \if(!r){ $r1 = Array.apply(null, Array(2)).map(Number.prototype.valueOf,Infinity);\
                          \        $r2 = Array.apply(null, Array(2)).map(Number.prototype.valueOf,-Infinity);}\
                          \else { $r1 = r[0].slice(0,2); $r2 = r[1].slice(0,2); }"
    boundingBox2D :: Feature -> (Vector2 x, Vector2 x)


{-# INLINE filterGeometryTypes #-}
filterGeometryTypes :: FeatureCollection -> (JS.Array Feature, JS.Array Feature, JS.Array Feature, JS.Array Feature)
filterGeometryTypes = js_filterGeometryTypes . toJSArray

{-# INLINE js_filterGeometryTypes #-}
foreign import javascript unsafe "var t = $1.filter(function(e){return e && e['geometry'] && e['geometry']['type'] && e['geometry']['coordinates'];});\
                                 \$r1 = t.filter(function(e){return (e['geometry']['type'] === 'Point' || e['geometry']['type'] === 'MultiPoint') && e['geometry']['coordinates'][0] != null;});\
                                 \$r2 = t.filter(function(e){return (e['geometry']['type'] === 'LineString' || e['geometry']['type'] === 'MultiLineString') && e['geometry']['coordinates'][0] != null && e['geometry']['coordinates'][0][0] != null;});\
                                 \$r3 = t.filter(function(e){return (e['geometry']['type'] === 'Polygon' || e['geometry']['type'] === 'MultiPolygon') && e['geometry']['coordinates'][0] != null && e['geometry']['coordinates'][0][0] != null && e['geometry']['coordinates'][0][0][0] != null;});\
                                 \$r4 = [];"
    js_filterGeometryTypes :: JS.Array Feature -> (JS.Array Feature, JS.Array Feature, JS.Array Feature, JS.Array Feature)

--foreign import javascript unsafe "($1 != null && $1['geometry'] && $1['geometry']['coordinates'] && $1['geometry']['type'] == 'Point' && $1['geometry'][0] != null)"
--    checkPoint :: Feature -> Bool
--foreign import javascript unsafe "($1 != null && $1['geometry'] && $1['geometry']['coordinates'] && $1['geometry']['type'] == 'MultiPoint' && $1['geometry']['coordinates'][0] != null && $1['geometry']['coordinates'][0][0] != null)"
--    checkMultiPoint :: Feature -> Bool
--foreign import javascript unsafe "($1 != null && $1['geometry'] && $1['geometry']['coordinates'] && $1['geometry']['type'] == 'LineString' && $1['geometry']['coordinates'][0] != null && $1['geometry']['coordinates'][0][0] != null)"
--    checkLineString :: Feature -> Bool
--foreign import javascript unsafe "($1 != null && $1['geometry'] && $1['geometry']['coordinates'] && $1['geometry']['type'] == 'MultiLineString' && $1['geometry']['coordinates'][0] != null && $1['geometry']['coordinates'][0][0] != null && $1['geometry']['coordinates'][0][0][0] != null)"
--    checkMultiLineString :: Feature -> Bool
--foreign import javascript unsafe "($1 != null && $1['geometry'] && $1['geometry']['coordinates'] && $1['geometry']['type'] == 'Polygon' && $1['geometry']['coordinates'][0] != null && $1['geometry']['coordinates'][0][0] != null && $1['geometry']['coordinates'][0][0][0] != null)"
--    checkPolygon :: Feature -> Bool
--foreign import javascript unsafe "($1 != null && $1['geometry'] && $1['geometry']['coordinates'] && $1['geometry']['type'] == 'MultiPolygon' && $1['geometry']['coordinates'][0] != null && $1['geometry']['coordinates'][0][0] != null && $1['geometry']['coordinates'][0][0][0] != null && $1['geometry']['coordinates'][0][0][0][0] != null)"
--    checkMultiPolygon :: Feature -> Bool

setFeature :: GeoJsonGeometry n x -> Feature -> Feature
setFeature geom = js_setFeature (asJSVal geom)

feature :: GeoJsonGeometry n x -> Feature
feature = js_feature . asJSVal


{-# INLINE js_setFeature #-}
foreign import javascript unsafe "$r = {}; $r['properties'] = $2['properties']; $r['type'] = 'Feature'; $r['geometry'] = $1;"
    js_setFeature :: JSVal -> Feature -> Feature

{-# INLINE js_feature #-}
foreign import javascript unsafe "$r = {}; $r['properties'] = {}; $r['type'] = 'Feature'; $r['geometry'] = $1;"
    js_feature :: JSVal -> Feature

----------------------------------------------------------------------------------------------------
-- Getting Geometry
----------------------------------------------------------------------------------------------------

data FeatureGeometryType = FeaturePoint
                         | FeatureMultiPoint
                         | FeatureLineString
                         | FeatureMultiLineString
                         | FeaturePolygon
                         | FeatureMultiPolygon


featureGeometryType :: Feature -> FeatureGeometryType
featureGeometryType = asLikeJS . js_featureGeometryType

foreign import javascript unsafe "$r = $1['geometry']['type'];"
    js_featureGeometryType :: Feature -> JSVal

instance LikeJS "String" FeatureGeometryType where
    asJSVal FeaturePoint           = asJSVal ("Point" :: JSString)
    asJSVal FeatureMultiPoint      = asJSVal ("MultiPoint" :: JSString)
    asJSVal FeatureLineString      = asJSVal ("LineString" :: JSString)
    asJSVal FeatureMultiLineString = asJSVal ("MultiLineString" :: JSString)
    asJSVal FeaturePolygon         = asJSVal ("Polygon" :: JSString)
    asJSVal FeatureMultiPolygon    = asJSVal ("MultiPolygon" :: JSString)
    asLikeJS jsv = case asLikeJS jsv :: JSString of
                     "Point"           -> FeaturePoint
                     "MultiPoint"      -> FeatureMultiPoint
                     "LineString"      -> FeatureLineString
                     "MultiLineString" -> FeatureMultiLineString
                     "Polygon"         -> FeaturePolygon
                     "MultiPolygon"    -> FeatureMultiPolygon
                     _                 -> FeaturePoint


data GeoJsonGeometryND x = forall n . KnownNat n => ND (GeoJsonGeometry n x)

data GeoJsonGeometry n x = GeoPoint (Point n x)
                         | GeoMultiPoint (MultiPoint n x)
                         | GeoLineString (LineString n x)
                         | GeoMultiLineString (MultiLineString n x)
                         | GeoPolygon (Polygon n x)
                         | GeoMultiPolygon (MultiPolygon n x)

instance LikeJS "Array" (GeoJsonGeometry n x) where
    asJSVal (GeoPoint x)           = asJSVal x
    asJSVal (GeoMultiPoint x)      = asJSVal x
    asJSVal (GeoLineString x)      = asJSVal x
    asJSVal (GeoMultiLineString x) = asJSVal x
    asJSVal (GeoPolygon x)         = asJSVal x
    asJSVal (GeoMultiPolygon x)    = asJSVal x
    asLikeJS _ = undefined



-- | Get Feature GeoJSON geometry, without knowledge of how many dimensions there are in geometry
getGeoJSONGeometry :: Feature -> Either JSString (GeoJsonGeometryND x)
getGeoJSONGeometry fe = if not (jsIsNullOrUndef js)
    then let mdims = someNatVal . toInteger $ getDimensionality js
         in case mdims of
             Nothing -> Left "Cannot parse GeoJsonGeometryND: failed to find dimensionality of the data"
             Just (SomeNat proxy) -> getGeoJSONGeometryN js >>= Right . ND . dimensionalize' proxy
    else Left "Cannot parse GeoJsonGeometryND: it is falsy!"
    where js = getGeoJSONGeometry' fe

-- | Get geometry of certain dimensionality;
--   Does not check the real dimensionality of geoJSON geometry!
getGeoJSONGeometryN :: JSVal -> Either JSString (GeoJsonGeometry n x)
getGeoJSONGeometryN js = if not (jsIsNullOrUndef js)
        then case getGeoJSONType js of
--            "Point"           -> if checkPoint js then Right . GeoPoint $ asLikeJS js else Left "Not a proper GeoJSON Feature."
--            "MultiPoint"      -> if checkMultiPoint js then Right . GeoMultiPoint $ asLikeJS js else Left "Not a proper GeoJSON Feature."
--            "LineString"      -> if checkLineString js then Right . GeoLineString $ asLikeJS js else Left "Not a proper GeoJSON Feature."
--            "MultiLineString" -> if checkMultiLineString js then Right . GeoMultiLineString $ asLikeJS js else Left "Not a proper GeoJSON Feature."
--            "Polygon"         -> if checkPolygon js then Right . GeoPolygon $ asLikeJS js else Left "Not a proper GeoJSON Feature."
--            "MultiPolygon"    -> if checkMultiPolygon js then Right . GeoMultiPolygon $ asLikeJS js else Left "Not a proper GeoJSON Feature."
--            t                 -> Left $ "Cannot parse GeoJsonGeometry: type " `append` t `append` " is not supported."
            "Point"           -> Right . GeoPoint $ asLikeJS js
            "MultiPoint"      -> Right . GeoMultiPoint $ asLikeJS js
            "LineString"      -> Right . GeoLineString $ asLikeJS js
            "MultiLineString" -> Right . GeoMultiLineString $ asLikeJS js
            "Polygon"         -> Right . GeoPolygon $ asLikeJS js
            "MultiPolygon"    -> Right . GeoMultiPolygon $ asLikeJS js
            t                 -> Left $ "Cannot parse GeoJsonGeometry: type " `append` t `append` " is not supported."
        else Left "Cannot parse GeoJsonGeometry: it is falsy!"

-- | Try to resize geometry inside feature to required dimensionality, and then return it
getSizedGeoJSONGeometry :: Vector n x -- ^ values to substitute into each coordinate if the vector dimensionality is larger than that of points
                        -> Feature -> Either JSString (GeoJsonGeometry n x)
getSizedGeoJSONGeometry v fe = if not (jsIsNullOrUndef js)
    then getGeoJSONGeometryN $ js_getSizedGeoJSONGeometry v js
    else Left "Cannot parse GeoJsonGeometry: it is falsy!"
    where js = getGeoJSONGeometry' fe



foreign import javascript unsafe "var res = gm$resizeNestedArray($1,$2['coordinates']); $r = {}; $r['coordinates'] = res; $r['type'] = $2['type'];"
    js_getSizedGeoJSONGeometry :: Vector n x -> JSVal -> JSVal


{-# INLINE dimensionalize' #-}
dimensionalize' :: KnownNat n => Proxy n -> GeoJsonGeometry n x -> GeoJsonGeometry n x
dimensionalize' _ = id



{-# INLINE getGeoJSONType #-}
foreign import javascript unsafe "$1['type']"
    getGeoJSONType :: JSVal -> JSString
{-# INLINE getGeoJSONGeometry #-}
foreign import javascript unsafe "$1['geometry']"
    getGeoJSONGeometry' :: Feature -> JSVal



{-# INLINE getDimensionality #-}
-- | Get length of the coordinates in GeoJSON object.
--   Default length is 3.
foreign import javascript unsafe "var dims = $1['coordinates'] ? gm$GeometryDims($1['coordinates']) : 3; $r = dims === 0 ? 3 : dims;"
    getDimensionality :: JSVal -> Int



instance PS.PointSet (GeoJsonGeometry n x) n x where
    {-# INLINE flatten #-}
    flatten (GeoPoint x)           = PS.flatten x
    flatten (GeoMultiPoint x)      = PS.flatten x
    flatten (GeoLineString x)      = PS.flatten x
    flatten (GeoMultiLineString x) = PS.flatten x
    flatten (GeoPolygon x)         = PS.flatten x
    flatten (GeoMultiPolygon x)    = PS.flatten x
    {-# INLINE toPointArray #-}
    toPointArray (GeoPoint x)           = PS.toPointArray x
    toPointArray (GeoMultiPoint x)      = PS.toPointArray x
    toPointArray (GeoLineString x)      = PS.toPointArray x
    toPointArray (GeoMultiLineString x) = PS.toPointArray x
    toPointArray (GeoPolygon x)         = PS.toPointArray x
    toPointArray (GeoMultiPolygon x)    = PS.toPointArray x
    {-# INLINE fromPointArray #-}
    fromPointArray = GeoMultiPoint . PS.fromPointArray
    {-# INLINE mean #-}
    mean (GeoPoint x)           = PS.mean x
    mean (GeoMultiPoint x)      = PS.mean x
    mean (GeoLineString x)      = PS.mean x
    mean (GeoMultiLineString x) = PS.mean x
    mean (GeoPolygon x)         = PS.mean x
    mean (GeoMultiPolygon x)    = PS.mean x
    {-# INLINE var #-}
    var (GeoPoint x)           = PS.var x
    var (GeoMultiPoint x)      = PS.var x
    var (GeoLineString x)      = PS.var x
    var (GeoMultiLineString x) = PS.var x
    var (GeoPolygon x)         = PS.var x
    var (GeoMultiPolygon x)    = PS.var x
    {-# INLINE mapSet #-}
    mapSet f (GeoPoint x)           = GeoPoint           $ PS.mapSet f x
    mapSet f (GeoMultiPoint x)      = GeoMultiPoint      $ PS.mapSet f x
    mapSet f (GeoLineString x)      = GeoLineString      $ PS.mapSet f x
    mapSet f (GeoMultiLineString x) = GeoMultiLineString $ PS.mapSet f x
    mapSet f (GeoPolygon x)         = GeoPolygon         $ PS.mapSet f x
    mapSet f (GeoMultiPolygon x)    = GeoMultiPolygon    $ PS.mapSet f x
    {-# INLINE mapCallbackSet #-}
    mapCallbackSet f (GeoPoint x)           = GeoPoint           $ PS.mapCallbackSet f x
    mapCallbackSet f (GeoMultiPoint x)      = GeoMultiPoint      $ PS.mapCallbackSet f x
    mapCallbackSet f (GeoLineString x)      = GeoLineString      $ PS.mapCallbackSet f x
    mapCallbackSet f (GeoMultiLineString x) = GeoMultiLineString $ PS.mapCallbackSet f x
    mapCallbackSet f (GeoPolygon x)         = GeoPolygon         $ PS.mapCallbackSet f x
    mapCallbackSet f (GeoMultiPolygon x)    = GeoMultiPolygon    $ PS.mapCallbackSet f x
    {-# INLINE foldSet #-}
    foldSet f a (GeoPoint x)           = PS.foldSet f a x
    foldSet f a (GeoMultiPoint x)      = PS.foldSet f a x
    foldSet f a (GeoLineString x)      = PS.foldSet f a x
    foldSet f a (GeoMultiLineString x) = PS.foldSet f a x
    foldSet f a (GeoPolygon x)         = PS.foldSet f a x
    foldSet f a (GeoMultiPolygon x)    = PS.foldSet f a x
    {-# INLINE foldCallbackSet #-}
    foldCallbackSet f a (GeoPoint x)           = PS.foldCallbackSet f a x
    foldCallbackSet f a (GeoMultiPoint x)      = PS.foldCallbackSet f a x
    foldCallbackSet f a (GeoLineString x)      = PS.foldCallbackSet f a x
    foldCallbackSet f a (GeoMultiLineString x) = PS.foldCallbackSet f a x
    foldCallbackSet f a (GeoPolygon x)         = PS.foldCallbackSet f a x
    foldCallbackSet f a (GeoMultiPolygon x)    = PS.foldCallbackSet f a x

----------------------------------------------------------------------------------------------------
-- FeatureCollection converters
----------------------------------------------------------------------------------------------------

{-# INLINE js_FCToJSArray #-}
foreign import javascript unsafe "$1['features']"
    js_FCToJSArray :: FeatureCollection -> JS.Array Feature
{-# INLINE js_JSArrayToFC #-}
foreign import javascript unsafe "$r = {}; $r['type'] = 'FeatureCollection'; $r['features'] = $1"
    js_JSArrayToFC :: JS.Array Feature -> FeatureCollection
