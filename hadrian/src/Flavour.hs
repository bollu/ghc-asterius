module Flavour
  ( Flavour (..), werror
  , DocTargets, DocTarget(..)
  , splitSections, splitSectionsIf
  ) where

import Expression
import Data.Set (Set)
import Packages

-- Please update doc/{flavours.md, user-settings.md} when changing this file.
-- | 'Flavour' is a collection of build settings that fully define a GHC build.
-- Note the following type semantics:
-- * @Bool@: a plain Boolean flag whose value is known at compile time.
-- * @Action Bool@: a flag whose value can depend on the build environment.
-- * @Predicate@: a flag whose value can depend on the build environment and
-- on the current build target.
data Flavour = Flavour {
    -- | Flavour name, to select this flavour from command line.
    name :: String,
    -- | Use these command line arguments.
    args :: Args,
    -- | Build these packages.
    packages :: Stage -> Action [Package],
    -- | Either 'integerGmp' or 'integerSimple'.
    integerLibrary :: Action Package,
    -- | Build libraries these ways.
    libraryWays :: Ways,
    -- | Build RTS these ways.
    rtsWays :: Ways,
    -- | Build dynamic GHC programs.
    dynamicGhcPrograms :: Action Bool,
    -- | Enable GHCi debugger.
    ghciWithDebugger :: Bool,
    -- | Build profiled GHC.
    ghcProfiled :: Bool,
    -- | Build GHC with debug information.
    ghcDebugged :: Bool,
    -- | Whether to build docs and which ones
    --   (haddocks, user manual, haddock manual)
    ghcDocs :: Action DocTargets }

-- | A set of documentation targets
type DocTargets = Set DocTarget

-- | Documentation targets
--
--   While we can't reasonably expose settings or CLI options
--   to selectively disable, say, base's haddocks, we can offer
--   a less fine-grained choice:
--
--   - haddocks for libraries
--   - non-haddock html pages (e.g GHC's user manual)
--   - PDF documents (e.g haddock's manual)
--   - man pages (GHC's)
--
--   The main goal being to have easy ways to do away with the need
--   for e.g @sphinx-build@ or @xelatex@ and associated packages
--   while still being able to build a(n almost) complete binary
--   distribution.
data DocTarget = Haddocks | SphinxHTML | SphinxPDFs | SphinxMan
  deriving (Eq, Ord, Show, Bounded, Enum)

-- | Turn on -Werror for packages built with the stage1 compiler.
-- It mimics the CI settings so is useful to turn on when developing.
werror :: Flavour -> Flavour
werror fl = fl { args = args fl <> (builder Ghc ? notStage0 ? arg "-Werror") }

-- | Transform the input 'Flavour' so as to build with
--   @-split-sections@ whenever appropriate. You can
--   select which package gets built with split sections
--   by passing a suitable predicate. If the predicate holds
--   for a given package, then @split-sections@ is used when
--   building it. If the given flavour doesn't build
--   anything in a @dyn@-enabled way, then 'splitSections' is a no-op.
splitSectionsIf :: (Package -> Bool) -> Flavour -> Flavour
splitSectionsIf pkgPredicate fl = fl { args = args fl <> splitSectionsArg }

  where splitSectionsArg = do
          way <- getWay
          pkg <- getPackage
          (Dynamic `wayUnit` way) ? pkgPredicate pkg ?
            builder (Ghc CompileHs) ? arg "-split-sections"

-- | Like 'splitSectionsIf', but with a fixed predicate: use
--   split sections for all packages but the GHC library.
splitSections :: Flavour -> Flavour
splitSections = splitSectionsIf (/=ghc)
-- Disable section splitting for the GHC library. It takes too long and
-- there is little benefit.
