import LightGraphs
const lg = LightGraphs

const ba8 = lg.barabasi_albert(8, 5, 2)

import Nauty

g8 = Nauty.lg_to_nauty(ba8)
