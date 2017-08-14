# Mostly taken wholesale from https://juliacomputing.com/blog/2017/02/21/finding-ioctls-with-cxx.html
using Cxx
CCompiler = Cxx.new_clang_instance(
    false #= don't julia definitions =#,
    true #= C mode (as opposed to C++) =#)

Cxx.cxxinclude(CCompiler, "/home/olie/Dropbox/working_dir/julia/offline-laptop/mykavosh/pynauty-0.6.0/nauty26r7/nauty.h") # Gives us an error but we can probably ignore it

PP = icxx"&$(Cxx.active_instances[2].CI)->getPreprocessor();"

P  = Cxx.active_instances[2].Parser

#= icxx"$PP->dumpMacroInfo($PP->getIdentifierInfo(\"WORDSIZE\"));" =#

getIdentifierInfo(PP, name) = icxx"$PP->getIdentifierInfo($name);"
getMacroInfo(PP, II::pcpp"clang::IdentifierInfo") = icxx"$PP->getMacroInfo($II);"
getMacroInfo(PP, name::String) = getMacroInfo(PP, getIdentifierInfo(PP, name))
tokens(MI::pcpp"clang::MacroInfo") = icxx"$MI->tokens();"

# Convert Tokens that are identifiers to strings, we'll use these later
tok_is_identifier(Tok) = icxx"$Tok.is(clang::tok::identifier);"
Base.String(II::pcpp"clang::IdentifierInfo") = unsafe_string(icxx"$II->getName().str();")
function Base.String(Tok::cxxt"clang::Token")
    @assert tok_is_identifier(Tok)
    II = icxx"$Tok.getIdentifierInfo();"
    @assert II != C_NULL
    String(II)
end
getSpelling(PP, Tok) = unsafe_string(icxx"$PP->getSpelling($Tok);")
function Base.show(io::IO, Tok::Union{cxxt"clang::Token",cxxt"clang::Token&"})
    print(io, unsafe_string(icxx"clang::tok::getTokenName($Tok.getKind());"))
    print(io, " '", getSpelling(PP, Tok), "'")
end

# Iteration for ArrayRef
import Base: start, next, length, done
const ArrayRef = cxxt"llvm::ArrayRef<$T>" where T
start(AR::ArrayRef) = 0
function next(AR::cxxt"llvm::ArrayRef<$T>", i) where T
    (icxx"""
        // Force a copy, otherwise we'll retain reference semantics in julia
        // which is not what people expect.
        $T element = ($AR)[$i];
        return element;
    """, i+1)
end
length(AR::ArrayRef) = icxx"$AR.size();"
done(AR::ArrayRef, i) = i >= length(AR)

# Usage stringFromMacro("WORDSIZE") etc
function stringFromMacro(macroname)
    join([getSpelling(PP,x) for x in tokens(getMacroInfo(PP,macroname))])
end
