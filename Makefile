# Each package must have a makefile with the name <package_name>.mk which
# defines the following goals:
# <package_name>: builds the package.
# <package_name>_test: builds the unit tests for the package.
# <package_name>_clean: removes object files generated by package.
PACKAGES = hello logger

# These variables are used by packages when they build their targets. Note that
# these variables will be modified based on the variables `target` and `mode`
# that are set on the command line.
#
# BUILD_DIR: directory to place object files. relative to *package* directory.
# OVERLAY_DIR: directory containing the root filesystem overlay.
# CFLAGS: flags to use with C compiler.
# RELEASE_CFLAGS: additional flags to use with C compiler in release mode.
# DEBUG_CFLAGS: additional flags to use with C compiler in debug mode.
# TEST_FLAGS: flags to use when building unit tests.
BUILD_DIR = build
OVERLAY_DIR = ext-tree/board
CFLAGS = -std=c99 -Wall -Wextra -pedantic -Werror
RELEASE_CFLAGS = -O2 -s -DNDEBUG
DEBUG_CFLAGS = -g
COVERAGE_CFLAGS = -fprofile-arcs -ftest-coverage
TEST_FLAGS = -std=c++11 -g -I$(GTEST_DIR) -I$(GTEST_DIR)/include
TEST_LD_FLAGS = -pthread -lgcov --coverage

# Check if the `target` variable was set on the command line. If not, local
# machine becomes the target by default. If target is invalid, throw an error
# no matter what. Supported values for the target variable are `qemu` and
# `arietta`.
#
# The following variables are modified or created based on the target:
# BUILD_DIR: modified based on target.
# CC: path to C compiler.
# CXX: path to C++ compiler.
# OVERLAY_DIRECTORY: modified based on target.
ifndef target
    CC = gcc
    CXX = g++
else
ifeq ($(target), qemu)
    BUILD_DIR := $(BUILD_DIR)/qemu
    CC = arm-buildroot-linux-uclibcgnueabi-cc
    OVERLAY_DIR := $(OVERLAY_DIR)/qemu/overlay

    # Add directory containing compiler to PATH.
    export PATH := $(shell echo ~)/buildroot-qemu/host/usr/bin:$(PATH)
else
ifeq ($(target), arietta)
    $(error target arietta is not currently supported)
else
ifeq ($(filter $(MAKECMDGOALS), clean clean_tree),)
    $(error target must be specified)
endif
endif
endif
endif

# Check if the mode variable was set on the command line. If not, throw an error
# unless a goal that does not require a mode was called. If mode is invalid,
# throw an error no matter what.
#
# The following variables are modified based on the release mode:
# BUILD_DIR
# CFLAGS
ifeq ($(mode), release)
    BUILD_DIR := $(BUILD_DIR)/release
    CFLAGS += $(RELEASE_CFLAGS)
else
ifeq ($(mode), debug)
    BUILD_DIR := $(BUILD_DIR)/debug
    CFLAGS += $(DEBUG_CFLAGS)
else
ifdef mode
    $(error mode must be set to release or debug)
else
ifeq ($(filter $(MAKECMDGOALS), build clean clean_tree),)
    $(error mode must be specified)
endif
endif
endif
endif

# Only include coverage flags only when debug and not tests
ifeq ($(mode), debug)
ifeq ($(filter $(MAKECMDGOALS), test),)
	CFLAGS += $(COVERAGE_CFLAGS)
endif
endif

.PHONY = all build clean clean_tree test check

all: $(PACKAGES)


# Only include test goal if building locally. Unit tests on other targets are
# not presently supported.
ifndef target
    test: $(foreach pkg, $(PACKAGES), $(pkg)_test)
		for pkg in $(PACKAGES); do \
			./$$pkg/$$pkg-test; \
		done
endif


# Build the embedded Linux OS with external tree.
build:
ifndef target
	$(error target must be specified)
else
ifeq ($(target), qemu)
	make BR2_EXTERNAL=$(shell pwd)/ext-tree \
		O=$(shell echo ~)/buildroot-qemu sc_qemu_defconfig -C buildroot
	make -C $(shell echo ~)/buildroot-qemu
endif
endif

# Call the clean goal in each package makefile, remove the overlay directory,
# and remove the Google Test build directory.
clean: $(foreach pkg, $(PACKAGES), $(pkg)_clean) clean_tree gtest_clean

# Remove the overlay directory.
clean_tree:
	@if [ -d $(OVERLAY_DIR) ]; then rm -r $(OVERLAY_DIR); fi

# Include makefile for building Google Test and makefiles from each package.
include common/googletest.mk
include $(foreach pkg, $(PACKAGES), $(pkg)/$(pkg).mk)
