push!(LOAD_PATH,"C:/Users/erica/OneDrive/Artigos/Autoria principal/Abertos/IEEE_MUST/Code/contract_optim_gen/src")
using MUSTOptim_gen
using Dates, CSV, JLD, PyPlot#, Plots, Plots.PlotMeasures
param_path        = "C:/Users/erica/OneDrive/Artigos/Autoria principal/Abertos/IEEE_MUST/testes_paper/data"

# Study executions
# upscalesize = 4 #Xx upscaling in resolution
# upscalefont = 4
# fntsm = Plots.font("sans-serif", pointsize=round(7.0*upscalefont))
# fntlg = Plots.font("sans-serif", pointsize=round(9.5*upscalefont))
# default(linewidth=3.0)
# default(right_margin=20mm, left_margin=20mm, bottom_margin=20mm )
# default(titlefont=fntsm, guidefont=fntlg, tickfont=fntlg, legendfont=fntsm)
# default(size=(800*upscalesize,600*upscalesize))

# Contracting studies
demandcontract(param_path)

# Sensitivity studies - Tariff
tariff_options    = ["uncertainty_range"] # "undercontracting" "overcontracting"]
initial_value   = 0.0
step            = 0.2
final_value     = 6.0
month = 8
year = 1

sensitivity_tariff(param_path,tariff_options,initial_value,final_value,step,month,year)

# Sensitivity studies - Risk parameters
initial_value   = 0.0
step            = 0.05
final_value     = 1.0
month = 8
year = 1

sensitivity_risk(param_path,initial_value,final_value,step,month,year)

# Caso especial de gráfico comparando cases com e sem contratao de range
# =========================================================================
# Connection 3-9
path = param_path

# Com contrato de faixa
# Leitura dos arquivos de dados
dimensions, optimparam, transparam, busdata, peaksnames, study_name = readdata(path)
        
# Otimização dos contratos
optimalresults, optimalcontract, riskindicators, plotdatamw, plotdatapercent = optimizecontract(transparam,dimensions,optimparam,busdata)

# Escrita de saídas
infotuple_strat1 = (dimensions, optimparam, peaksnames)

con = transparam.busnames[1] # fronteiras de MUST

# Pasta de saída dos resultados
out_path = joinpath(path, "Resultados", "$study_name", "$con")
mkpath(out_path)

# Geração dos gráficos de saída
plotdatamwtuple_strat1 = (out_path, con, plotdatamw[con])
plotdatapercenttuple_strat1 = (out_path, con, plotdatapercent[con])

# Sem contrato de faixa
# Leitura dos arquivos de dados
optimparam.flextolflag = 0
        
# Otimização dos contratos
optimalresults, optimalcontract, riskindicators, plotdatamw, plotdatapercent = optimizecontract(transparam,dimensions,optimparam,busdata)

# Escrita de saídas
infotuple_strat2 = (dimensions, optimparam, peaksnames)

# Geração dos gráficos de saída
plotdatamwtuple_strat2 = (out_path, con, plotdatamw[con])
plotdatapercenttuple_strat2 = (out_path, con, plotdatapercent[con])

p=1
# (dimensions,optimparam,peaksnames) = infotuple
(out_path,con,plotdata_strat1) = plotdatamwtuple_strat1
(out_path,con,plotdata_strat2) = plotdatamwtuple_strat2

# xticks_base = collect(0:12:dimensions.nyear*dimensions.nmonths)
# y_interval = ceil((ceil(maximum(plotdata_strat2[p].f))-floor(minimum(plotdata_strat2[p].f)))/10)
# if y_interval == 0 
#     y_interval = 1
# end

# yticks_base = 0:y_interval:ceil(maximum(plotdata_strat2[p].f))+y_interval
# ylims_base = (0,ceil(maximum(plotdata_strat2[p].f))+y_interval)

xticks_original = [0,11,23,35,47]
xticks_plot     = [1,12,24,36,48]
linewdt_1 = 0.8
linewdt_2 = 1.2
fontsize_plot = 15

