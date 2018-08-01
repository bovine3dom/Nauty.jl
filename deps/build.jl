println("Building nauty...")
nautydir = "$(@__DIR__)/nauty26r7/"
nautyfiles = nautydir .* ["nauty","nautil","naugraph", "schreier","naurng"] .* ".c"
run(`gcc -DWORDSIZE=64 -DMAXN=WORDSIZE -O4 -o $(@__DIR__)/minnautywrap.so $(@__DIR__)/minnautywrap.c $nautyfiles -shared -fPIC -I $nautydir`)
