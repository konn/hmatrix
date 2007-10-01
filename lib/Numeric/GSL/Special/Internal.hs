{-# OPTIONS #-}
-----------------------------------------------------------------------------
{- |
Module      :  Numeric.GSL.Special.Internal
Copyright   :  (c) Alberto Ruiz 2007
License     :  GPL-style

Maintainer  :  Alberto Ruiz (aruiz at um dot es)
Stability   :  provisional
Portability :  uses ffi

Support for Special functions.

<http://www.gnu.org/software/gsl/manual/html_node/Special-Functions.html#Special-Functions>
-}
-----------------------------------------------------------------------------

module Numeric.GSL.Special.Internal (
    createSFR,
    createSFR_E10,
    Precision(..),
    Gsl_mode_t,
    Size_t,
    precCode
)
where

import Foreign
import Data.Packed.Internal(check,(//))


data Precision = PrecDouble | PrecSingle | PrecApprox

precCode :: Precision -> Int
precCode PrecDouble = 0
precCode PrecSingle = 1
precCode PrecApprox = 2

type Gsl_mode_t = Int

type Size_t = Int

----------------------------------------------------------------
-- | access to a sf_result
createSFR :: Storable a => String -> (Ptr a -> IO Int) -> (a, a)
createSFR s f = unsafePerformIO $ do
    p <- mallocArray 2
    f p // check s []
    [val,err] <- peekArray 2 p
    free p
    return (val,err)


---------------------------------------------------------------------
-- the sf_result_e10 contains two doubles and the exponent

-- | acces to sf_result_e10
createSFR_E10 :: (Storable t2, Storable t3, Storable t1) => String -> (Ptr a -> IO Int) -> (t1, t2, t3)
createSFR_E10 s f = unsafePerformIO $ do
    let sd = sizeOf (0::Double)
    let si = sizeOf (0::Int)
    p <- mallocBytes (2*sd + si)
    f p // check s []
    val <- peekByteOff p 0
    err <- peekByteOff p sd
    expo <- peekByteOff p (2*sd) 
    free p
    return (val,expo,err)