fig  = figure(figsize=(10,10))
plt1 = plot(plotdata_strat2[p].f[:,1], color = "gray", linewidth=linewdt_1,label = "Scenarios")
plt2 = plot(plotdata_strat2[p].f[:,2:end], color = "gray", linewidth=linewdt_1)
plt3 = plot(plotdata_strat1[p].penalty,color = "#cc7000", linewidth=linewdt_2, label = "Penalty limits(case 1)")
plt4 = plot(plotdata_strat1[p].overcont,color = "#cc7000", linewidth=linewdt_2)
plt5 = plot(plotdata_strat1[p].optimalM,color = "blue",label = "Optimal contract(case 1)",linewidth=linewdt_2)
plt6 = plot(plotdata_strat1[p].optimalM .* (1+transparam.ϵU),color = "blue",label = "Regulated tolerance(case 1)",linestyle="dashed",linewidth=linewdt_2)
plt7 = plot(plotdata_strat1[p].optimalM .* (1-transparam.ϵS),color = "blue",linewidth=linewdt_2,linestyle="dashed")
plt8 = plot(plotdata_strat2[p].optimalM,color = "black",label = "Optimal contract(case 2)",linewidth=linewdt_2)
plt9 = plot(plotdata_strat2[p].optimalM .* (1+transparam.ϵU),color = "black",label = "Regulated tolerance(case 2)",linestyle="dashed",linewidth=linewdt_2)
plt10 = plot(plotdata_strat2[p].optimalM .* (1-transparam.ϵS),color = "black",linewidth=linewdt_2,linestyle="dashed")

xlabel("Months", fontsize=fontsize_plot);
ylabel("MW", fontsize=fontsize_plot);
xlim(xmin=0)
xlim(xmax=48)
ylim(ymin=0.0)
xticks(ticks=xticks_original, labels=xticks_plot)
legend(ncol=2, loc=3, fontsize=fontsize_plot,frameon=false)
tick_params(axis="both", labelsize=fontsize_plot)
display(gcf())
savefig(joinpath("C:\\Users\\erica\\OneDrive\\Projetos P&D\\Artigos\\MUST\\img","cenarios_MUST_Fronteira_2postounicoV2.png"), dpi=300, bbox_inches="tight")


# plot(legend=:bottomleft)
# plot!(plotdata_strat2[p].f[:,1], color = :lightgray,label = "Scenarios", xticks = xticks_base, yticks = yticks_base, ylims = ylims_base)
        
# plot!(plotdata_strat2[p].f[:,2:end], color = :lightgray,label = "")

# plot!(plotdata_strat1[p].penalty,color = :orange,label = "Penalty limits(case 1)" ,linewidth=4.5)
# plot!(plotdata_strat1[p].overcont,color = :orange,label = "" ,linewidth=4.5)
# plot!(plotdata_strat1[p].optimalM,color = :blue,label = "Optimal contract(case 1)",linewidth=4.5)
# plot!(plotdata_strat1[p].optimalM .* (1+transparam.ϵU),color = :blue,label = "Regulated tolerance(case 1)",linestyle=:dash,linewidth=5)
# plot!(plotdata_strat1[p].optimalM .* (1-transparam.ϵS),color = :blue,label = "",linewidth=5,linestyle=:dash)

# plot!(plotdata_strat2[p].optimalM,color = :black,label = "Optimal contract(case 2)",linewidth=4.5)
# plot!(plotdata_strat2[p].optimalM .* (1+transparam.ϵU),color = :black,label = "Regulated tolerance(case 2)",linestyle=:dash,linewidth=5)
# plot!(plotdata_strat2[p].optimalM .* (1-transparam.ϵS),color = :black,label = "",linewidth=5,linestyle=:dash)

# xlabel!("Months")
# ylabel!("MW")

# title!("Cenários de máxima injeção mensal - "*con*" "*peaksnames[p])
# savefig(joinpath("C:\\Users\\erica\\OneDrive\\Projetos P&D\\Artigos\\MUST\\img","cenarios_MUST_Fronteira_2postounico.png"))
