import Nauty
import LightGraphs
using BenchmarkTools
const n = Nauty
@static if VERSION < v"0.7.0-DEV.2005"
    using Base.Test
else
    using Test
end

helper(x) = LightGraphs.Graph(x .| x')
iso1a = helper(Array([0 1 1; 0 0 0; 0 0 0]))
@testset begin
   "Convert the adjacency matrix of a directed graph into an undirected graph."

   # Two simple isomorphic graphs.
   iso1b = helper(Array([0 0 0; 1 0 1; 0 0 0]))

   @test n.lg_to_nauty(iso1a) == Array{UInt64,1}([0x6000000000000000, 0x8000000000000000, 0x8000000000000000])
   @test n.lg_to_nauty(iso1b) == Array{UInt64,1}([0x4000000000000000, 0xa000000000000000, 0x4000000000000000])

   # Two simple isomorphic digraphs.
   diso1a = LightGraphs.DiGraph(Array([0 1 1; 0 0 0; 0 0 0]))
   diso1b = LightGraphs.DiGraph(Array([0 0 0; 1 0 1; 0 0 0]))

   @test n.lg_to_nauty(diso1a) == Array{UInt64,1}([0x6000000000000000, 0x0000000000000000, 0x0000000000000000])
   @test n.lg_to_nauty(diso1b) == Array{UInt64,1}([0x0000000000000000, 0xa000000000000000, 0x0000000000000000])

   # This indirectly tests densenauty(), optionblk(), optionblk_mutable(), lg_to_nauty()
   @test n.canonical_form(iso1a).canong == n.canonical_form(iso1b).canong
   @test n.canonical_form(diso1a).canong == n.canonical_form(diso1b).canong

end

println("The following should take about 7 microseconds:")
@show @benchmark n.canonical_form(iso1a).canong
