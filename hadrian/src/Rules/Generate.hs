module Rules.Generate (
    isGeneratedCmmFile, compilerDependencies, generatePackageCode,
    generateRules, copyRules, generatedDependencies, generatedGhcDependencies,
    ghcPrimDependencies
    ) where

import Base
import Expression
import Flavour
import Oracles.Flag
import Oracles.ModuleFiles
import Oracles.Setting
import Packages
import Rules.Gmp
import Rules.Libffi
import Settings
import Target
import Utilities

-- | Track this file to rebuild generated files whenever it changes.
trackGenerateHs :: Expr ()
trackGenerateHs = expr $ need [sourcePath -/- "Rules/Generate.hs"]

primopsSource :: FilePath
primopsSource = "compiler/prelude/primops.txt.pp"

primopsTxt :: Stage -> FilePath
primopsTxt stage = buildDir (vanillaContext stage compiler) -/- "primops.txt"

isGeneratedCmmFile :: FilePath -> Bool
isGeneratedCmmFile file = takeBaseName file == "AutoApply"

ghcPrimDependencies :: Expr [FilePath]
ghcPrimDependencies = do
    stage <- getStage
    path  <- expr $ buildPath (vanillaContext stage ghcPrim)
    return [path -/- "GHC/Prim.hs", path -/- "GHC/PrimopWrappers.hs"]

derivedConstantsDependencies :: [FilePath]
derivedConstantsDependencies = fmap (generatedDir -/-)
    [ "DerivedConstants.h"
    , "GHCConstantsHaskellExports.hs"
    , "GHCConstantsHaskellType.hs"
    , "GHCConstantsHaskellWrappers.hs" ]

compilerDependencies :: Expr [FilePath]
compilerDependencies = do
    root    <- getBuildRoot
    stage   <- getStage
    isGmp   <- (== integerGmp) <$> getIntegerPackage
    ghcPath <- expr $ buildPath (vanillaContext stage compiler)
    gmpPath <- expr gmpBuildPath
    rtsPath <- expr (rtsBuildPath stage)
    mconcat [ return ((root -/-) <$> derivedConstantsDependencies)
            , notStage0 ? isGmp ? return [gmpPath -/- gmpLibraryH]
            , notStage0 ? return ((rtsPath -/-) <$> libffiDependencies)
            , return $ fmap (ghcPath -/-)
                  [ "primop-can-fail.hs-incl"
                  , "primop-code-size.hs-incl"
                  , "primop-commutable.hs-incl"
                  , "primop-data-decl.hs-incl"
                  , "primop-fixity.hs-incl"
                  , "primop-has-side-effects.hs-incl"
                  , "primop-list.hs-incl"
                  , "primop-out-of-line.hs-incl"
                  , "primop-primop-info.hs-incl"
                  , "primop-strictness.hs-incl"
                  , "primop-tag.hs-incl"
                  , "primop-vector-tycons.hs-incl"
                  , "primop-vector-tys-exports.hs-incl"
                  , "primop-vector-tys.hs-incl"
                  , "primop-vector-uniques.hs-incl" ] ]

generatedDependencies :: Expr [FilePath]
generatedDependencies = do
    root     <- getBuildRoot
    stage    <- getStage
    rtsPath  <- expr (rtsBuildPath stage)
    includes <- expr includesDependencies
    mconcat [ package compiler ? compilerDependencies
            , package ghcPrim  ? ghcPrimDependencies
            , package rts      ? return (fmap (rtsPath -/-) libffiDependencies
                ++ includes
                ++ fmap (root -/-) derivedConstantsDependencies)
            , stage0 ? return includes ]

generate :: FilePath -> Context -> Expr String -> Action ()
generate file context expr = do
    contents <- interpretInContext context expr
    writeFileChanged file contents
    putSuccess $ "| Successfully generated " ++ file ++ "."

