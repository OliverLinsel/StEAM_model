using SpineOpt
using Pkg

Pkg.status()
println(ARGS)
run_spineopt(
	ARGS...,
	use_direct_model=false
)

########### 
##""" testing use of direct_model: 
##could improve performance drastically while maybe breaking the modeling results because JuMP indexing is broken after using... 
##cf  https://www.youtube.com/watch?v=MLunP5cdRBI , https://github.com/jump-dev/JuMP.jl/issues/969 """
###########