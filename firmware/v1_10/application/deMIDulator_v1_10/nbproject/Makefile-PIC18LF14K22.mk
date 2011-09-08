#
# Generated Makefile - do not edit!
#
# Edit the Makefile in the project folder instead (../Makefile). Each target
# has a -pre and a -post target defined where you can add customized code.
#
# This makefile implements configuration specific macros and targets.


# Include project Makefile
include Makefile

# Environment
MKDIR=mkdir -p
RM=rm -f 
CP=cp 

# Macros
CND_CONF=PIC18LF14K22
ifeq ($(TYPE_IMAGE), DEBUG_RUN)
IMAGE_TYPE=debug
FINAL_IMAGE=dist/${CND_CONF}/${IMAGE_TYPE}/deMIDulator_v1_10.${IMAGE_TYPE}.cof
else
IMAGE_TYPE=production
FINAL_IMAGE=dist/${CND_CONF}/${IMAGE_TYPE}/deMIDulator_v1_10.${IMAGE_TYPE}.cof
endif

# Object Directory
OBJECTDIR=build/${CND_CONF}/${IMAGE_TYPE}

# Distribution Directory
DISTDIR=dist/${CND_CONF}/${IMAGE_TYPE}

# Object Files
OBJECTFILES=${OBJECTDIR}/_ext/812168374/main.o


CFLAGS=
ASFLAGS=
LDLIBSOPTIONS=

# Path to java used to run MPLAB X when this makefile was created
MP_JAVA_PATH=/System/Library/Java/JavaVirtualMachines/1.6.0.jdk/Contents/Home/bin/
OS_CURRENT="$(shell uname -s)"
############# Tool locations ##########################################
# If you copy a project from one host to another, the path where the  #
# compiler is installed may be different.                             #
# If you open this project with MPLAB X in the new host, this         #
# makefile will be regenerated and the paths will be corrected.       #
#######################################################################
# MP_CC is not defined
# MP_BC is not defined
MP_AS=/Applications/microchip/mplabx/mpasmx/mpasmx
MP_LD=/Applications/microchip/mplabx/mpasmx/mplink
MP_AR=/Applications/microchip/mplabx/mpasmx/mplib
# MP_BC is not defined
# MP_CC_DIR is not defined
# MP_BC_DIR is not defined
MP_AS_DIR=/Applications/microchip/mplabx/mpasmx
MP_LD_DIR=/Applications/microchip/mplabx/mpasmx
MP_AR_DIR=/Applications/microchip/mplabx/mpasmx
# MP_BC_DIR is not defined

.build-conf: ${BUILD_SUBPROJECTS}
	${MAKE}  -f nbproject/Makefile-PIC18LF14K22.mk dist/${CND_CONF}/${IMAGE_TYPE}/deMIDulator_v1_10.${IMAGE_TYPE}.cof

MP_PROCESSOR_OPTION=18lf14k22
MP_LINKER_DEBUG_OPTION= -u_DEBUGCODESTART=0x3e00 -u_DEBUGCODELEN=0x200
# ------------------------------------------------------------------------------------
# Rules for buildStep: createRevGrep
ifeq ($(TYPE_IMAGE), DEBUG_RUN)
__revgrep__:   nbproject/Makefile-${CND_CONF}.mk
	@echo 'grep -q $$@' > __revgrep__
	@echo 'if [ "$$?" -ne "0" ]; then' >> __revgrep__
	@echo '  exit 0' >> __revgrep__
	@echo 'else' >> __revgrep__
	@echo '  exit 1' >> __revgrep__
	@echo 'fi' >> __revgrep__
	@chmod +x __revgrep__
else
__revgrep__:   nbproject/Makefile-${CND_CONF}.mk
	@echo 'grep -q $$@' > __revgrep__
	@echo 'if [ "$$?" -ne "0" ]; then' >> __revgrep__
	@echo '  exit 0' >> __revgrep__
	@echo 'else' >> __revgrep__
	@echo '  exit 1' >> __revgrep__
	@echo 'fi' >> __revgrep__
	@chmod +x __revgrep__
endif

# ------------------------------------------------------------------------------------
# Rules for buildStep: assemble
ifeq ($(TYPE_IMAGE), DEBUG_RUN)
.PHONY: ${OBJECTDIR}/_ext/812168374/main.o
${OBJECTDIR}/_ext/812168374/main.o: ../source/main.asm __revgrep__ nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} ${OBJECTDIR}/_ext/812168374 
ifneq (,$(findstring MINGW32,$(OS_CURRENT))) 
	-${MP_AS} $(MP_EXTRA_AS_PRE) -d__DEBUG -d__MPLAB_DEBUGGER_PK3=1 -q -p$(MP_PROCESSOR_OPTION)  -l"${OBJECTDIR}/_ext/812168374/main.lst" -e"${OBJECTDIR}/_ext/812168374/main.err" $(ASM_OPTIONS) -o"${OBJECTDIR}/_ext/812168374/main.o" ../source/main.asm 
