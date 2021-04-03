"""  Constrói a estrutura PlotDatamw """
function plotdatamwconstruct(busdata::Dict,optimparam::OptimParameters,optimalcontract::Dict,con::String,
    dimensions::Dimensions,transparam::TransGeneralParam)

    Ω = 1:dimensions.nscen
    Months = 1:dimensions.nmonths
    years = 1:dimensions.nyear
    ntotal_months = dimensions.nyear*dimensions.nmonths

    base_plotdatamw = PlotDatamw(
        zeros(ntotal_months),
        zeros(ntotal_months),
        zeros(ntotal_months),
        zeros(ntotal_months,dimensions.nscen*dimensions.ntop),
        Dict(collect(1:dimensions.nyear)[i] => Array{Float64}(undef,0,0) for i=1:dimensions.nyear),
        Dict(collect(1:dimensions.nyear)[i] => Array{Float64}(undef,0,0) for i=1:dimensions.nyear),
        zeros(ntotal_months),
        zeros(ntotal_months),
        zeros(ntotal_months),
        zeros(ntotal_months),
        zeros(ntotal_months),
        Vector{Float64}(undef,0),
        Array{Float64}(undef,0,0),
        zeros(ntotal_months))

    plotdatamw = Dict(optimparam.peaksid[j] => deepcopy(base_plotdatamw) for j=1:dimensions.npeaks)

    # Preenchimento das estruturas
    for p in optimparam.peaksid

        # Dados vindos de outras funções
        # Cenários de máxima demanda
        count = 0
        for k in optimparam.topologyid
            count = count + 1
            plotdatamw[p].f[:,1+dimensions.nscen*(count-1):dimensions.nscen*count] = busdata[con][p].f[k][1:ntotal_months,:]
        end

        # Quantis
        for m in 1:ntotal_months
            # Quantis dos cenários de máxima demanda
            plotdatamw[p].quantile5_f[m] = quantile(plotdatamw[p].f[m,:],0.05,sorted=false)
            plotdatamw[p].quantile50_f[m] = quantile(plotdatamw[p].f[m,:],0.5,sorted=false)
            plotdatamw[p].quantile95_f[m] = quantile(plotdatamw[p].f[m,:],0.95,sorted=false)

            # Cenários de máximo e mínimo
            plotdatamw[p].max_f[m] = maximum(plotdatamw[p].f[m,:])
            plotdatamw[p].min_f[m] = minimum(plotdatamw[p].f[m,:])
        end

        # Dados anuais
        for a in years
            # Contrato ótimo
            plotdatamw[p].optimalM[collect(Months).+(a-1)*dimensions.nmonths] = optimalcontract[con][p].optimalM[:,a]

            # Limite de ultrapassagem
            if optimparam.flextolflag == 1
                plotdatamw[p].penalty[collect(Months).+(a-1)*dimensions.nmonths] = optimalcontract[con][p].optimalM[:,a].*((1+transparam.ϵU).+transparam.ϵU_gen[con][p][a])
                plotdatamw[p].overcont[collect(Months).+(a-1)*dimensions.nmonths] = optimalcontract[con][p].optimalM[:,a].*((1-transparam.ϵS).-transparam.ϵS_gen[con][p][a])
            else
                plotdatamw[p].penalty[collect(Months).+(a-1)*dimensions.nmonths] = optimalcontract[con][p].optimalM[:,a].*(1+transparam.ϵU)
                plotdatamw[p].overcont[collect(Months).+(a-1)*dimensions.nmonths] = optimalcontract[con][p].optimalM[:,a].*(1-transparam.ϵS)
            end
        end

    end

    return plotdatamw
end

"""  Constrói a estrutura PlotDatapercent """
function plotdatapercentconstruct(optimparam::OptimParameters,optimalcontract::Dict,con::String,
    dimensions::Dimensions)

    Ω      = 1:dimensions.nscen
    Months = 1:dimensions.nmonths
    years  = 1:dimensions.nyear
    ntotal_months = dimensions.nyear*dimensions.nmonths

    base_plotdatapercent = PlotDatapercent(
        zeros(ntotal_months),
        zeros(ntotal_months),
        zeros(ntotal_months),
        zeros(ntotal_months))

    plotdatapercent = Dict(optimparam.peaksid[j] => deepcopy(base_plotdatapercent) for j=1:dimensions.npeaks)

    # Seleção da quantidade de cenarios pertencentes a cada faixa e preenchimento das probabilidades - Análise mensal
    for p in optimparam.peaksid
        for m in 1:ntotal_months
            k=1
            plotdatapercent[p].overcont[m] = (length(optimalcontract[con][p].scen_overcont[m,k]) / dimensions.nscen) 
            plotdatapercent[p].tolerance_up[m] = (length(optimalcontract[con][p].scen_tolerance_up[m,k]) / dimensions.nscen)
            plotdatapercent[p].tolerance_dwn[m] = (length(optimalcontract[con][p].scen_tolerance_dwn[m,k]) / dimensions.nscen)
            plotdatapercent[p].penalty[m] = (length(optimalcontract[con][p].scen_penalty[m,k]) / dimensions.nscen)
        end
    end

    return plotdatapercent