generatePackageCode :: Context -> Rules ()
generatePackageCode context@(Context stage pkg _) = do
    root <- buildRootRules
    let dir         = buildDir context
        generated f = (root -/- dir ++ "//*.hs") ?== f && not ("//autogen/*" ?== f)
        go gen file = generate file context gen
    generated ?> \file -> do
        let unpack = fromMaybe . error $ "No generator for " ++ file ++ "."
        (src, builder) <- unpack <$> findGenerator context file
        need [src]
        build $ target context builder [src] [file]
        let boot = src -<.> "hs-boot"
        whenM (doesFileExist boot) $ do
            let target = file -<.> "hs-boot"
            copyFile boot target
            produces [target]

    priority 2.0 $ do
        when (pkg == compiler) $ do
            root <//> dir -/- "Config.hs" %> go generateConfigHs
            root <//> dir -/- "*.hs-incl" %> genPrimopCode context
        when (pkg == ghcPrim) $ do
            root <//> dir -/- "GHC/Prim.hs" %> genPrimopCode context
            root <//> dir -/- "GHC/PrimopWrappers.hs" %> genPrimopCode context
        when (pkg == ghcPkg) $
            root <//> dir -/- "Version.hs" %> go generateVersionHs

    when (pkg == compiler) $ do
        root -/- primopsTxt stage %> \file -> do
            includes <- includesDependencies
            need $ [primopsSource] ++ includes
            build $ target context HsCpp [primopsSource] [file]

        root -/- stageString stage <//> "ghc_boot_platform.h" %>
            go generateGhcBootPlatformH

    when (pkg == rts) $ do
        root <//> dir -/- "cmm/AutoApply.cmm" %> \file ->
            build $ target context GenApply [] [file]
        -- TODO: This should be fixed properly, e.g. generated here on demand.
        (root <//> dir -/- "DerivedConstants.h") <~ (buildRoot <&> (-/- generatedDir))
        (root <//> dir -/- "ghcautoconf.h") <~ (buildRoot <&> (-/- generatedDir))
        (root <//> dir -/- "ghcplatform.h") <~ (buildRoot <&> (-/- generatedDir))
        (root <//> dir -/- "ghcversion.h") <~ (buildRoot <&> (-/- generatedDir))
 where
    pattern <~ mdir = pattern %> \file -> do
        dir <- mdir
        copyFile (dir -/- takeFileName file) file

genPrimopCode :: Context -> FilePath -> Action ()
genPrimopCode context@(Context stage _pkg _) file = do
    root <- buildRoot
    need [root -/- primopsTxt stage]
    build $ target context GenPrimopCode [root -/- primopsTxt stage] [file]

copyRules :: Rules ()
copyRules = do
    root <- buildRootRules
    forM_ [Stage0 ..] $ \stage -> do
        let prefix = root -/- stageString stage -/- "lib"

            infixl 1 <~
            pattern <~ mdir = pattern %> \file -> do
                dir <- mdir
                copyFile (dir -/- makeRelative prefix file) file

        prefix -/- "ghc-usage.txt"     <~ return "driver"
        prefix -/- "ghci-usage.txt"    <~ return "driver"
        prefix -/- "llvm-targets"      <~ return "."
        prefix -/- "llvm-passes"       <~ return "."
        prefix -/- "platformConstants" <~ (buildRoot <&> (-/- generatedDir))
        prefix -/- "settings"          <~ return "."
        prefix -/- "template-hsc.h"    <~ return (pkgPath hsc2hs)

        prefix -/- "html//*"           <~ return "utils/haddock/haddock-api/resources"
        prefix -/- "latex//*"          <~ return "utils/haddock/haddock-api/resources"

generateRules :: Rules ()
generateRules = do
    root <- buildRootRules
    priority 2.0 $ (root -/- generatedDir -/- "ghcautoconf.h") <~ generateGhcAutoconfH
    priority 2.0 $ (root -/- generatedDir -/- "ghcplatform.h") <~ generateGhcPlatformH
    priority 2.0 $ (root -/- generatedDir -/-  "ghcversion.h") <~ generateGhcVersionH

    -- TODO: simplify, get rid of fake rts context
    root -/- generatedDir ++ "//*" %> \file -> do
        withTempDir $ \dir -> build $
            target (rtsContext Stage1) DeriveConstants [] [file, dir]
  where
    file <~ gen = file %> \out -> generate out emptyTarget gen

-- TODO: Use the Types, Luke! (drop partial function)
-- We sometimes need to evaluate expressions that do not require knowing all
-- information about the context. In this case, we don't want to know anything.
emptyTarget :: Context
emptyTarget = vanillaContext (error "Rules.Generate.emptyTarget: unknown stage")
                             (error "Rules.Generate.emptyTarget: unknown package")

-- Generators

-- | Given a 'String' replace charaters '.' and '-' by underscores ('_') so that
-- the resulting 'String' is a valid C preprocessor identifier.
cppify :: String -> String
cppify = replaceEq '-' '_' . replaceEq '.' '_'

-- | Generate @ghcplatform.h@ header.
generateGhcPlatformH :: Expr String
generateGhcPlatformH = do
    trackGenerateHs
    hostPlatform   <- getSetting HostPlatform
    hostArch       <- getSetting HostArch
    hostOs         <- getSetting HostOs
    hostVendor     <- getSetting HostVendor
    targetPlatform <- getSetting TargetPlatform
    targetArch     <- getSetting TargetArch
    targetOs       <- getSetting TargetOs
    targetVendor   <- getSetting TargetVendor
    ghcUnreg       <- getFlag    GhcUnregisterised
    return . unlines $
        [ "#ifndef __GHCPLATFORM_H__"
        , "#define __GHCPLATFORM_H__"
        , ""
        , "#define BuildPlatform_TYPE  " ++ cppify hostPlatform
        , "#define HostPlatform_TYPE   " ++ cppify targetPlatform
        , ""
        , "#define " ++ cppify hostPlatform   ++ "_BUILD 1"
        , "#define " ++ cppify targetPlatform ++ "_HOST 1"
        , ""
        , "#define " ++ hostArch   ++ "_BUILD_ARCH 1"
        , "#define " ++ targetArch ++ "_HOST_ARCH 1"
        , "#define BUILD_ARCH " ++ show hostArch
        , "#define HOST_ARCH "  ++ show targetArch
        , ""
        , "#define " ++ hostOs   ++ "_BUILD_OS 1"
        , "#define " ++ targetOs ++ "_HOST_OS 1"
        , "#define BUILD_OS " ++ show hostOs
        , "#define HOST_OS "  ++ show targetOs
        , ""
        , "#define " ++ hostVendor   ++ "_BUILD_VENDOR 1"
        , "#define " ++ targetVendor ++ "_HOST_VENDOR 1"
        , "#define BUILD_VENDOR " ++ show hostVendor
        , "#define HOST_VENDOR "  ++ show targetVendor
        , ""
        , "/* These TARGET macros are for backwards compatibility... DO NOT USE! */"
        , "#define TargetPlatform_TYPE " ++ cppify targetPlatform
        , "#define " ++ cppify targetPlatform ++ "_TARGET 1"
        , "#define " ++ targetArch ++ "_TARGET_ARCH 1"
        , "#define TARGET_ARCH " ++ show targetArch
        , "#define " ++ targetOs ++ "_TARGET_OS 1"
        , "#define TARGET_OS " ++ show targetOs
        , "#define " ++ targetVendor ++ "_TARGET_VENDOR 1" ]
        ++
        [ "#define UnregisterisedCompiler 1" | ghcUnreg ]
        ++
        [ "\n#endif /* __GHCPLATFORM_H__ */" ]

-- | Generate @Config.hs@ files.
generateConfigHs :: Expr String
generateConfigHs = do
    trackGenerateHs
    cProjectName        <- getSetting ProjectName
    cProjectGitCommitId <- getSetting ProjectGitCommitId
    cProjectVersion     <- getSetting ProjectVersion
    cProjectVersionInt  <- getSetting ProjectVersionInt
    cProjectPatchLevel  <- getSetting ProjectPatchLevel
    cProjectPatchLevel1 <- getSetting ProjectPatchLevel1
    cProjectPatchLevel2 <- getSetting ProjectPatchLevel2
    cBooterVersion      <- getSetting GhcVersion
    intLib              <- getIntegerPackage
    debugged            <- ghcDebugged    <$> expr flavour
    let cIntegerLibraryType
            | intLib == integerGmp    = "IntegerGMP"
            | intLib == integerSimple = "IntegerSimple"
            | otherwise = error $ "Unknown integer library: " ++ pkgName intLib
    cGhcWithInterpreter        <- expr $ yesNo <$> ghcWithInterpreter
    cGhcWithNativeCodeGen      <- expr $ yesNo <$> ghcWithNativeCodeGen
    cGhcWithSMP                <- expr $ yesNo <$> ghcWithSMP
    cGhcEnableTablesNextToCode <- expr $ yesNo <$> ghcEnableTablesNextToCode
    cLeadingUnderscore         <- expr $ yesNo <$> flag LeadingUnderscore
    cGHC_UNLIT_PGM             <- fmap takeFileName $ getBuilderPath Unlit
    cLibFFI                    <- expr useLibFFIForAdjustors
    rtsWays                    <- getRtsWays
    cGhcRtsWithLibdw           <- getFlag WithLibdw
    let cGhcRTSWays = unwords $ map show rtsWays
    return $ unlines
        [ "{-# LANGUAGE CPP #-}"
        , "module Config where"
        , ""
        , "import GhcPrelude"
        , ""
        , "#include \"ghc_boot_platform.h\""
        , ""
        , "data IntegerLibrary = IntegerGMP"
        , "                    | IntegerSimple"
        , "                    deriving Eq"
        , ""
        , "cBuildPlatformString :: String"
        , "cBuildPlatformString = BuildPlatform_NAME"
        , "cHostPlatformString :: String"
        , "cHostPlatformString = HostPlatform_NAME"
        , "cTargetPlatformString :: String"
        , "cTargetPlatformString = TargetPlatform_NAME"
        , ""
        , "cProjectName          :: String"
        , "cProjectName          = " ++ show cProjectName
        , "cProjectGitCommitId   :: String"
        , "cProjectGitCommitId   = " ++ show cProjectGitCommitId
        , "cProjectVersion       :: String"
        , "cProjectVersion       = " ++ show cProjectVersion
        , "cProjectVersionInt    :: String"
        , "cProjectVersionInt    = " ++ show cProjectVersionInt
        , "cProjectPatchLevel    :: String"
        , "cProjectPatchLevel    = " ++ show cProjectPatchLevel
        , "cProjectPatchLevel1   :: String"
        , "cProjectPatchLevel1   = " ++ show cProjectPatchLevel1
        , "cProjectPatchLevel2   :: String"
        , "cProjectPatchLevel2   = " ++ show cProjectPatchLevel2
        , "cBooterVersion        :: String"
        , "cBooterVersion        = " ++ show cBooterVersion
        , "cStage                :: String"
        , "cStage                = show (STAGE :: Int)"
        , "cIntegerLibrary       :: String"
        , "cIntegerLibrary       = " ++ show (pkgName intLib)
        , "cIntegerLibraryType   :: IntegerLibrary"
        , "cIntegerLibraryType   = " ++ cIntegerLibraryType
        , "cGhcWithInterpreter   :: String"
        , "cGhcWithInterpreter   = " ++ show cGhcWithInterpreter
        , "cGhcWithNativeCodeGen :: String"
        , "cGhcWithNativeCodeGen = " ++ show cGhcWithNativeCodeGen
        , "cGhcWithSMP           :: String"
        , "cGhcWithSMP           = " ++ show cGhcWithSMP
        , "cGhcRTSWays           :: String"
        , "cGhcRTSWays           = " ++ show cGhcRTSWays
        , "cGhcEnableTablesNextToCode :: String"
        , "cGhcEnableTablesNextToCode = " ++ show cGhcEnableTablesNextToCode
        , "cLeadingUnderscore    :: String"
        , "cLeadingUnderscore    = " ++ show cLeadingUnderscore
        , "cGHC_UNLIT_PGM        :: String"
        , "cGHC_UNLIT_PGM        = " ++ show cGHC_UNLIT_PGM
        , "cLibFFI               :: Bool"
        , "cLibFFI               = " ++ show cLibFFI
        , "cGhcThreaded :: Bool"
        , "cGhcThreaded = " ++ show (any (wayUnit Threaded) rtsWays)
        , "cGhcDebugged :: Bool"
        , "cGhcDebugged = " ++ show debugged
        , "cGhcRtsWithLibdw :: Bool"
        , "cGhcRtsWithLibdw = " ++ show cGhcRtsWithLibdw ]

-- | Generate @ghcautoconf.h@ header.
generateGhcAutoconfH :: Expr String
generateGhcAutoconfH = do
    trackGenerateHs
    configHContents  <- expr $ map undefinePackage <$> readFileLines configH
    tablesNextToCode <- expr ghcEnableTablesNextToCode
    ghcUnreg         <- getFlag    GhcUnregisterised
    ccLlvmBackend    <- getSetting CcLlvmBackend
    ccClangBackend   <- getSetting CcClangBackend
    return . unlines $
        [ "#ifndef __GHCAUTOCONF_H__"
        , "#define __GHCAUTOCONF_H__" ]
        ++ configHContents ++
        [ "\n#define TABLES_NEXT_TO_CODE 1" | tablesNextToCode && not ghcUnreg ]
        ++
        [ "\n#define llvm_CC_FLAVOR 1"      | ccLlvmBackend == "1" ]
        ++
        [ "\n#define clang_CC_FLAVOR 1"     | ccClangBackend == "1" ]
        ++
        [ "#endif /* __GHCAUTOCONF_H__ */" ]
  where
    undefinePackage s
        | "#define PACKAGE_" `isPrefixOf` s
            = "/* #undef " ++ takeWhile (/=' ') (drop 8 s) ++ " */"
        | otherwise = s

-- | Generate @ghc_boot_platform.h@ headers.
generateGhcBootPlatformH :: Expr String
generateGhcBootPlatformH = do
    trackGenerateHs
    stage <- getStage
    let chooseSetting x y = getSetting $ if stage == Stage0 then x else y
    buildPlatform  <- chooseSetting BuildPlatform HostPlatform
    buildArch      <- chooseSetting BuildArch     HostArch
    buildOs        <- chooseSetting BuildOs       HostOs
    buildVendor    <- chooseSetting BuildVendor   HostVendor
    hostPlatform   <- chooseSetting HostPlatform  TargetPlatform
    hostArch       <- chooseSetting HostArch      TargetArch
    hostOs         <- chooseSetting HostOs        TargetOs
    hostVendor     <- chooseSetting HostVendor    TargetVendor
    targetPlatform <- getSetting TargetPlatform
    targetArch     <- getSetting TargetArch
    llvmTarget     <- getSetting LlvmTarget
    targetOs       <- getSetting TargetOs
    targetVendor   <- getSetting TargetVendor
    return $ unlines
        [ "#ifndef __PLATFORM_H__"
        , "#define __PLATFORM_H__"
        , ""
        , "#define BuildPlatform_NAME  " ++ show buildPlatform
        , "#define HostPlatform_NAME   " ++ show hostPlatform
        , "#define TargetPlatform_NAME " ++ show targetPlatform
        , ""
        , "#define " ++ cppify buildPlatform  ++ "_BUILD 1"
        , "#define " ++ cppify hostPlatform   ++ "_HOST 1"
        , "#define " ++ cppify targetPlatform ++ "_TARGET 1"
        , ""
        , "#define " ++ buildArch  ++ "_BUILD_ARCH 1"
        , "#define " ++ hostArch   ++ "_HOST_ARCH 1"
        , "#define " ++ targetArch ++ "_TARGET_ARCH 1"
        , "#define BUILD_ARCH "  ++ show buildArch
        , "#define HOST_ARCH "   ++ show hostArch
        , "#define TARGET_ARCH " ++ show targetArch
        , "#define LLVM_TARGET " ++ show llvmTarget
        , ""
        , "#define " ++ buildOs  ++ "_BUILD_OS 1"
        , "#define " ++ hostOs   ++ "_HOST_OS 1"
        , "#define " ++ targetOs ++ "_TARGET_OS 1"
        , "#define BUILD_OS "  ++ show buildOs
        , "#define HOST_OS "   ++ show hostOs
        , "#define TARGET_OS " ++ show targetOs
        , ""
        , "#define " ++ buildVendor  ++ "_BUILD_VENDOR 1"
        , "#define " ++ hostVendor   ++ "_HOST_VENDOR 1"
        , "#define " ++ targetVendor ++ "_TARGET_VENDOR  1"
        , "#define BUILD_VENDOR "  ++ show buildVendor
        , "#define HOST_VENDOR "   ++ show hostVendor
        , "#define TARGET_VENDOR " ++ show targetVendor
        , ""
        , "#endif /* __PLATFORM_H__ */" ]

-- | Generate @ghcversion.h@ header.
generateGhcVersionH :: Expr String
generateGhcVersionH = do
    trackGenerateHs
    version     <- getSetting ProjectVersionInt
    patchLevel1 <- getSetting ProjectPatchLevel1
    patchLevel2 <- getSetting ProjectPatchLevel2
    return . unlines $
        [ "#ifndef __GHCVERSION_H__"
        , "#define __GHCVERSION_H__"
        , ""
        , "#ifndef __GLASGOW_HASKELL__"
        , "# define __GLASGOW_HASKELL__ " ++ version
        , "#endif"
        , ""]
        ++
        [ "#define __GLASGOW_HASKELL_PATCHLEVEL1__ " ++ patchLevel1 | patchLevel1 /= "" ]
        ++
        [ "#define __GLASGOW_HASKELL_PATCHLEVEL2__ " ++ patchLevel2 | patchLevel2 /= "" ]
        ++
        [ ""
        , "#define MIN_VERSION_GLASGOW_HASKELL(ma,mi,pl1,pl2) (\\"
        , "   ((ma)*100+(mi)) <  __GLASGOW_HASKELL__ || \\"
        , "   ((ma)*100+(mi)) == __GLASGOW_HASKELL__    \\"
        , "          && (pl1) <  __GLASGOW_HASKELL_PATCHLEVEL1__ || \\"
        , "   ((ma)*100+(mi)) == __GLASGOW_HASKELL__    \\"
        , "          && (pl1) == __GLASGOW_HASKELL_PATCHLEVEL1__ \\"
        , "          && (pl2) <= __GLASGOW_HASKELL_PATCHLEVEL2__ )"
        , ""
        , "#endif /* __GHCVERSION_H__ */" ]

-- | Generate @Version.hs@ files.
generateVersionHs :: Expr String
generateVersionHs = do
    trackGenerateHs
    projectVersion <- getSetting ProjectVersion
    targetOs       <- getSetting TargetOs
    targetArch     <- getSetting TargetArch
    return $ unlines
        [ "module Version where"
        , "version, targetOS, targetARCH :: String"
        , "version    = " ++ show projectVersion
        , "targetOS   = " ++ show targetOs
        , "targetARCH = " ++ show targetArch ]