else 
	-${MP_AS} $(MP_EXTRA_AS_PRE) -d__DEBUG -d__MPLAB_DEBUGGER_PK3=1 -q -p$(MP_PROCESSOR_OPTION) -u  -l"${OBJECTDIR}/_ext/812168374/main.lst" -e"${OBJECTDIR}/_ext/812168374/main.err" $(ASM_OPTIONS) -o"${OBJECTDIR}/_ext/812168374/main.o" ../source/main.asm 
endif 
	@cat  "${OBJECTDIR}/_ext/812168374/main.err" | sed -e 's/\x0D$$//' -e 's/\(^Warning\|^Error\|^Message\)\(\[[0-9]*\]\) *\(.*\) \([0-9]*\) : \(.*$$\)/\3:\4: \1\2: \5/g'
	@./__revgrep__ "^Error" ${OBJECTDIR}/_ext/812168374/main.err
else
.PHONY: ${OBJECTDIR}/_ext/812168374/main.o
${OBJECTDIR}/_ext/812168374/main.o: ../source/main.asm __revgrep__ nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} ${OBJECTDIR}/_ext/812168374 
ifneq (,$(findstring MINGW32,$(OS_CURRENT))) 
	-${MP_AS} $(MP_EXTRA_AS_PRE) -q -p$(MP_PROCESSOR_OPTION)  -l"${OBJECTDIR}/_ext/812168374/main.lst" -e"${OBJECTDIR}/_ext/812168374/main.err" $(ASM_OPTIONS) -o"${OBJECTDIR}/_ext/812168374/main.o" ../source/main.asm 
else 
	-${MP_AS} $(MP_EXTRA_AS_PRE) -q -p$(MP_PROCESSOR_OPTION) -u  -l"${OBJECTDIR}/_ext/812168374/main.lst" -e"${OBJECTDIR}/_ext/812168374/main.err" $(ASM_OPTIONS) -o"${OBJECTDIR}/_ext/812168374/main.o" ../source/main.asm 
endif 
	@cat  "${OBJECTDIR}/_ext/812168374/main.err" | sed -e 's/\x0D$$//' -e 's/\(^Warning\|^Error\|^Message\)\(\[[0-9]*\]\) *\(.*\) \([0-9]*\) : \(.*$$\)/\3:\4: \1\2: \5/g'
	@./__revgrep__ "^Error" ${OBJECTDIR}/_ext/812168374/main.err
endif

# ------------------------------------------------------------------------------------
# Rules for buildStep: link
ifeq ($(TYPE_IMAGE), DEBUG_RUN)
dist/${CND_CONF}/${IMAGE_TYPE}/deMIDulator_v1_10.${IMAGE_TYPE}.cof: ${OBJECTFILES}  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} dist/${CND_CONF}/${IMAGE_TYPE} 
	${MP_LD} $(MP_EXTRA_LD_PRE)   -p$(MP_PROCESSOR_OPTION)  -w -x -u_DEBUG -z__ICD2RAM=1  -z__MPLAB_BUILD=1  -z__MPLAB_DEBUG=1 -z__MPLAB_DEBUGGER_PK3=1 $(MP_LINKER_DEBUG_OPTION) -odist/${CND_CONF}/${IMAGE_TYPE}/deMIDulator_v1_10.${IMAGE_TYPE}.cof ${OBJECTFILES}     
else
dist/${CND_CONF}/${IMAGE_TYPE}/deMIDulator_v1_10.${IMAGE_TYPE}.cof: ${OBJECTFILES}  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} dist/${CND_CONF}/${IMAGE_TYPE} 
	${MP_LD} $(MP_EXTRA_LD_PRE)   -p$(MP_PROCESSOR_OPTION)  -w   -z__MPLAB_BUILD=1  -odist/${CND_CONF}/${IMAGE_TYPE}/deMIDulator_v1_10.${IMAGE_TYPE}.cof ${OBJECTFILES}     
endif


# Subprojects
.build-subprojects:

# Clean Targets
.clean-conf:
	${RM} -r build/PIC18LF14K22
	${RM} -r dist/PIC18LF14K22

# Enable dependency checking
.dep.inc: .depcheck-impl

include .dep.inc
