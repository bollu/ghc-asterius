# -----------------------------------------------------------------------------
#
# (c) 2009 The University of Glasgow
#
# This file is part of the GHC build system.
#
# To understand how the build system works and how to modify it, see
#      https://gitlab.haskell.org/ghc/ghc/wikis/building/architecture
#      https://gitlab.haskell.org/ghc/ghc/wikis/building/modifying
#
# -----------------------------------------------------------------------------

ifeq "$(Windows_Host)" "YES"

driver/ghc_dist_C_SRCS   = ghc.c ../utils/cwrapper.c ../utils/getLocation.c
driver/ghc_dist_CC_OPTS += -I driver/utils
driver/ghc_dist_PROGNAME = ghc-$(ProjectVersion)
driver/ghc_dist_INSTALL  = YES
driver/ghc_dist_INSTALL_INPLACE = NO

$(eval $(call build-prog,driver/ghc,dist,0))

endif

