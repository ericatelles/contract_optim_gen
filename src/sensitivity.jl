""" Function of tariff demand contratct sensitivity tariff_in_analisys"""
function tariff_sensitivity(tariff_in_analisys::String, initial_value::Float64, final_value::Float64, step::Float64, optimparam::OptimParameters, 
        busdata::Dict, transparam::TransGeneralParam, dimensions::Dimensions)

    # Optimization loop
    optimalresults_sensitivity  = Dict()
    optimalcontract_sensitivity = Dict()
    riskindicators_sensitivity  = Dict()
    plotdatamw_sensitivity      = Dict()
    plotdatapercent_sensitivity = Dict()
       
    count = 0

    @info("Beginning of tariff sensitivity anallysis")
    @info("Tariff range: minimum $initial_value, step $step, maximum $final_value")

    for tariff in initial_value:step:final_value
        # Iteration counter
        count += 1

        # Tariff change
        for con in transparam.busnames
            if tariff_in_analisys == "regular"
                for p in optimparam.peaksid
                    busdata[con][p].T_T = ones(length(busdata[con][p].T_T)) .* tariff
                end
                
            elseif tariff_in_analisys == "undercontracting"
                for p in optimparam.peaksid
                    busdata[con][p].T_U = ones(length(busdata[con][p].T_U)) .* tariff
                end

            elseif tariff_in_analisys == "overcontracting"
                for p in optimparam.peaksid
                    busdata[con][p].T_S = ones(length(busdata[con][p].T_S)) .* tariff
                end
            elseif tariff_in_analisys == "uncertainty_range"
                for p in optimparam.peaksid
                    busdata[con][p].T_rangeU = ones(length(busdata[con][p].T_rangeU)) .* tariff
                    busdata[con][p].T_rangeS = ones(length(busdata[con][p].T_rangeS)) .* tariff
                end
            end
        end

            # Optimization for the current tariff value
        optimalresults, optimalcontract, riskindicators, plotdatamw, plotdatapercent = optimizecontract(transparam,dimensions,optimparam,busdata; VERBOSE = false)
        optimalresults_sensitivity[count]  = optimalresults
        optimalcontract_sensitivity[count] = optimalcontract
        riskindicators_sensitivity[count]  = riskindicators
        plotdatamw_sensitivity[count]      = plotdatamw
        plotdatapercent_sensitivity[count] = plotdatapercent

        @info("Tariff in analysis: $tariff")
    end

    return optimalresults_sensitivity, optimalcontract_sensitivity, riskindicators_sensitivity, plotdatamw_sensitivity, plotdatapercent_sensitivity, optimparam, transparam

end

    """ Function of tariff demand contratct sensitivity tariff_in_analisys"""
    function risk_sensitivity(initial_value::Float64, final_value::Float64, step::Float64, optimparam::OptimParameters, 
        busdata::Dict, transparam::TransGeneralParam, dimensions::Dimensions)

        # Optimization loop
        optimalresults_risk  = Dict()
        optimalcontract_risk = Dict()
        riskindicators_risk  = Dict()
        plotdatamw_risk      = Dict()
        plotdatapercent_risk = Dict()
        
        count = 0

        @info("Beginning of risk sensitivity analysis")
        @info("Risk parameter range: minimum $initial_value, step $step, maximum $final_value")

        for risk in initial_value:step:final_value
            # Iteration counter
            count += 1

            # Tariff change
            for con in transparam.busnames, p in optimparam.peaksid
                busdata[con][p].μ_underpenalty = ones(length(busdata[con][p].μ_underpenalty)) .* risk
            end
                
            # Optimization for the current risk value
            optimalresults, optimalcontract, riskindicators, plotdatamw, plotdatapercent = optimizecontract(transparam,dimensions,optimparam,busdata; VERBOSE = false)

            optimalresults_risk[count]  = optimalresults
            optimalcontract_risk[count] = optimalcontract
            riskindicators_risk[count]  = riskindicators
            plotdatamw_risk[count]      = plotdatamw
            plotdatapercent_risk[count] = plotdatapercent

            @info("Risk parameter in analysis: $risk")
        end

        return optimalresults_risk, optimalcontract_risk, riskindicators_risk, plotdatamw_risk, plotdatapercent_risk, optimparam, transparam
    end

    """ Function of tariff demand contratct sensitivity tariff_in_analisys"""
    function risk_fobj_sensitivity(initial_value::Float64, final_value::Float64, step::Float64, optimparam::OptimParameters, 
        busdata::Dict, transparam::TransGeneralParam, dimensions::Dimensions)

        # Optimization loop
        optimalresults_risk  = Dict()
        optimalcontract_risk = Dict()
        riskindicators_risk  = Dict()
        plotdatamw_risk      = Dict()
        plotdatapercent_risk = Dict()
        
        count = 0

        @info("Beginning of risk sensitivity analysis for the objective function")
        @info("Risk parameter range: minimum $initial_value, step $step, maximum $final_value")

        for risk in initial_value:step:final_value
            # Iteration counter
            count += 1

            # Tariff change
            for con in transparam.busnames, p in optimparam.peaksid
                optimparam.λ = risk
                busdata[con][p].μ_underpenalty .= 100.0
            end
                
            # Optimization for the current risk value
            optimalresults, optimalcontract, riskindicators, plotdatamw, plotdatapercent = optimizecontract(transparam,dimensions,optimparam,busdata; VERBOSE = false)

            optimalresults_risk[count]  = optimalresults
            optimalcontract_risk[count] = optimalcontract
            riskindicators_risk[count]  = riskindicators
            plotdatamw_risk[count]      = plotdatamw
            plotdatapercent_risk[count] = plotdatapercent

            @info("Risk parameter in analysis: $risk")
        end

        return optimalresults_risk, optimalcontract_risk, riskindicators_risk, plotdatamw_risk, plotdatapercent_risk, optimparam, transparam
    end

