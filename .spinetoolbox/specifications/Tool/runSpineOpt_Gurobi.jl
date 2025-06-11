using SpineOpt
using Pkg
using Gurobi
#using PackageCompiler
Pkg.status()

m = run_spineopt(ARGS...,lp_solver=Gurobi.Optimizer,mip_solver=Gurobi.Optimizer)