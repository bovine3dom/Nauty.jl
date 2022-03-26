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

# Two simple isomorphic graphs.
const iso1a = helper(Array([0 1 1; 0 0 0; 0 0 0]))
const iso1b = helper(Array([0 0 0; 1 0 1; 0 0 0]))

@testset begin
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

@testset "New tests" begin
   o = n.defaultoptions_graph()
   o.getcanon = 1

   rtn1a = n.densenauty(iso1a, o)
   rtn1b = n.densenauty(iso1b, o)

   @test rtn1a.canong == rtn1b.canong

   # Test that we can print without throwing an error
   Base.show(IOBuffer(), rtn1a)
   @test true

   @testset "Debug aids" begin
      @test n.label_to_adj(rtn1a.canong) == [0 0 1; 0 0 1; 1 1 0]
      @test n.label_to_humanreadable(rtn1a.canong) == Int128[32, 32, 192]
   end

   @testset "Digraphs" begin
      diso1a = LightGraphs.DiGraph(Array([0 1 1; 0 0 0; 0 0 0]))
      diso1b = LightGraphs.DiGraph(Array([0 0 0; 1 0 1; 0 0 0]))
      diso2a = LightGraphs.DiGraph(Array([0 0 0; 1 0 1; 1 0 0]))

      function cf(g)
         om = n.defaultoptions_digraph()
         om.getcanon = 1
         n.densenauty(g, om).canong
      end

      @test cf(diso1a) == cf(diso1b)
      @test cf(diso1a) != cf(diso2a)
   end
end

@info "The following should take about 1.5 microseconds:"
Base.show(@benchmark n.baked_canonical_form(iso1a).canong)
println()

@info "And this is expected to take longer, if it doesn't then the baked methods can probably be removed:"
Base.show(@benchmark n.densenauty(iso1a, n.GETCANON_OPTIONS_GRAPH).canong)
println()