""" Function to plot sensitivity graph """
function plot_tariff_sensitivity(param_path::String, study_name::String, tariff_in_analisys::String, 
    initial_value::Float64, final_value::Float64, step::Float64, optimalcontract_sensitivity::Dict, 
    plotdatamw_sensitivity::Dict, optimparam::OptimParameters, busdata::Dict, transparam::TransGeneralParam, peaksnames::Dict,
    riskindicators_sensitivity::Dict, month::Int64, year::Int64, dimensions::Dimensions)

    # Array organization
    # Optimal contract
    step_id         = collect(initial_value:step:final_value)
    
    for p in optimparam.peaksid, con in transparam.busnames, k in optimparam.topologyid
        contract                = zeros(length(step_id))
        fixed_tol_up            = zeros(length(step_id))
        fixed_tol_down          = zeros(length(step_id))
        gen_tol_up              = zeros(length(step_id))
        gen_tol_down            = zeros(length(step_id))
        range_up                = zeros(length(step_id))
        range_down              = zeros(length(step_id))
        worst_scen_total_cost   = zeros(length(step_id))
        worst_scen_under_cost   = zeros(length(step_id))
        worst_scen_over_cost    = zeros(length(step_id))
        cvar_scen_total_cost    = zeros(length(step_id))
        cvar_scen_under_cost    = zeros(length(step_id))
        cvar_scen_over_cost     = zeros(length(step_id))
        ev_scen_total_cost      = zeros(length(step_id))
        ev_scen_under_cost      = zeros(length(step_id))
        ev_scen_over_cost       = zeros(length(step_id))
        under_prob              = zeros(length(step_id))
        over_prob               = zeros(length(step_id))

        for i in keys(optimalcontract_sensitivity)
            contract[i]       = optimalcontract_sensitivity[i][con][p].optimalM[month,year]
            fixed_tol_up[i]   = (1+transparam.ϵU) * contract[i]
            fixed_tol_down[i] = (1-transparam.ϵS) * contract[i]
            gen_tol_up[i]     = plotdatamw_sensitivity[i][con][p].penalty[(year-1)*dimensions.nmonths+month]
            gen_tol_down[i]   = plotdatamw_sensitivity[i][con][p].overcont[(year-1)*dimensions.nmonths+month]
            range_up[i]       = gen_tol_up[i] - fixed_tol_up[i]
            range_down[i]     = fixed_tol_down[i] - gen_tol_down[i]

            worst_scen_total_cost[i]    = riskindicators_sensitivity[i][con][p].worstscen_totalcost[year]
            worst_scen_under_cost[i]    = riskindicators_sensitivity[i][con][p].worstscen_penaltycost[year]
            worst_scen_over_cost[i]     = riskindicators_sensitivity[i][con][p].worstscen_overcontcost[year]
            cvar_scen_total_cost[i]     = riskindicators_sensitivity[i][con][p].CVaR_totalcost[year]
            cvar_scen_under_cost[i]     = riskindicators_sensitivity[i][con][p].CVaR_penaltycost[year]
            cvar_scen_over_cost[i]      = riskindicators_sensitivity[i][con][p].CVaR_overcontcost[year]
            ev_scen_total_cost[i]       = riskindicators_sensitivity[i][con][p].E_totalcost[year]
            ev_scen_under_cost[i]       = riskindicators_sensitivity[i][con][p].E_penaltycost[year]
            ev_scen_over_cost[i]        = riskindicators_sensitivity[i][con][p].E_overcontcost[year]
            under_prob[i]               = riskindicators_sensitivity[i][con][p].penaltyprob[(year-1)*dimensions.nmonths+month]
            over_prob[i]                = riskindicators_sensitivity[i][con][p].overcontprob[(year-1)*dimensions.nmonths+month]
        end

        # Plot general settings
        # =========================================
        # contracts plots
        xticks_plot     = collect(initial_value:2*step:final_value)
        xticks_original = collect(0:2:length(step_id)-1)

        linewdt_1 = 0.8
        linewdt_2 = 1.2
        fontsize_plot = 15

        fig  = figure(figsize=(10,10))
        plt1 = plot(contract, color = "blue",label = "Optimal contract", linewidth=linewdt_2)
        if optimparam.flextolflag == 1
            pl2 = plot(gen_tol_up, color = "#cc7000",label = "Penalty limits", linewidth=linewdt_2)
            pl3 = plot(gen_tol_down, color = "#cc7000", linewidth=linewdt_2)
        end

        plt4 = plot(fixed_tol_up, color = "blue",label = "Regulated tolerance", linewidth=linewdt_2, linestyle="dashed")
        plt5 = plot(fixed_tol_down, color = "blue", linewidth=linewdt_2, linestyle="dashed")
        plt6 = axhline(y=maximum(busdata[con][p].f[k][(year-1)*dimensions.nmonths+month,:]), color = "black",label = "Max. and min. demand scenarios", linewidth=linewdt_2)
        plt7 = axhline(y=minimum(busdata[con][p].f[k][(year-1)*dimensions.nmonths+month,:]), color = "black", linewidth=linewdt_2)
        plt8 = axhline(y=quantile(busdata[con][p].f[k][(year-1)*dimensions.nmonths+month,:],0.95), color = "gray",label = "95%, 50% and 5% demand quantiles", linewidth=linewdt_2)
        plt9 = axhline(y=quantile(busdata[con][p].f[k][(year-1)*dimensions.nmonths+month,:],0.5), color = "gray", linewidth=linewdt_2)
        plt10 = axhline(y=quantile(busdata[con][p].f[k][(year-1)*dimensions.nmonths+month,:],0.05), color = "gray", linewidth=linewdt_2)

        if tariff_in_analisys == "undercontracting"
            xlabel("Undercontracting Tariff \$/MW", fontsize=fontsize_plot)
        elseif tariff_in_analisys == "overcontracting"
            xlabel("Overcontracting Tariff \$/MW", fontsize=fontsize_plot)
        elseif tariff_in_analisys == "uncertainty_range"
            xlabel("Uncertainty Range Tariff \$/MW", fontsize=fontsize_plot)
        end

        ylabel("MW", fontsize=fontsize_plot);

        xticks(ticks=xticks_original, labels=xticks_plot)
        legend(ncol=2, loc=4, fontsize=fontsize_plot,frameon=false)
        xlim(xmin=0)
        ylim(ymin=50.0)
        tick_params(axis="both", labelsize=fontsize_plot)

        out_path = joinpath(param_path, "Resultados", "$study_name", "$con", "tariff_sensitivity")
        mkpath(out_path)

        savefig(joinpath(out_path,"tariff_sensitivity_$tariff_in_analisys$con$(peaksnames[p]).png"), dpi=300, bbox_inches="tight")

        # display(gcf())
    end

    return nothing
