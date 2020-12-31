using LightGraphs
using Nauty
using Test

function dowork()
   g = LightGraphs.barabasi_albert(63, 5)
   Nauty.baked_canonical_form(g).canong
end

fetch.([Threads.@spawn dowork() for _ in 1:1000])

@test true
