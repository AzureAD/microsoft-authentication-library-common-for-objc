import os

configurations = [
    "Wall",
    "Werror",
    "Wextra",
    "Wassign-enum",
    "Wblock-capture-autoreleasing",
    "Wbool-conversion",
    "Wcomma",
    "Wconditional-uninitialized",
    "Wconstant-conversion",
    "Wdeprecated-declarations",
    "Wdeprecated-implementations",
    "Wdeprecated-objc-isa-usage",
    "Wduplicate-method-match",
    "Wdocumentation",
    "Wempty-body",
    "Wenum-conversion",
    "Wfatal-errors",
    "Wfloat-conversion",
    "Wheader-hygiene",
    "Wincompatible-pointer-types",
    "Wint-conversion",
    "Winvalid-offsetof",
    "Wnewline-eof",
    "Wno-unknown-pragmas",
    "Wnon-literal-null-conversion",
    "Wnon-modular-include-in-framework-module",
    "Wnon-virtual-dtor",
    "Wobjc-literal-conversion",
    "Wobjc-root-class",
    "Wprotocol",
    "Wshorten-64-to-32",
    "Wstrict-prototypes",
    "Wundeclared-selector",
    "Wunreachable-code",
    "Wunused-parameter",
]

current_directory = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
file_path = current_directory + "/IdentityCore/xcconfig/identitycore__common.xcconfig"


contents = []
with open(file_path, "r") as f:
    contents = list(f.readlines())

for i in range(len(contents)):
    if contents[i] == "OTHER_CFLAGS=$(inherited) -fstack-protector-strong\n":

        new_lines = []
        for configuration in configurations:
            new_lines.append("OTHER_CFLAGS=$(OTHER_CFLAGS) -" + configuration + "\n")
        contents = contents[:i] + new_lines + contents[i:]

print('\n'.join(contents))

# write into file
with open(file_path, "w") as f:
    f.writelines(contents)
