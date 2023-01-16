# -- start config

build_dir := build
ftdi_dir := /Library/Application\ Support/Microsoft

# for Linux and macOS that ^^ should be sufficient

# for Windows and msvc vv + msys2 (MinGW64)
# ls "/c/Program Files/Microsoft Visual Studio"
vs_version := 2022
# ls "/c/Program Files/Microsoft Visual Studio/XXXXXXvs_versionXXXXXX/Community/VC/Tools/MSVC/"
msvc_version := 14.34.31933
# ls "/c/Program Files (x86)/Windows Kits/"
sdk_major_version := 10
# ls "/c/Program Files (x86)/Windows Kits/XXXXXsdm_major_versionXXXXXX/Include/"
sdk_full_version := 10.0.22000.0

# -- end config


# --
xload_dir := XLoad

# --
compiler ?= cc
CXXFLAGS += -std=c++20
CXXFLAGS += -g

obj_ext ?= o
shared_ext ?= so
shared_switch ?= -shared

# --
os ?= $(shell uname -s)

ifeq ($(findstring MINGW,$(os)),MINGW)
os := MinGW
endif

ifeq ($(os),Darwin)
compiler := clang
shared_ext := dylib
shared_switch := -dynamic
endif

ifeq ($(os),MinGW)
compiler := msvc
endif

ifeq ($(compiler),msvc)
# msvc
CXX := ./cccl
CXXFLAGS += -EHa # exceptions
#CXXFLAGS += -bigobj # because of juce
CXXFLAGS += --cccl-muffle
obj_ext := obj
shared_ext := dll
shared_switch := -shared

cl_path := /c/Program Files/Microsoft Visual Studio/$(vs_version)/Community/VC/Tools/MSVC/$(msvc_version)
cl_path_win := $(shell cygpath -w -s "$(cl_path)")
cl_path_unix = $(subst %:/,/%/,$(shell cygpath -m -s "$(cl_path)"))
export PATH := $(cl_path_win)/bin/Hostx64/x64:$(PATH)

sdk_path = /c/Program Files (x86)/Windows Kits/$(sdk_major_version)
sdk_inc_path :=  $(subst %:/,/%/,$(shell cygpath -m -s "$(sdk_path)/Include/$(sdk_full_version)"))
sdk_lib_path :=  $(subst %:/,/%/,$(shell cygpath -m -s "$(sdk_path)/Lib/$(sdk_full_version)"))

CXXFLAGS += -I$(cl_path_unix)/include -I$(sdk_inc_path)/ucrt -I$(sdk_inc_path)/um -I$(sdk_inc_path)/shared /FS
LDFLAGS += -L$(cl_path_unix)/lib/x64 -L$(sdk_lib_path)/ucrt/x64 -L$(sdk_lib_path)/um/x64 -L$(sdk_lib_path)/shared
LDFLAGS += -lcomdlg32 -lAdvapi32 -lGdi32 -lOle32 -lOleAut32 -lwinmm -lWs2_32 -lShell32
endif

ifeq ($(compiler),clang)
CXXFLAGS += -MMD
endif

# -- utils

rwildcard = $(wildcard $1$2) $(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2))
rwildcardmul = $(wildcard $(addsuffix $2, $1)) $(foreach d,$(wildcard $(addsuffix *, $1)),$(call rwildcard,$d/,$2))


# -- XLoad

xload_srcs += XLoad.cpp
xload_srcs := $(addprefix $(xload_dir)/,$(xload_srcs))
xload_objs := $(addprefix $(build_dir)/,$(xload_srcs:.cpp=.$(obj_ext)))

xload_cxxflags += -I$(xload_dir)/FTDI
#xload_ldflags += $(xload_objs)
xload_ldflags += -L$(ftdi_dir) -lftd2xx

# every demo needs flip anyway
CXXFLAGS += $(xload_cxxflags)
LDFLAGS += $(xload_ldflags)

xload_exe := $(build_dir)/XLoad.exe
$(xload_exe): $(xload_objs)
	$(call gen_file,l,$<,$@,  $(CXX) -o $@ $^ $(LDFLAGS))
default: $(xload_exe)
xload_test: $(xload_exe)
xload_test: test_exe=$(xload_exe)
test: xload_test

load: $(xload_exe)
xload_test: test_exe=$(xload_exe)
xload_test: test_args=-img ../XVA1/XVA1_102/bitloader/CMOD_A7_Loader.bit

%_test:
	$(call run_exe,$(test_exe),env DYLD_LIBRARY_PATH=$(ftdi_dir) $(test_exe) $(test_args))


# -- open FPGA loader

open_fpga:
	@#openFPGALoader -r -b arty -f ../XVA1/XVA1_102/bitloader/CMOD_A7_Loader.bit
	openFPGALoader -r -b arty -f ../XVA1/XVA1_102/XVA1_CMOD_A7.bin


# -- rules

ifeq ($(os),Darwin)
$(build_dir)/%.$(obj_ext): %.mm
	$(call gen_file,c,$<,$@,  clang  $(CXXFLAGS) -c $< -o $@ )
endif

$(build_dir)/%.$(obj_ext): %.cpp
	$(call gen_file,c,$<,$@,  $(CXX) $(CXXFLAGS) -c $< -o $@ )


# -- dependencies

objs := $(xload_objs)
deps := $(objs:%.$(obj_ext)=%.d)
exes := $(xload_exe)

-include $(deps)


# -- clean

# don't remove deps .d
clean:
	@rm -f $(objs)
	@echo rm objs
	@rm -f $(exes)
	@echo rm exes

distclean: clean
	find . -name ".DS_Store" -exec rm -rf {} \;
	rm -f *.pdb

clear: distclean
ifneq ($(strip $(build_dir)),)
	rm -rf $(build_dir)
endif

zip: distclean
	(cd ..; rm -f XLoad.zip; zip -r XLoad.zip XLoad)


# -- build messages

# Set silent_opt to 's' if --quiet/-s set, otherwise ''.
silent_opt := $(filter s,$(word 1, $(MAKEFLAGS)))
silent =
ifeq ($(silent_opt),s)
silent = yes
endif
ifeq ($V,0)
silent = yes
endif

ifeq ($(silent),yes)

define gen_file
	@$(4)
endef
define run_exe
	@$(2)
endef

else

	ifeq ($V,max)
define gen_file # 1:type 2:src 3:dst 4:cmd 
	@mkdir -p $(dir $3)
	$(4)
endef
	else
define gen_file
	@mkdir -p $(dir $3)
	@echo $(1) $(notdir $3)
	@$(4)
endef
	endif

	ifeq ($V,max)
define run_exe
	$(2)
endef
	else
define run_exe
	@echo r $(notdir $(1))
	@$(2)
endef
	endif

endif