end

"""  Plot dos cenários de máxima demanda mensal para um ponto de conexão """
function plotcen(infotuple::Tuple{Dimensions,OptimParameters,Dict},plotdatamwtuple::Tuple{String,String,Dict}, transparam::TransGeneralParam)

    (dimensions,optimparam,peaksnames) = infotuple
    (out_path,con,plotdata) = plotdatamwtuple
        
    # Limites max e min do eixo y
    for p in optimparam.peaksid
        if con == "Fronteira_1"
            xticks_original = [0,11,23,35,47]
            xticks_plot     = [1,12,24,36,48]
        elseif con == "JUPIA-MIMOSO"
            xticks_original = [0,2,5,8,11]
            xticks_plot     = [1,3,6,9,12]
        else
            xticks_original = [0,11,23,35,47]
            xticks_plot     = [1,12,24,36,48]
        end
        linewdt_1 = 0.8
        linewdt_2 = 1.2
        fontsize_plot = 15

        fig  = figure(figsize=(10,10))
        plt1 = plot(plotdata[p].f[:,1], color = "gray",label = "Scenarios", linewidth=linewdt_1)
        plt2 = plot(plotdata[p].f[:,2:end], color = "gray", linewidth=linewdt_1)

        xlabel("Months", fontsize=fontsize_plot);
        ylabel("MW", fontsize=fontsize_plot);
        xlim(xmin=0)
        
        if con == "Fronteira_1"
            ylim(ymin=35.0)
            ylim(ymax=60.0)
            xlim(xmax=47)
        elseif con == "JUPIA-MIMOSO"
            ylim(ymin=40.0)
            xlim(xmax=11)
        else
            ylim(ymin=0.0)
        end

        xticks(ticks=xticks_original, labels=xticks_plot)
        legend(ncol=1, loc=3, fontsize=fontsize_plot,frameon=false)
        tick_params(axis="both", labelsize=fontsize_plot)
        # display(gcf())
        savefig(joinpath(out_path,"cenarios.png"), dpi=300, bbox_inches="tight")

        fig  = figure(figsize=(9,9))
        plt1 = plot(plotdata[p].f[:,1], color = "gray",label = "Scenarios", linewidth=linewdt_1)
        plt2 = plot(plotdata[p].f[:,2:end], color = "gray", linewidth=linewdt_1)
        plt3 = plot(plotdata[p].penalty,color = "#cc7000",label = "Penalty limits" ,linewidth=linewdt_2)
        plt4 = plot(plotdata[p].overcont,color = "#cc7000",linewidth=linewdt_2)
        plt5 = plot(plotdata[p].optimalM,color = "blue",label = "Optimal contract",linewidth=linewdt_2)
        plt6 = plot(plotdata[p].optimalM .* (1+transparam.ϵU),color = "blue",label = "Regulated tolerance",linestyle="dashed",linewidth=linewdt_2)
        plt7 = plot(plotdata[p].optimalM .* (1-transparam.ϵS),color = "blue",linewidth=linewdt_2,linestyle="dashed")

        xlabel("Months", fontsize=fontsize_plot);
        ylabel("MW", fontsize=fontsize_plot);
        xlim(xmin=0)

        if con == "Fronteira_1"
            ylim(ymin=35.0)
            ylim(ymax=60.0)
            xlim(xmax=47)
        elseif con == "JUPIA-MIMOSO"
            ylim(ymin=40.0)
            xlim(xmax=11)
        else
            ylim(ymin=0.0)
        end

        xticks(ticks=xticks_original, labels=xticks_plot)
        legend(ncol=2, loc=3, fontsize=fontsize_plot,frameon=false)
        tick_params(axis="both", labelsize=fontsize_plot)
        # display(gcf())
        savefig(joinpath(out_path,"cenarios_MUST_$con$(peaksnames[p]).png"), dpi=300, bbox_inches="tight")
    end

    return nothing
end

# """  Plot dos cenários de máxima demanda mensal com o MUST ótimo para um ponto de conexão """
# function plotcenMUST(infotuple::Tuple{Dimensions,OptimParameters,Dict},plotdatamwtuple::Tuple{String,String,Dict},transparam::TransGeneralParam)