end

""" Function to plot sensitivity graph """
function plot_risk_sensitivity(param_path::String, study_name::String, 
        initial_value::Float64, final_value::Float64, step::Float64, optimalcontract_risk::Dict, 
        plotdatamw_risk::Dict, optimparam::OptimParameters, busdata::Dict, transparam::TransGeneralParam, peaksnames::Dict,
        riskindicators_risk::Dict, month::Int64, year::Int64, dimensions::Dimensions)
    
    # Array organization
    # Optimal contract
    step_id                         = collect(initial_value:step:final_value)
    param_ticks                    = collect(1:1:length(step_id))

    for p in optimparam.peaksid, con in transparam.busnames, k in optimparam.topologyid
        contract                = zeros(length(step_id))
        fixed_cost              = zeros(length(step_id))
        range_cost              = zeros(length(step_id))
        fixed_tol_up            = zeros(length(step_id))
        fixed_tol_down          = zeros(length(step_id))
        gen_tol_up              = zeros(length(step_id))
        gen_tol_down            = zeros(length(step_id))
        range_up                = zeros(length(step_id))
        range_down              = zeros(length(step_id))
        worst_scen_total_cost   = zeros(length(step_id))
        worst_scen_under_cost   = zeros(length(step_id))
        worst_scen_over_cost    = zeros(length(step_id))
        cvar_scen_total_cost    = zeros(length(step_id))
        cvar_scen_under_cost    = zeros(length(step_id))
        cvar_scen_over_cost     = zeros(length(step_id))
        ev_scen_total_cost      = zeros(length(step_id))
        ev_scen_under_cost      = zeros(length(step_id))
        ev_scen_over_cost       = zeros(length(step_id))
        under_prob              = zeros(length(step_id))
        over_prob               = zeros(length(step_id))

        for i in keys(optimalcontract_risk)
            contract[i]       = optimalcontract_risk[i][con][p].optimalM[month,year]
            fixed_cost[i]     = 12 * (busdata[con][p].T_T[1] .* contract[i])
            range_cost[i]     = sum(optimalcontract_risk[i][con][p].CMR)
            fixed_tol_up[i]   = (1+transparam.ϵU) * contract[i]
            fixed_tol_down[i] = (1-transparam.ϵS) * contract[i]
            gen_tol_up[i]     = plotdatamw_risk[i][con][p].penalty[(year-1)*dimensions.nmonths+month]
            gen_tol_down[i]   = plotdatamw_risk[i][con][p].overcont[(year-1)*dimensions.nmonths+month]
            range_up[i]       = gen_tol_up[i] - fixed_tol_up[i]
            range_down[i]     = fixed_tol_down[i] - gen_tol_down[i]

            worst_scen_total_cost[i]    = riskindicators_risk[i][con][p].worstscen_totalcost[year]
            worst_scen_under_cost[i]    = riskindicators_risk[i][con][p].worstscen_penaltycost[year]
            worst_scen_over_cost[i]     = riskindicators_risk[i][con][p].worstscen_overcontcost[year]
            cvar_scen_total_cost[i]     = riskindicators_risk[i][con][p].CVaR_totalcost[year]
            cvar_scen_under_cost[i]     = riskindicators_risk[i][con][p].CVaR_penaltycost[year]
            cvar_scen_over_cost[i]      = riskindicators_risk[i][con][p].CVaR_overcontcost[year]
            ev_scen_total_cost[i]       = riskindicators_risk[i][con][p].E_totalcost[year]
            ev_scen_under_cost[i]       = riskindicators_risk[i][con][p].E_penaltycost[year]
            ev_scen_over_cost[i]        = riskindicators_risk[i][con][p].E_overcontcost[year]
            under_prob[i]               = riskindicators_risk[i][con][p].penaltyprob[(year-1)*dimensions.nmonths+month]
            over_prob[i]                = riskindicators_risk[i][con][p].overcontprob[(year-1)*dimensions.nmonths+month]
        end

        # =========================================
        # contracts plots
        xticks_plot     = collect(initial_value:2*step:final_value)
        xticks_original = collect(0:2:length(step_id)-1)
            
        linewdt_1 = 0.8
        linewdt_2 = 1.2
        fontsize_plot = 15

        fig  = figure(figsize=(10,10))
        plt1 = plot(contract, color = "blue",label = "Optimal contract", linewidth=linewdt_2)
        plt2 = plot(fixed_tol_up, color = "blue",label = "Regulated tolerance", linewidth=linewdt_2, linestyle="dashed")
        plt3 = plot(fixed_tol_down, color = "blue", linewidth=linewdt_2, linestyle="dashed")

        if optimparam.flextolflag == 1
            plt4 = plot(gen_tol_up, color = "#cc7000",label = "Penalty limits")
            plt5 = plot(gen_tol_down, color = "#cc7000")
        end
            
        plt6 = axhline(maximum(busdata[con][p].f[k][(year-1)*dimensions.nmonths+month,:]), color = "black",label = "Max and min scenarios", linewidth=linewdt_2)
        plt7 = axhline(minimum(busdata[con][p].f[k][(year-1)*dimensions.nmonths+month,:]), color = "black", linewidth=linewdt_2)
        plt8 = axhline(quantile(busdata[con][p].f[k][(year-1)*dimensions.nmonths+month,:],0.95), color = "gray",label = "95%, 50% and 5% demand quantiles", linewidth=linewdt_2)
        plt9 = axhline(quantile(busdata[con][p].f[k][(year-1)*dimensions.nmonths+month,:],0.5), color = "gray", linewidth=linewdt_2)
        plt10 = axhline(quantile(busdata[con][p].f[k][(year-1)*dimensions.nmonths+month,:],0.05), color = "gray", linewidth=linewdt_2)

        xlabel("Undercontracting Risk Parameter", fontsize=fontsize_plot);
        ylabel("MW", fontsize=fontsize_plot);
        xlim(xmin=0)
        ylim(ymin=0.0)

        xticks(ticks=xticks_original, labels=xticks_plot)
        legend(ncol=2, loc=3, fontsize=fontsize_plot,frameon=false)
        tick_params(axis="both", labelsize=fontsize_plot)

        # display(gcf())

        # Save plots in .png
        out_path = joinpath(param_path, "Resultados", "$study_name", "$con", "risk_sensitivity")
        mkpath(out_path)

        savefig(joinpath(out_path,"risk_sensitivity_$con$(peaksnames[p]).png"), dpi=300, bbox_inches="tight")
            
        # ====================================================
        # Total cost plots
        xticks_plot     = collect(initial_value:2*step:final_value)
        xticks_original = collect(0:2:length(step_id)-1)

        fig  = figure(figsize=(10,10))

        plt1 = plot(fixed_cost, color = "blue", label = "Fixed cost", linewidth=linewdt_2)
        plt2 = plot(range_cost, color = "#cc7000", label = "Uncertainty range cost", linewidth=linewdt_2)
        plt3 = plot(worst_scen_total_cost, color = "red", label = "Total cost worst scenario", linewidth=linewdt_2)
        plt4 = plot(cvar_scen_total_cost, color = "purple", label = "Total cost CVaR", linewidth=linewdt_2)
        plt5 = plot(ev_scen_total_cost, color = "green", label = "Total cost expected value", linewidth=linewdt_2)
        plt6 = scatter([],[], color = "black", label = "Undercontracting probability", marker = "D")

        xlabel("Undercontracting Risk Parameter", fontsize=fontsize_plot);
        ylabel("Cost", fontsize=fontsize_plot);
        xlim(xmin=0)
        ylim(ymin=0.0)
        ylim(ymax=1800.0)

        xticks(ticks=xticks_original, labels=xticks_plot)
        legend(ncol=2, loc=3, fontsize=fontsize_plot,frameon=false)
        tick_params(axis="both", labelsize=fontsize_plot)

        # Eixo de probabilidade
        ax2 = twinx()
        ylabel("Probability(%)", fontsize=fontsize_plot)
        plt6 = scatter(collect(0:1:length(step_id)-1),round.(100 .*under_prob; digits=2), color = "black", marker = "D")

        xticks(ticks=xticks_original, labels=xticks_plot)
        tick_params(axis="both", labelsize=fontsize_plot)

        # display(gcf())

        # Save plots in .png
        out_path = joinpath(param_path, "Resultados", "$study_name", "$con", "risk_sensitivity")
        mkpath(out_path)

        savefig(joinpath(out_path,"totalcost_risk_$con$(peaksnames[p]).png"), dpi=300, bbox_inches="tight")
    end    
    return nothing
