{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE DataKinds, KindSignatures, GHCForeignImportPrim #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  Data.Geometry.Structure.LinearRing
-- Copyright   :  (c) Artem Chirkin
-- License     :  BSD3
--
-- Maintainer  :  Artem Chirkin <chirkin@arch.ethz.ch>
-- Stability   :  experimental
--
--
-----------------------------------------------------------------------------

module Data.Geometry.Structure.LinearRing
    ( LinearRing ()
    , linearRing, length, index, toList
    ) where

import Prelude hiding (length)

import GHC.Exts (Any)
import Unsafe.Coerce (unsafeCoerce)
import GHC.TypeLits

import GHCJS.Types
import GHCJS.Marshal.Pure (PFromJSVal(..))

import Data.Geometry
import qualified Data.Geometry.Structure.PointSet as PS

-- | GeoJSON LinearRing
newtype LinearRing (n::Nat) x = LinearRing JSVal
instance IsJSVal (LinearRing n x)
instance PFromJSVal (LinearRing n x) where
    pFromJSVal = LinearRing

instance PS.PointSet (LinearRing n x) n x where
    {-# INLINE flatten #-}
    flatten = PS.flatten . js_LRtoPA
    {-# INLINE toPointArray #-}
    toPointArray = js_LRtoPA
    {-# INLINE fromPointArray #-}
    fromPointArray = js_PAtoLR
    {-# INLINE mean #-}
    mean = PS.mean . js_LRtoPA
    {-# INLINE var #-}
    var = PS.var . js_LRtoPA


-- | Create a LinearRing
linearRing :: Vector n x -- ^ First (and last) point of the LinearRing
           -> Vector n x -- ^ Second point
           -> Vector n x -- ^ Third point
           -> [Vector n x] -- ^ All remaining points (without duplicate of the first one)
           -> LinearRing n x
linearRing a b c xs = js_createLinearRing  . unsafeCoerce . seqList $ a:b:c:xs

-- | Get list of points from LinearRing (without repeatative last point)
toList :: LinearRing n x -> [Vector n x]
toList = unsafeCoerce . js_LRtoList


{-# INLINE length #-}
foreign import javascript unsafe "$1.length - 1"
    length :: LinearRing n x -> Int

{-# INLINE index #-}
foreign import javascript unsafe "$2[$1]"
    index :: Int -> LinearRing n x -> Vector n x


{-# INLINE js_createLinearRing #-}
foreign import javascript unsafe "$r = h$listToArray($1); $r.push($r[0]);"
    js_createLinearRing :: Any -> LinearRing n x

{-# INLINE js_LRtoList #-}
foreign import javascript unsafe "h$toHsListJSVal($1.slice(0,$1.length-1))"
    js_LRtoList:: LinearRing n x -> Any

{-# INLINE js_LRtoPA #-}
foreign import javascript unsafe "$1.slice(0,$1.length-1)"
    js_LRtoPA :: LinearRing n x -> PS.PointArray n x

{-# INLINE js_PAtoLR #-}
foreign import javascript unsafe "$r = Array.from($1); $r.push($1[0]);"
    js_PAtoLR :: PS.PointArray n x -> LinearRing n x

seqList :: [a] -> [a]
seqList xs = foldr seq () xs `seq` xs
