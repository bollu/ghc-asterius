module Settings.Flavours.Development (developmentFlavour) where

import Expression
import Flavour
import {-# SOURCE #-} Settings.Default

-- Please update doc/flavours.md when changing this file.
developmentFlavour :: Stage -> Flavour
developmentFlavour ghcStage = defaultFlavour
    { name = "devel" ++ show (fromEnum ghcStage)
    , args = defaultBuilderArgs <> developmentArgs ghcStage <> defaultPackageArgs
    , libraryWays = pure [vanilla]
    , rtsWays = pure [vanilla, threaded]
    , dynamicGhcPrograms = return False }

developmentArgs :: Stage -> Args
developmentArgs ghcStage = do
    stage <- getStage
    sourceArgs SourceArgs
        { hsDefault  = pure ["-O", "-H64m"]
        , hsLibrary  = notStage0 ? arg "-dcore-lint"
        , hsCompiler = mconcat [stage0 ? arg "-O2",
                                succ stage == ghcStage ? pure ["-O0", "-DDEBUG"]]
        , hsGhc      = succ stage == ghcStage ? pure ["-O0", "-DDEBUG"] }
