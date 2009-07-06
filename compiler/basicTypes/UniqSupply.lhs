%
% (c) The University of Glasgow 2006
% (c) The GRASP/AQUA Project, Glasgow University, 1992-1998
%

\begin{code}
module UniqSupply (
        -- * Main data type
        UniqSupply, -- Abstractly

        -- ** Operations on supplies 
        uniqFromSupply, uniqsFromSupply, -- basic ops
        
        mkSplitUniqSupply,
        splitUniqSupply, listSplitUniqSupply,

        -- * Unique supply monad and its abstraction
        UniqSM, MonadUnique(..),
        
        -- ** Operations on the monad
        initUs, initUs_,
        lazyThenUs, lazyMapUs,

        -- ** Deprecated operations on 'UniqSM'
        getUniqueUs, getUs, returnUs, thenUs, mapUs
  ) where

import Unique
import FastTypes

import MonadUtils
import Control.Monad
#if __GLASGOW_HASKELL__ >= 611
import GHC.IO (unsafeDupableInterleaveIO)
#else
import GHC.IOBase (unsafeDupableInterleaveIO)
#endif

\end{code}

%************************************************************************
%*                                                                      *
\subsection{Splittable Unique supply: @UniqSupply@}
%*                                                                      *
%************************************************************************

\begin{code}
-- | A value of type 'UniqSupply' is unique, and it can
-- supply /one/ distinct 'Unique'.  Also, from the supply, one can
-- also manufacture an arbitrary number of further 'UniqueSupply' values,
-- which will be distinct from the first and from all others.
data UniqSupply
  = MkSplitUniqSupply FastInt   -- make the Unique with this
                   UniqSupply UniqSupply
                                -- when split => these two supplies
\end{code}

\begin{code}
mkSplitUniqSupply :: Char -> IO UniqSupply
-- ^ Create a unique supply out of thin air. The character given must
-- be distinct from those of all calls to this function in the compiler
-- for the values generated to be truly unique.

splitUniqSupply :: UniqSupply -> (UniqSupply, UniqSupply)
-- ^ Build two 'UniqSupply' from a single one, each of which
-- can supply its own 'Unique'.
listSplitUniqSupply :: UniqSupply -> [UniqSupply]
-- ^ Create an infinite list of 'UniqSupply' from a single one
uniqFromSupply  :: UniqSupply -> Unique
-- ^ Obtain the 'Unique' from this particular 'UniqSupply'
uniqsFromSupply :: UniqSupply -> [Unique] -- Infinite
-- ^ Obtain an infinite list of 'Unique' that can be generated by constant splitting of the supply
\end{code}

\begin{code}
mkSplitUniqSupply c
  = case fastOrd (cUnbox c) `shiftLFastInt` _ILIT(24) of
     mask -> let
        -- here comes THE MAGIC:

        -- This is one of the most hammered bits in the whole compiler
        mk_supply
          = unsafeDupableInterleaveIO (
                genSymZh    >>= \ u_ -> case iUnbox u_ of { u -> (
                mk_supply   >>= \ s1 ->
                mk_supply   >>= \ s2 ->
                return (MkSplitUniqSupply (mask `bitOrFastInt` u) s1 s2)
            )})
       in
       mk_supply

foreign import ccall unsafe "genSymZh" genSymZh :: IO Int

splitUniqSupply (MkSplitUniqSupply _ s1 s2) = (s1, s2)
listSplitUniqSupply  (MkSplitUniqSupply _ s1 s2) = s1 : listSplitUniqSupply s2
\end{code}

\begin{code}
uniqFromSupply  (MkSplitUniqSupply n _ _)  = mkUniqueGrimily (iBox n)
uniqsFromSupply (MkSplitUniqSupply n _ s2) = mkUniqueGrimily (iBox n) : uniqsFromSupply s2
\end{code}

%************************************************************************
%*                                                                      *
\subsubsection[UniqSupply-monad]{@UniqSupply@ monad: @UniqSM@}
%*                                                                      *
%************************************************************************

\begin{code}
-- | A monad which just gives the ability to obtain 'Unique's
newtype UniqSM result = USM { unUSM :: UniqSupply -> (result, UniqSupply) }

instance Monad UniqSM where
  return = returnUs
  (>>=) = thenUs
  (>>)  = thenUs_

