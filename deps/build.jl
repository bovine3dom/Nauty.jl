@info "Building nauty..."
using Libdl

function packagedir(pkg::AbstractString)
    if endswith(pkg, ".jl")
        pkg = pkg[1:end-3]
    end
    pkgnautywrap = joinpath(depsdir, "minnautywrap." * Libdl.dlext)
    dir = Base.find_package(pkg)
    isnothing(pkgdir) && throw(ErrorException("package \"$pkg\" not found"))              
    pkgdir = abspath(joinpath(dirname(pkgdir), ".."))
    return pkgdir
end

depsdir = joinpath(packagedir("Nauty"), "deps") 
nautydir = joinpath(depsdir, "nauty26r7")
nautyfiles = joinpath.(nautydir, ["nauty","nautil","naugraph", "schreier","naurng"] .* ".c")
nautywrapper = joinpath(depsdir, "minnautywrap.c") 
nautylib = joinpath(depsdir, "minnautywrap." * Libdl.dlext) 

run(`gcc -DWORDSIZE=64 -DMAXN=WORDSIZE -O4 -o $nautylib $nautywrapper $nautyfiles -shared -fPIC -I $nautydir`)
