push!(LOAD_PATH,"C:/Users/erica/OneDrive/Artigos/Autoria principal/Abertos/IEEE_MUST/Code/contract_optim_gen/src")
using MUSTOptim_gen
using Dates, CSV, JLD, Plots, Plots.PlotMeasures
param_path        = "C:/Users/erica/OneDrive/Artigos/Autoria principal/Abertos/IEEE_MUST/testes_paper/data"

# Study executions
upscalesize = 3 #Xx upscaling in resolution
upscalefont = 3
fntsm = Plots.font("sans-serif", pointsize=round(7.0*upscalefont))
fntlg = Plots.font("sans-serif", pointsize=round(9.5*upscalefont))
default(linewidth=3.0)
default(right_margin=30mm, left_margin=30mm, bottom_margin=30mm )
default(titlefont=fntsm, guidefont=fntlg, tickfont=fntlg, legendfont=fntlg)
default(size=(800*upscalesize,400*upscalesize))

# Contracting studies
demandcontract(param_path)

# Sensitivity studies
tariff_options    = ["uncertainty_range"] #, "range", "undercontracting","overcontracting"] #
initial_value   = 0.0
step            = 0.5
final_value     = 6.0
month = 3
year = 2

sensitivity(param_path,tariff_options,initial_value,final_value,step,month,year)