instance Functor UniqSM where
    fmap f (USM x) = USM (\us -> case x us of
                                 (r, us') -> (f r, us'))

instance Applicative UniqSM where
    pure = returnUs
    (USM f) <*> (USM x) = USM $ \us -> case f us of
                            (ff, us')  -> case x us' of
                              (xx, us'') -> (ff xx, us'')

-- | Run the 'UniqSM' action, returning the final 'UniqSupply'
initUs :: UniqSupply -> UniqSM a -> (a, UniqSupply)
initUs init_us m = case unUSM m init_us of { (r,us) -> (r,us) }

-- | Run the 'UniqSM' action, discarding the final 'UniqSupply'
initUs_ :: UniqSupply -> UniqSM a -> a
initUs_ init_us m = case unUSM m init_us of { (r, _) -> r }

{-# INLINE thenUs #-}
{-# INLINE lazyThenUs #-}
{-# INLINE returnUs #-}
{-# INLINE splitUniqSupply #-}
\end{code}

@thenUs@ is where we split the @UniqSupply@.
\begin{code}
instance MonadFix UniqSM where
    mfix m = USM (\us -> let (r,us') = unUSM (m r) us in (r,us'))

thenUs :: UniqSM a -> (a -> UniqSM b) -> UniqSM b
thenUs (USM expr) cont
  = USM (\us -> case (expr us) of
                   (result, us') -> unUSM (cont result) us')

lazyThenUs :: UniqSM a -> (a -> UniqSM b) -> UniqSM b
lazyThenUs (USM expr) cont
  = USM (\us -> let (result, us') = expr us in unUSM (cont result) us')

thenUs_ :: UniqSM a -> UniqSM b -> UniqSM b
thenUs_ (USM expr) (USM cont)
  = USM (\us -> case (expr us) of { (_, us') -> cont us' })

returnUs :: a -> UniqSM a
returnUs result = USM (\us -> (result, us))

getUs :: UniqSM UniqSupply
getUs = USM (\us -> splitUniqSupply us)

-- | A monad for generating unique identifiers
class Monad m => MonadUnique m where
    -- | Get a new UniqueSupply
    getUniqueSupplyM :: m UniqSupply
    -- | Get a new unique identifier
    getUniqueM  :: m Unique
    -- | Get an infinite list of new unique identifiers
    getUniquesM :: m [Unique]

    getUniqueM  = liftM uniqFromSupply  getUniqueSupplyM
    getUniquesM = liftM uniqsFromSupply getUniqueSupplyM

instance MonadUnique UniqSM where
    getUniqueSupplyM = USM (\us -> splitUniqSupply us)
    getUniqueM  = getUniqueUs
    getUniquesM = getUniquesUs

getUniqueUs :: UniqSM Unique
getUniqueUs = USM (\us -> case splitUniqSupply us of
                          (us1,us2) -> (uniqFromSupply us1, us2))

getUniquesUs :: UniqSM [Unique]
getUniquesUs = USM (\us -> case splitUniqSupply us of
                           (us1,us2) -> (uniqsFromSupply us1, us2))

mapUs :: (a -> UniqSM b) -> [a] -> UniqSM [b]
mapUs _ []     = returnUs []
mapUs f (x:xs)
  = f x         `thenUs` \ r  ->
    mapUs f xs  `thenUs` \ rs ->
    returnUs (r:rs)
\end{code}

\begin{code}
-- {-# SPECIALIZE mapM          :: (a -> UniqSM b) -> [a] -> UniqSM [b] #-}
-- {-# SPECIALIZE mapAndUnzipM  :: (a -> UniqSM (b,c))   -> [a] -> UniqSM ([b],[c]) #-}
-- {-# SPECIALIZE mapAndUnzip3M :: (a -> UniqSM (b,c,d)) -> [a] -> UniqSM ([b],[c],[d]) #-}

lazyMapUs :: (a -> UniqSM b) -> [a] -> UniqSM [b]
lazyMapUs _ []     = returnUs []
lazyMapUs f (x:xs)
  = f x             `lazyThenUs` \ r  ->
    lazyMapUs f xs  `lazyThenUs` \ rs ->
    returnUs (r:rs)
\end{code}
