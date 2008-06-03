{-# OPTIONS_GHC -fglasgow-exts -fallow-undecidable-instances #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  Data.Packed.Internal.Vector
-- Copyright   :  (c) Alberto Ruiz 2007
-- License     :  GPL-style
--
-- Maintainer  :  Alberto Ruiz <aruiz@um.es>
-- Stability   :  provisional
-- Portability :  portable (uses FFI)
--
-- Vector implementation
--
-----------------------------------------------------------------------------
-- #hide

module Data.Packed.Internal.Vector where

import Data.Packed.Internal.Common
import Foreign
import Complex
import Control.Monad(when)

-- | A one-dimensional array of objects stored in a contiguous memory block.
data Vector t = V { dim  :: Int              -- ^ number of elements
                  , fptr :: ForeignPtr t     -- ^ foreign pointer to the memory block
                  }

vec = withVector

withVector (V n fp) f = withForeignPtr fp $ \p -> do
    let v g = do
        g (fi n) p
    f v

-- | allocates memory for a new vector
createVector :: Storable a => Int -> IO (Vector a)
createVector n = do
    when (n <= 0) $ error ("trying to createVector of dim "++show n)
    fp <- mallocForeignPtrArray n
    return $ V n fp

{- | creates a Vector from a list:

@> fromList [2,3,5,7]
4 |> [2.0,3.0,5.0,7.0]@

-}
fromList :: Storable a => [a] -> Vector a
fromList l = unsafePerformIO $ do
    v <- createVector (length l)
    let f _ p = pokeArray p l >> return 0
    app1 f vec v "fromList"
    return v

safeRead v = unsafePerformIO . withForeignPtr (fptr v)

{- | extracts the Vector elements to a list

@> toList (linspace 5 (1,10))
[1.0,3.25,5.5,7.75,10.0]@

-}
toList :: Storable a => Vector a -> [a]
toList v = safeRead v $ peekArray (dim v)

-- | an alternative to 'fromList' with explicit dimension, used also in the instances for Show (Vector a).
(|>) :: (Storable a) => Int -> [a] -> Vector a
infixl 9 |>
n |> l = if length l == n then fromList l else error "|> with wrong size"

-- | access to Vector elements without range checking
at' :: Storable a => Vector a -> Int -> a
at' v n = safeRead v $ flip peekElemOff n

-- | access to Vector elements with range checking.
at :: Storable a => Vector a -> Int -> a
at v n | n >= 0 && n < dim v = at' v n
       | otherwise          = error "vector index out of range"

{- | takes a number of consecutive elements from a Vector

@> subVector 2 3 (fromList [1..10])
3 |> [3.0,4.0,5.0]@

-}
subVector :: Storable t => Int       -- ^ index of the starting element
                        -> Int       -- ^ number of elements to extract
                        -> Vector t  -- ^ source
                        -> Vector t  -- ^ result
subVector k l (v@V {dim=n})
    | k<0 || k >= n || k+l > n || l < 0 = error "subVector out of range"
    | otherwise = unsafePerformIO $ do
        r <- createVector l
        let f _ s _ d = copyArray d (advancePtr s k) l >> return 0
        app2 f vec v vec r "subVector"
        return r

{- | Reads a vector position:

@> fromList [0..9] \@\> 7
7.0@

-}
(@>) :: Storable t => Vector t -> Int -> t
infixl 9 @>
(@>) = at


{- | creates a new Vector by joining a list of Vectors

@> join [fromList [1..5], constant 1 3]
8 |> [1.0,2.0,3.0,4.0,5.0,1.0,1.0,1.0]@

-}
join :: Storable t => [Vector t] -> Vector t
join [] = error "joining zero vectors"
join as = unsafePerformIO $ do
    let tot = sum (map dim as)
    r@V {fptr = p} <- createVector tot
    withForeignPtr p $ \ptr ->
        joiner as tot ptr
    return r
  where joiner [] _ _ = return ()
        joiner (V {dim = n, fptr = b} : cs) _ p = do
            withForeignPtr b $ \pb -> copyArray p pb n
            joiner cs 0 (advancePtr p n)


-- | transforms a complex vector into a real vector with alternating real and imaginary parts 
asReal :: Vector (Complex Double) -> Vector Double
asReal v = V { dim = 2*dim v, fptr =  castForeignPtr (fptr v) }

-- | transforms a real vector into a complex vector with alternating real and imaginary parts
asComplex :: Vector Double -> Vector (Complex Double)
asComplex v = V { dim = dim v `div` 2, fptr =  castForeignPtr (fptr v) }

----------------------------------------------------------------

-- | map on Vectors
liftVector :: (Storable a, Storable b) => (a-> b) -> Vector a -> Vector b
liftVector  f = fromList . map f . toList

-- | zipWith for Vectors
liftVector2 :: (Storable a, Storable b, Storable c) => (a-> b -> c) -> Vector a -> Vector b -> Vector c
liftVector2 f u v = fromList $ zipWith f (toList u) (toList v)

-----------------------------------------------------------------

{- | creates a new vector with a desired position updated with a modification function

@> updateVector 3 (+7) (fromList [1..5])
5 |> [1.0,2.0,3.0,11.0,5.0]@

-}
updateVector :: Storable t => Int       -- ^ position
                           -> (t->t)    -- ^ modification function
                           -> Vector t  -- ^ source
                           -> Vector t  -- ^ result
updateVector k h (v@V {dim=n})
    | k<0 || k >= n = error $ "updateVector out of range (dim="++show n++", pos="++show k++")"
    | otherwise = unsafePerformIO $ do
        r <- createVector n
        let f _ s _ d =  copyArray d s n
                      >> pokeElemOff d k (h (v`at'`k))
                      >> return 0
        app2 f vec v vec r "updateVector"
        return r

-----------------------------------------------------------------

cloneVector :: Storable t => Vector t -> IO (Vector t)
cloneVector (v@V {dim=n}) = do
        r <- createVector n
        let f _ s _ d =  copyArray d s n >> return 0
        app2 f vec v vec r "cloneVector"
        return r
