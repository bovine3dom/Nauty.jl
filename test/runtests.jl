import Nauty
import LightGraphs
using BenchmarkTools
using PerformanceTestTools: @include_foreach


const n = Nauty
@static if VERSION < v"0.7.0-DEV.2005"
    using Base.Test
    macro info(x...)
        info(x...)
    end
else
    using Test
    using LinearAlgebra
end

"Convert the adjacency matrix of a directed graph into an undirected graph."
helper(x) = LightGraphs.Graph(x .| x')

iso1a = helper(Array([0 1 1; 0 0 0; 0 0 0]))
@testset begin
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
   @test n.baked_canonical_form(iso1a).canong == n.baked_canonical_form(iso1b).canong
   @test n.baked_canonical_form(diso1a).canong == n.baked_canonical_form(diso1b).canong

   @static if VERSION > v"1.3.0"
      @testset "Multithreading" begin
         @include_foreach("threading-test.jl", [["JULIA_NUM_THREADS" => "10"]])
      end
   end
end

@testset "Printing" begin
   Base.show(IOBuffer(), n.densenauty(iso1a))
   @test true
end

@info "The following should take about 1.5 microseconds:"
Base.show(@benchmark n.baked_canonical_form(iso1a).canong)
println()

@info "And this is expected to take longer, if it doesn't then the baked methods can probably be removed:"
Base.show(@benchmark n.densenauty(iso1a, n.GETCANON_OPTIONS_GRAPH).canong)
println()
