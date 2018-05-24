import LightGraphs
lg = LightGraphs

Pkg.build("Nauty")
Pkg.test("Nauty")
reload("Nauty"); n = Nauty

# Example graph
ba8 = lg.barabasi_albert(8, 5, 2)
g8 = Nauty.lg_to_nauty(ba8)

# Look for segfaults
for i = 1:2000000
  n.densenauty(ba8)
  n.densenauty(g8)
  n.densenauty(ba8, n.optionblk())
  n.densenauty(ba8, n.optionblk_mutable())
end

n.baked_canonical_form(ba8)
n.baked_canonical_form_and_stats(ba8)

n.optionblk()
