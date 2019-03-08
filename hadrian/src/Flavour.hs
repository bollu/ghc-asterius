module Flavour
  ( Flavour (..), werror
  , DocTargets, DocTarget(..)
  ) where

import Expression
import Data.Set (Set)

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