end

    """ Function to plot sensitivity graph """
function plot_risk_fobj_sensitivity(param_path::String, study_name::String, 
        initial_value::Float64, final_value::Float64, step::Float64, optimalcontract_risk::Dict, 
        plotdatamw_risk::Dict, optimparam::OptimParameters, busdata::Dict, transparam::TransGeneralParam, peaksnames::Dict,
        riskindicators_risk::Dict, month::Int64, year::Int64, dimensions::Dimensions)
    
    # Array organization
    # Optimal contract
    step_id                         = collect(initial_value:step:final_value)
    param_ticks                    = collect(1:1:length(step_id))

    for p in optimparam.peaksid, con in transparam.busnames, k in optimparam.topologyid
        contract                = zeros(length(step_id))
        fixed_cost              = zeros(length(step_id))
        range_cost              = zeros(length(step_id))
        fixed_tol_up            = zeros(length(step_id))
        fixed_tol_down          = zeros(length(step_id))
        gen_tol_up              = zeros(length(step_id))
        gen_tol_down            = zeros(length(step_id))
        range_up                = zeros(length(step_id))
        range_down              = zeros(length(step_id))
        worst_scen_total_cost   = zeros(length(step_id))
        worst_scen_under_cost   = zeros(length(step_id))
        worst_scen_over_cost    = zeros(length(step_id))
        cvar_scen_total_cost    = zeros(length(step_id))
        cvar_scen_under_cost    = zeros(length(step_id))
        cvar_scen_over_cost     = zeros(length(step_id))
        ev_scen_total_cost      = zeros(length(step_id))
        ev_scen_under_cost      = zeros(length(step_id))
        ev_scen_over_cost       = zeros(length(step_id))
        under_prob              = zeros(length(step_id))
        over_prob               = zeros(length(step_id))

        for i in keys(optimalcontract_risk)
            contract[i]       = optimalcontract_risk[i][con][p].optimalM[month,year]
            fixed_cost[i]     = 12 * (busdata[con][p].T_T[1] .* contract[i])
            range_cost[i]     = sum(optimalcontract_risk[i][con][p].CMR)
            fixed_tol_up[i]   = (1+transparam.ϵU) * contract[i]
            fixed_tol_down[i] = (1-transparam.ϵS) * contract[i]
            gen_tol_up[i]     = plotdatamw_risk[i][con][p].penalty[(year-1)*dimensions.nmonths+month]
            gen_tol_down[i]   = plotdatamw_risk[i][con][p].overcont[(year-1)*dimensions.nmonths+month]
            range_up[i]       = gen_tol_up[i] - fixed_tol_up[i]
            range_down[i]     = fixed_tol_down[i] - gen_tol_down[i]

            worst_scen_total_cost[i]    = riskindicators_risk[i][con][p].worstscen_totalcost[year]
            worst_scen_under_cost[i]    = riskindicators_risk[i][con][p].worstscen_penaltycost[year]
            worst_scen_over_cost[i]     = riskindicators_risk[i][con][p].worstscen_overcontcost[year]
            cvar_scen_total_cost[i]     = riskindicators_risk[i][con][p].CVaR_totalcost[year]
            cvar_scen_under_cost[i]     = riskindicators_risk[i][con][p].CVaR_penaltycost[year]
            cvar_scen_over_cost[i]      = riskindicators_risk[i][con][p].CVaR_overcontcost[year]
            ev_scen_total_cost[i]       = riskindicators_risk[i][con][p].E_totalcost[year]
            ev_scen_under_cost[i]       = riskindicators_risk[i][con][p].E_penaltycost[year]
            ev_scen_over_cost[i]        = riskindicators_risk[i][con][p].E_overcontcost[year]
            under_prob[i]               = riskindicators_risk[i][con][p].penaltyprob[(year-1)*dimensions.nmonths+month]
            over_prob[i]                = riskindicators_risk[i][con][p].overcontprob[(year-1)*dimensions.nmonths+month]
        end

        # =========================================
        # contracts plots
        xticks_plot     = collect(initial_value:2*step:final_value)
        xticks_original = collect(0:2:length(step_id)-1)
            
        linewdt_1 = 0.8
        linewdt_2 = 1.2
        fontsize_plot = 15

        fig  = figure(figsize=(10,10))
        plt1 = plot(contract, color = "blue",label = "Optimal contract", linewidth=linewdt_2)
        plt2 = plot(fixed_tol_up, color = "blue",label = "Regulated tolerance", linewidth=linewdt_2, linestyle="dashed")
        plt3 = plot(fixed_tol_down, color = "blue", linewidth=linewdt_2, linestyle="dashed")

        if optimparam.flextolflag == 1
            plt4 = plot(gen_tol_up, color = "#cc7000",label = "Penalty limits")
            plt5 = plot(gen_tol_down, color = "#cc7000")
        end
            
        plt6 = axhline(maximum(busdata[con][p].f[k][(year-1)*dimensions.nmonths+month,:]), color = "black",label = "Max and min scenarios", linewidth=linewdt_2)
        plt7 = axhline(minimum(busdata[con][p].f[k][(year-1)*dimensions.nmonths+month,:]), color = "black", linewidth=linewdt_2)
        plt8 = axhline(quantile(busdata[con][p].f[k][(year-1)*dimensions.nmonths+month,:],0.95), color = "gray",label = "95%, 50% and 5% demand quantiles", linewidth=linewdt_2)
        plt9 = axhline(quantile(busdata[con][p].f[k][(year-1)*dimensions.nmonths+month,:],0.5), color = "gray", linewidth=linewdt_2)
        plt10 = axhline(quantile(busdata[con][p].f[k][(year-1)*dimensions.nmonths+month,:],0.05), color = "gray", linewidth=linewdt_2)

        xlabel("Objective Function Risk Parameter", fontsize=fontsize_plot)
        ylabel("MW", fontsize=fontsize_plot)
        xlim(xmin=0)
        ylim(ymin=0.0)

        xticks(ticks=xticks_original, labels=xticks_plot)
        legend(ncol=2, loc=3, fontsize=fontsize_plot,frameon=false)
        tick_params(axis="both", labelsize=fontsize_plot)

        # display(gcf())

        # Save plots in .png
        out_path = joinpath(param_path, "Resultados", "$study_name", "$con", "risk_fobj_sensitivity")
        mkpath(out_path)

        savefig(joinpath(out_path,"risk_fobj_sensitivity_$con$(peaksnames[p]).png"), dpi=300, bbox_inches="tight")
            
        # ====================================================
        # Total cost plots
        xticks_plot     = collect(initial_value:2*step:final_value)
        xticks_original = collect(0:2:length(step_id)-1)

        fig  = figure(figsize=(10,10))

        plt1 = plot(fixed_cost, color = "blue", label = "Fixed cost", linewidth=linewdt_2)
        plt2 = plot(range_cost, color = "#cc7000", label = "Uncertainty range cost", linewidth=linewdt_2)
        plt3 = plot(worst_scen_total_cost, color = "red", label = "Total cost worst scenario", linewidth=linewdt_2)
        plt4 = plot(cvar_scen_total_cost, color = "purple", label = "Total cost CVaR", linewidth=linewdt_2)
        plt5 = plot(ev_scen_total_cost, color = "green", label = "Total cost expected value", linewidth=linewdt_2)
        plt6 = scatter([],[], color = "black", label = "Undercontracting probability", marker = "D")

        xlabel("Objective Function Risk Parameter", fontsize=fontsize_plot);
        ylabel("Cost", fontsize=fontsize_plot);
        xlim(xmin=0)
        ylim(ymin=0.0)
        ylim(ymax=1800.0)

        xticks(ticks=xticks_original, labels=xticks_plot)
        legend(ncol=1, loc=3, fontsize=fontsize_plot,frameon=false)
        tick_params(axis="both", labelsize=fontsize_plot)

        # Eixo de probabilidade
        ax2 = twinx()
        ylabel("Probability(%)", fontsize=fontsize_plot)
        plt7 = scatter(collect(0:1:length(step_id)-1),round.(100 .*under_prob; digits=2), color = "black", marker = "D")

        xticks(ticks=xticks_original, labels=xticks_plot)
        tick_params(axis="both", labelsize=fontsize_plot)

        # display(gcf())

        # Save plots in .png
        out_path = joinpath(param_path, "Resultados", "$study_name", "$con", "risk_fobj_sensitivity")
        mkpath(out_path)

        savefig(joinpath(out_path,"totalcost_risk_fobj_$con$(peaksnames[p]).png"), dpi=300, bbox_inches="tight")  
    end
    return nothing
end