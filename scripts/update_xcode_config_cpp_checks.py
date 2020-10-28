import os

prefixConfigurationFlags="OTHER_CFLAGS=$(OTHER_CFLAGS) -"
configurations=["Wall", "Werror", "Wextra", "Wassign-enum", "Wblock-capture-autoreleasing", "Wbool-conversion", "Wcomma", "Wconditional-uninitialized", "Wconstant-conversion", "Wdeprecated-declarations", "Wdeprecated-implementations", "Wdeprecated-objc-isa-usage", "Wduplicate-method-match", "Wdocumentation", "Wempty-body", "Wenum-conversion", "Wfatal-errors", "Wfloat-conversion", "Wheader-hygiene", "Wincompatible-pointer-types", "Wint-conversion", "Winvalid-offsetof", "Wnewline-eof", "Wno-unknown-pragmas", "Wnon-literal-null-conversion", "Wnon-modular-include-in-framework-module", "Wnon-virtual-dtor", "Wobjc-literal-conversion", "Wobjc-root-class", "Wprotocol", "Wshorten-64-to-32", "Wstrict-prototypes", "Wundeclared-selector", "Wunreachable-code", "Wunused-parameter"]

# get current directory
filePath = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))+"/IdentityCore/xcconfig/identitycore__common.xcconfig"
f=open(filePath, 'r')
counter = 0
# find the first line where to put extra configurations
lines=f.readlines()
for line in lines:
    counter+=1
    if line=="OTHER_CFLAGS=$(inherited) -fstack-protector-strong\n":
        break
configurationInStr = ""

# read lines and append configurations
for configuration in configurations:
    configurationInStr+=(prefixConfigurationFlags+configuration+"\n")
lines[counter]=(lines[counter]+configurationInStr)
f.close()

# write into file
f=open(filePath, 'w')
f.writelines(lines)
f.close()