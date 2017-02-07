# Each package must have a makefile with the name <package_name>.mk which
# defines the following goals:
# <package_name>: builds the package.
# <package_name>_clean: removes object files generated by package.
PACKAGES = hello

# These variables are used by packages when they build their targets. Note that
# these variables will be modified based on the variables `target` and `mode`
# that are set on the command line.
#
# BUILD_DIR: directory to place object files. relative to *package* directory.
# OVERLAY_DIR: directory containing the root filesystem overlay.
# CC: path to C compiler.
# CFLAGS: flags to use with C compiler.
# RELEASE_CFLAGS: additional flags to use with C compiler in release mode.
# DEBUG_CFLAGS: additional flags to use with C compiler in debug mode.
BUILD_DIR = build
OVERLAY_DIR = ext-tree/board
CC = arm-buildroot-linux-uclibcgnueabi-cc
CFLAGS = -std=c99 -Wall -Wextra -pedantic -Werror
RELEASE_CFLAGS = -O2 -s -DNDEBUG
DEBUG_CFLAGS = -g

# Check if the target variable was set on the command line. If not, throw an
# error unless a goal that does not require a target was called. If target is
# invalid, throw an error no matter what.
ifeq ($(target), qemu)
    BUILD_DIR := $(BUILD_DIR)/qemu
    OVERLAY_DIR := $(OVERLAY_DIR)/qemu/overlay

    export PATH := $(shell echo ~)/buildroot-qemu/host/usr/bin:$(PATH)
else
ifeq ($(target), arietta)
    $(error target arietta is not currently supported)
else
ifdef target
    $(error target must be set to qemu or arietta)
else
ifneq ($(MAKECMDGOALS), clean)
    $(error target must be specified)
endif
endif
endif
endif

# Check if the mode variable was set on the command line. If not, throw an error
# unless a goal that does not require a mode was called. If mode is invalid,
# throw an error no matter what.
ifeq ($(mode), release)
    CFLAGS += $(RELEASE_CFLAGS)
    BUILD_DIR := $(BUILD_DIR)/release
else
ifeq ($(mode), debug)
    CFLAGS += $(DEBUG_CFLAGS)
    BUILD_DIR := $(BUILD_DIR)/debug
else
ifdef mode
    $(error mode must be set to release or debug)
else
ifeq ($(filter $(MAKECMDGOALS), build clean),)
    $(error mode must be specified)
endif
endif
endif
endif

.PHONY = all build clean

all: $(PACKAGES)

# Build the embedded Linux OS with external tree.
build:
ifeq ($(target), qemu)
	make BR2_EXTERNAL=$(shell pwd)/ext-tree \
		O=$(shell echo ~)/buildroot-qemu sc_qemu_defconfig -C buildroot
	make -C $(shell echo ~)/buildroot-qemu
endif

# Call the clean goal in each package makefile and removes the overlay
# directory.
clean: $(foreach pkg, $(PACKAGES), $(pkg)_clean)
	@if [ -d $(OVERLAY_DIR) ]; then rm -r $(OVERLAY_DIR); fi

# Include makefiles from each package.
include $(foreach pkg, $(PACKAGES), $(pkg)/$(pkg).mk)