#     (dimensions,optimparam,peaksnames) = infotuple
#     (out_path,con,plotdata) = plotdatamwtuple
#     xticks_base = 0:2:dimensions.nyear*dimensions.nmonths
    
#     # Limites max e min do eixo y
#     for p in optimparam.peaksid
#         y_interval = ceil((ceil(maximum(plotdata[p].f))-floor(minimum(plotdata[p].f)))/10)
#         if y_interval == 0 
#             y_interval = 1
#         end
        
#         yticks_base = floor(minimum(plotdata[p].f))-4*y_interval:y_interval:ceil(maximum(plotdata[p].f))+y_interval
#         ylims_base = (floor(minimum(plotdata[p].f))-4*y_interval,ceil(maximum(plotdata[p].f))+y_interval)
#         # yticks_base = 0:10:100
#         # ylims_base = (0,100)

#         plot(legend=:bottomright, foreground_color_legend = nothing)
#         plot!(plotdata[p].max_f, color = :blue,label = "Monthly max and min", linestyle=:dot, 
#         xticks = xticks_base, yticks = yticks_base, ylims = ylims_base)
#         plot!(plotdata[p].min_f, color = :blue,label = "", linestyle=:dot)

#         plot!(plotdata[p].quantile95_f, color = :black,label = "5%, 50% and 95% quantiles", linestyle=:dash)
#         plot!(plotdata[p].quantile50_f, color = :black,label = "", linestyle=:dash)
#         plot!(plotdata[p].quantile5_f, color = :black,label = "", linestyle=:dash)

#         xlabel!("Months")
#         ylabel!("MW")

#         plot!(plotdata[p].optimalM,color = :red,label = "Optimal contract",linewidth=2.5)
#         plot!(plotdata[p].penalty,color = :red,label = "Under and overcontracting limits" ,linewidth=2.5, linestyle=:dash)
#         plot!(plotdata[p].overcont,color = :red,label = "" ,linewidth=2.5, linestyle=:dash)
#         plot!(plotdata[p].optimalM .* (1+transparam.ϵU),color = :gray,label = "Regulated tolerance",linewidth=2.5, linestyle=:dash)
#         plot!(plotdata[p].optimalM .* (1-transparam.ϵS),color = :gray,label = "",linewidth=2.5, linestyle=:dash)

#         savefig(joinpath(out_path,"cenariosMUST_$con$(peaksnames[p]).png"))
#     end

#     return nothing
# end

# """  Plot da divisão percentual dos cenários em faixas - Análise mensal """
# function plotpercentmonth(infotuple::Tuple{Dimensions,OptimParameters,Dict},plotdatapercenttuple::Tuple{String,String,Dict})

#     (dimensions,optimparam,peaksnames) = infotuple
#     (out_path,con,plotdatapercent) = plotdatapercenttuple

#     for a in 1:dimensions.nyear, p in optimparam.peaksid
#         if optimparam.overcontflag == 0
#             plotmatrix = [plotdatapercent[p].penalty[1+(a-1)*dimensions.nmonths:a*dimensions.nmonths] plotdatapercent[p].tolerance_up[1+(a-1)*dimensions.nmonths:a*dimensions.nmonths] plotdatapercent[p].tolerance_dwn[1+(a-1)*dimensions.nmonths:a*dimensions.nmonths]]
#             groupedbar(plotmatrix, bar_position = :stack, bar_width=1,xlabel = "Months", ylabel = "Probability",
#                 xlims=(0.5,dimensions.nmonths+0.5),
#                 xticks=1:dimensions.nmonths,
#                 label = ["Undercontracting" "between 100% and 110%" "bellow 100%"],
#                 color = [:red :orange :green])
#         else
#             plotmatrix = [plotdatapercent[p].penalty[1+(a-1)*dimensions.nmonths:a*dimensions.nmonths] plotdatapercent[p].tolerance_up[1+(a-1)*dimensions.nmonths:a*dimensions.nmonths] plotdatapercent[p].tolerance_dwn[1+(a-1)*dimensions.nmonths:a*dimensions.nmonths] plotdatapercent[p].overcont[1+(a-1)*dimensions.nmonths:a*dimensions.nmonths]]
#             groupedbar(plotmatrix, bar_position = :stack, bar_width=1,xlabel = "Months", ylabel = "Probability",
#                 xlims=(0.5,dimensions.nmonths+0.5),
#                 xticks=1:dimensions.nmonths,
#                 label = ["Undercontracting" "between 100% and 110%" "between 100% and 90%" "Overcontracting"],
#                 color = [:red :orange :green :purple])
#         end

#         savefig(joinpath(out_path,"prob_mensal_cenarios_$con$(peaksnames[p])_ano$a.png"))
#     end

#     return nothing
# end

