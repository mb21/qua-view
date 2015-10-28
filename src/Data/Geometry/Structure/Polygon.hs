{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE DataKinds, KindSignatures, GHCForeignImportPrim #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  Data.Geometry.Structure.Polygon
-- Copyright   :  (c) Artem Chirkin
-- License     :  BSD3
--
-- Maintainer  :  Artem Chirkin <chirkin@arch.ethz.ch>
-- Stability   :  experimental
-- Portability :
--
--
-----------------------------------------------------------------------------

module Data.Geometry.Structure.Polygon
    ( Polygon ()
    , polygon, numRings, index, rings
    , triangulate, triangulate'
    ) where

import Prelude hiding (length)

import GHC.Exts (Any)
import Unsafe.Coerce (unsafeCoerce)
import GHC.TypeLits

import GHCJS.Types
import GHCJS.Marshal.Pure (PFromJSVal(..))

import Data.Geometry
import qualified Data.Geometry.Structure.PointSet as PS
import Data.Geometry.Structure.LinearRing (LinearRing)
--import qualified Data.Geometry.Structure.LinearRing as LRing

-- | GeoJSON LinearRing
newtype Polygon (n::Nat) x = Polygon JSVal
instance IsJSVal (Polygon n x)
instance PFromJSVal (Polygon n x) where
    pFromJSVal = Polygon

instance PS.PointSet (Polygon n x) n x where
    {-# INLINE flatten #-}
    flatten = PS.flatten . js_PtoPA
    {-# INLINE toPointArray #-}
    toPointArray = js_PtoPA
    {-# INLINE fromPointArray #-}
    fromPointArray = polygon .  (:[]) . PS.fromPointArray
    {-# INLINE mean #-}
    mean = PS.mean . js_PtoPA
    {-# INLINE var #-}
    var = PS.var . js_PtoPA


-- | Create a Polygon
polygon :: [LinearRing n x] -- ^ All remaining points (without duplicate of the first one)
           -> Polygon n x
polygon xs = js_createPolygon  . unsafeCoerce . seqList $ xs

-- | Get list of points from Polygon (without repeatative last point)
rings :: Polygon n x -> [LinearRing n x]
rings = unsafeCoerce . js_PtoLRList

triangulate :: (KnownNat n, Fractional x, JSNum x) => Polygon n x -> [Int]
triangulate = unsafeCoerce .  js_indicesListPrim . triangulate'

triangulate' :: (KnownNat n, Fractional x, JSNum x) => Polygon n x -> JSVal
triangulate' poly = triangulate'' projset rinds
    where set = PS.toPointArray poly
          rinds = js_ringIndices poly
          v = PS.pcaVectors set
          projset = PS.projectND v set

triangulate'' :: PS.PointArray 2 x -> JSVal -> JSVal
triangulate'' set rinds = js_triangulate (PS.flatten set) rinds


{-# INLINE numRings #-}
foreign import javascript unsafe "$1['coordinates'].length"
    numRings :: Polygon n x -> Int

{-# INLINE index #-}
foreign import javascript unsafe "$2['coordinates'][$1]"
    index :: Int -> Polygon n x -> LinearRing n x


{-# INLINE js_createPolygon #-}
foreign import javascript unsafe "$r = {}; $r['type'] = 'Polygon'; $r['coordinates'] = h$listToArray($1);"
    js_createPolygon :: Any -> Polygon n x

{-# INLINE js_PtoLRList #-}
foreign import javascript unsafe "h$toHsListJSVal($1['coordinates'])"
    js_PtoLRList:: Polygon n x -> Any

{-# INLINE js_PtoPA #-}
foreign import javascript unsafe "[].concat.apply([], $1['coordinates'].map(function(a){return a.slice(0,a.length-1);}))"
    js_PtoPA :: Polygon n x -> PS.PointArray n x

{-# INLINE js_ringIndices #-}
foreign import javascript unsafe "$1['coordinates'].slice(0,$1['coordinates'].length-1)\
                                        \.reduce(function(r,e){return r.concat([e.length-1]);},[])"
    js_ringIndices :: Polygon n x -> JSVal

{-# INLINE js_triangulate #-}
foreign import javascript unsafe "earcut($1,$2)"
    js_triangulate :: JSVal -> JSVal -> JSVal

{-# INLINE js_indicesListPrim #-}
foreign import javascript unsafe "h$fromArrayNoWrap($1)"
    js_indicesListPrim:: JSVal -> Any

seqList :: [a] -> [a]
seqList xs = foldr seq () xs `seq` xs
