{-# LANGUAGE FlexibleContexts #-}

{-# LANGUAGE DataKinds, FlexibleInstances, MultiParamTypeClasses #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  Program.Reactions.GeometryChanges
-- Copyright   :  (c) Artem Chirkin
-- License     :  BSD3
--
-- Maintainer  :  Artem Chirkin <chirkin@arch.ethz.ch>
-- Stability   :  experimental
--
--
--
-----------------------------------------------------------------------------

module Program.Reactions.GeometryChanges () where

--import Geometry.Space
--import Geometry.Space.Transform
--import Geometry.Math
--import GHCJS.Marshal
import GHCJS.Useful

import Reactive
import Controllers.GUIEvents
--import Controllers.LuciClient

import Program
import Program.Model.City
import Program.Model.CityObject
--import Program.Model.GeoJSON
import Program.View

import Data.Geometry
import Data.Geometry.Transform
import Data.Geometry.Structure.PointSet
--import Debug.Trace
--import Geometry.Structure
--import Control.Monad

import GHCJS.Foreign.Callback
import GHCJS.Types
import GHCJS.Prim
import Data.Coerce

import Unsafe.Coerce

--updateProgramView :: String -> Program -> PView -> IO (Either PView e)
--updateProgramView msg program pview = do
--        getElementById "clearbutton" >>= elementParent >>= hideElement
--        cityView' <- updateView (glctx $ context pview) (city program) (cityView pview)
--        logText msg
--        return $ Left pview{cityView = cityView', scUpToDate = False}

instance Reaction Program PView ClearingGeometry "Clearing City Geometry" 0 where
--    react _ ClearingGeometry program = program
--        { city = clearCity (city program)
--        , controls = (controls program){placeTransform = Nothing}
--        }
--    response _ _ _ = updateProgramView "Cleared geometry."


instance Reaction Program PView GeoJSONLoaded "Updating City Geometry after GeoJSON is loaded" 0 where
    react _ GeoJSONLoaded
        { isDynamic = dyn
        , featureCollection = col }
        program@Program{city = ci} = if isEmptyCity ci
            then program {city = snd $ buildCity 3 200 col}
            else program
    response _ GeoJSONLoaded
        { isDynamic = dyn
        , featureCollection = col } _ prog view = do
            print "Starting response"
            printVal (unsafeCoerce .  objectsIn $ city prog)
            cview <- createView (glctx $ context view) (city prog)
            print "Finishing response"
--            let (errors, city) = buildCity 3 200 col
--            let (scale,shift) = scenarioViewScaling 200 col
--                (errors, cityObjs) = processScenario 3 scale shift col
--            mapM_ print errors
--            printVal $ unsafeCoerce (objectsIn city)
            return $ Left view{cityView = cview}
--    react _ geoJSONI program@Program{controls = c@Controls{placeTransform = Nothing}}
--        = program{controls = c{placeTransform = Just (scal, shift)}}
--        { city = addCityStaticWires lns $ addCityObjects geoms (city program)
--        }
--        where ((geoms, lns),_msgs,scal,shift) = featureCollectionToObjectsAndScale
--                    behav (featureCollection geoJSONI) -- TODO: how to log this?
--              behav = if isDynamic geoJSONI then Dynamic else Static
--    react _ geoJSONI program@Program{controls = Controls{placeTransform = Just (scal, shift)}}
--        = program
--        { city = addCityStaticWires lns $ addCityObjects geoms (city program)
--        }
--        where ((geoms, lns),_msgs) = featureCollectionToObjects
--                    behav scal shift (featureCollection geoJSONI) -- TODO: how to log this?
--              behav = if isDynamic geoJSONI then Dynamic else Static
--    response _ _ _ = updateProgramView "Updated geometry."


--mapJSArray :: (Coercible a JSVal, Coercible b JSVal)
--           => (a -> Either JSString b) -> JSVal -> IO (JSVal,JSVal)
--mapJSArray f arr = do
--    call <- syncCallback1' $ \jsx ->
--        case f (coerce jsx) of
--            Right v  -> setRight (coerce v)
--            Left str -> setLeft str
--    rez <- mapJSArray' call arr
--    releaseCallback call
--    return rez
--
--{-# INLINE setLeft #-}
--foreign import javascript unsafe "[false, $1]"
--    setLeft :: JSString -> IO JSVal
--{-# INLINE setRight #-}
--foreign import javascript unsafe "[true, $1]"
--    setRight :: JSVal -> IO JSVal
--
--{-# INLINE mapJSArray' #-}
--foreign import javascript unsafe "var rez = $2.map(function(e){ return $1(e);});\
--                                 \$r1 = rez.filter(function(e){return !e[0];}).map(function(e){ return e[1];});\
--                                 \$r2 = rez.filter(function(e){return e[0];}).map(function(e){ return e[1];});"
--    mapJSArray' :: (Callback (JSVal -> IO JSVal)) -> JSVal -> IO (JSVal, JSVal)