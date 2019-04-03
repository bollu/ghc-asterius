module Main (main) where

import System.Directory (getCurrentDirectory)
import Development.Shake
import Hadrian.Expression
import Hadrian.Utilities

import qualified Base
import qualified CommandLine
import qualified Environment
import qualified Rules
import qualified Rules.Clean
import qualified Rules.Documentation
import qualified Rules.Nofib
import qualified Rules.SourceDist
import qualified Rules.Selftest
import qualified Rules.Test
import qualified UserSettings

main :: IO ()
main = do
    -- Provide access to command line arguments and some user settings through
    -- Shake's type-indexed map 'shakeExtra'.
    argsMap <- CommandLine.cmdLineArgsMap
    let extra = insertExtra UserSettings.buildProgressColour
              $ insertExtra UserSettings.successColour
              $ insertExtra (VerboseCommand UserSettings.verboseCommand) argsMap

        BuildRoot buildRoot = CommandLine.lookupBuildRoot argsMap

        rebuild = [ (RebuildLater, buildRoot -/- "stage0//*")
                  | CommandLine.lookupFreeze1 argsMap ]

    cwd <- getCurrentDirectory
    let options :: ShakeOptions
        options = shakeOptions
            { shakeChange   = ChangeModtimeAndDigest
            , shakeFiles    = buildRoot -/- Base.shakeFilesDir
            , shakeProgress = progressSimple
            , shakeRebuild  = rebuild
            , shakeTimings  = True
            , shakeExtra    = extra

            -- Enable linting file accesses in the build dir and ghc root dir
            -- (cwd) when using the `--lint-fsatrace` option.
            , shakeLintInside = [ cwd, buildRoot ]
            , shakeLintIgnore =
                -- Ignore access to the package database caches.
                -- They are managed externally by the ghc-pkg tool.
                [ buildRoot -/- "//package.conf.d/package.cache"

                -- Ignore access to autom4te.cache directories.
                -- They are managed externally by auto tools.
                , "//autom4te.cache//*"
                ]
            }

        rules :: Rules ()
        rules = do
            Rules.buildRules
            Rules.Documentation.documentationRules
            Rules.Clean.cleanRules
            Rules.Nofib.nofibRules
            Rules.oracleRules
            Rules.Selftest.selftestRules
            Rules.SourceDist.sourceDistRules
            Rules.Test.testRules
            Rules.topLevelTargets
            Rules.toolArgsTarget

    shakeArgsWith options CommandLine.optDescrs $ \_ targets -> do
        Environment.setupEnvironment
        return . Just $ if null targets
                        then rules
                        else want targets >> withoutActions rules
