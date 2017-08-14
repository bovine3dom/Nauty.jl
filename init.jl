import LightGraphs
const lg = LightGraphs

const ba8 = lg.barabasi_albert(8, 5, 2)

include("nauty.jl")

g8 = nauty.lg_to_nauty(ba8)
