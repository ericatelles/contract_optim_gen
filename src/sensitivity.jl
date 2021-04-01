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
            y_interval = ceil((ceil(maximum(busdata[con][p].f[1]))-floor(minimum(busdata[con][p].f[1])))/10)
            if y_interval == 0 y_interval = 1.0 end

            # yticks_base = floor(minimum(busdata[con][p].f[1])):y_interval:ceil(maximum(busdata[con][p].f[1]))+y_interval
            # ylims_base = (floor(minimum(busdata[con][p].f[1])),ceil(maximum(busdata[con][p].f[1]))+y_interval)
            yticks_base = floor(minimum(busdata[con][p].f[1]))-3*y_interval:y_interval:ceil(maximum(busdata[con][p].f[1]))+y_interval
            ylims_base = (floor(minimum(busdata[con][p].f[1]))-3*y_interval,ceil(maximum(busdata[con][p].f[1]))+y_interval)

            tariff_ticks    = collect(1:2:length(initial_value:step:final_value))
            xticks_base = collect(initial_value:2*step:final_value)

            # =========================================
            # contracts plots
            plot(legend=:bottomright, yticks = yticks_base, ylims = ylims_base, foreground_color_legend = nothing)

            # plot!(contract, color = :blue,label = "Contract", xticks = step_id, linewidth=2.5, yticks = yticks_base, ylims =ylims_base)
            plot!(contract, color = :blue,label = "Optimal contract", linewidth=4.5, xticks = (tariff_ticks,xticks_base))

            if optimparam.flextolflag == 1
                plot!(gen_tol_up, color = :orange,label = "Penalty limits", linewidth=4.5)
                plot!(gen_tol_down, color = :orange,label = "", linewidth=4.5)
            end

            plot!(fixed_tol_up, color = :blue,label = "Regulated tolerance", linewidth=4.5, linestyle=:dash)
            plot!(fixed_tol_down, color = :blue,label = "", linewidth=4.5, linestyle=:dash)
            hline!([maximum(busdata[con][p].f[k][(year-1)*dimensions.nmonths+month,:])], color = :black,label = "Max and min scenarios")
            hline!([minimum(busdata[con][p].f[k][(year-1)*dimensions.nmonths+month,:])], color = :black,label = "")
            hline!([quantile(busdata[con][p].f[k][(year-1)*dimensions.nmonths+month,:],0.95)], color = :gray,label = "95%, 50% and 5% demand quantiles")
            hline!([quantile(busdata[con][p].f[k][(year-1)*dimensions.nmonths+month,:],0.5)], color = :gray,label = "")
            hline!([quantile(busdata[con][p].f[k][(year-1)*dimensions.nmonths+month,:],0.05)], color = :gray,label = "")

            if tariff_in_analisys == "undercontracting"
                plot!(xlabel="Undercontracting Tariff \$/MW", ylabel="MW")
            elseif tariff_in_analisys == "overcontracting"
                plot!(xlabel="Overcontracting Tariff \$/MW", ylabel="MW")
            elseif tariff_in_analisys == "uncertainty_range"
                plot!(xlabel="Uncertainty Range Tariff \$/MW", ylabel="MW")
            end

            # Save plots in .png
            out_path = joinpath(param_path, "Resultados", "$study_name", "$con", "tariff_sensitivity")
            mkpath(out_path)

            savefig(joinpath(out_path,"tariff_sensitivity_$tariff_in_analisys$con$(peaksnames[p]).png"))

            
            # =======================================================================
            # Undercontracting penalty cost plots
            # plot(legend=:bottomright)
            # plot!([NaN.*ones(length(step_id)) worst_scen_under_cost cvar_scen_under_cost ev_scen_under_cost], 
            #     color = [:black :red :orange :green],
            #     xticks = (tariff_ticks,step_id),
            #     ylabel = "Undercontracting cost \$",
            #     label = ["Undercontracting probability" "Worst cost scenario" "Cost CVaR" "Cost EV"],
            #     seriestype = [:scatter :line :line :line],
            #     linewidth=2.5, legend=:top)
            
            # if tariff_in_analisys == "undercontracting"
            #     plot!(xlabel="Undercontracting Tariff \$/MW")
            # elseif tariff_in_analisys == "overcontracting"
            #     plot!(xlabel="Overcontracting Tariff \$/MW")
            # elseif tariff_in_analisys == "uncertainty_range"
            #     plot!(xlabel="Uncertainty Range Tariff \$/MW")
            # end

            # scatter!(twinx(), ylabel = "%", round.(100 .*under_prob; digits=2),
            #     xticks = (tariff_ticks,[]),
            #     xlabel = "",
            #     markershape = :circle,
            #     markersize = 6,
            #     markercolor = :black,
            #     markerstrokewidth = 3,
            #     markerstrokealpha = 0.2,
            #     markerstrokecolor = :black,
            #     markerstrokestyle = :dot,legend=:left, label="")     

            # # Save plots in .png
            # out_path = joinpath(param_path, "Resultados", "$study_name", "$con")
            # mkpath(out_path)

            # savefig(joinpath(out_path,"undercost_$tariff_in_analisys$con$(peaksnames[p]).png"))

            # ====================================================
            # Overcontracting penalty cost plots
            # plot(legend=:topleft)
            # plot!([NaN.*ones(length(step_id)) worst_scen_over_cost cvar_scen_over_cost ev_scen_over_cost],
            #     color = [:black :red :orange :green],
            #     xticks = (tariff_ticks,step_id),
            #     ylabel = "Overcontracting cost \$",
            #     label = ["Overcontracting probability" "Worst scenario" "CVaR" "Expected value"],
            #     seriestype = [:scatter :line :line :line],
            #     linewidth=2.5)
            
            # if tariff_in_analisys == "undercontracting"
            #     plot!(xlabel="Undercontracting Tariff \$/MW")
            # elseif tariff_in_analisys == "overcontracting"
            #     plot!(xlabel="Overcontracting Tariff \$/MW")
            # elseif tariff_in_analisys == "uncertainty_range"
            #     plot!(xlabel="Uncertainty Range Tariff \$/MW")
            # end

            # scatter!(twinx(), ylabel = "%", round.(100 .*over_prob; digits=2),
            #     xticks = (tariff_ticks,[]),
            #     xlabel = "",
            #     markershape = :circle,
            #     markersize = 6,
            #     markercolor = :black,
            #     markerstrokewidth = 3,
            #     markerstrokealpha = 0.2,
            #     markerstrokecolor = :black,
            #     markerstrokestyle = :dot,legend=:left, label="")     

            # # Save plots in .png
            # out_path = joinpath(param_path, "Resultados", "$study_name", "$con")
            # mkpath(out_path)

            # savefig(joinpath(out_path,"overcost_$tariff_in_analisys$con$(peaksnames[p]).png"))

            # ====================================================
            # Total cost plots
            # plot(legend=:topleft)
            # plot!([NaN.*ones(length(step_id)) NaN.*ones(length(step_id)) worst_scen_total_cost cvar_scen_total_cost ev_scen_total_cost],
            #     color = [:black :blue :red :orange :green],
            #     xticks = (tariff_ticks,step_id),
            #     ylabel = "Total cost \$",
            #     label = ["Overcontracting probability" "Undercontracting probability" "Worst scenario" "CVaR" "Expected value"],
            #     seriestype = [:scatter :scatter :line :line :line],
            #     linewidth=2.5)
            
            # if tariff_in_analisys == "undercontracting"
            #     plot!(xlabel="Undercontracting Tariff \$/MW")
            # elseif tariff_in_analisys == "overcontracting"
            #     plot!(xlabel="Overcontracting Tariff \$/MW")
            # elseif tariff_in_analisys == "uncertainty_range"
            #     plot!(xlabel="Uncertainty Range Tariff \$/MW")
            # end

            # scatter!(twinx(), ylabel = "%", [round.(100 .*over_prob; digits=2) round.(100 .*under_prob; digits=2)],
            #     xticks = (tariff_ticks,[]),
            #     xlabel = "",
            #     markershape = [:circle :circle],
            #     markersize = 6,
            #     markercolor = [:black :blue],
            #     markerstrokewidth = 3,
            #     markerstrokealpha = 0.2,
            #     markerstrokecolor = [:black :blue],
            #     markerstrokestyle = :dot, label="")     

            # # Save plots in .png
            # out_path = joinpath(param_path, "Resultados", "$study_name", "$con")
            # mkpath(out_path)

            # savefig(joinpath(out_path,"totalcost_$tariff_in_analisys$con$(peaksnames[p]).png"))
            
        end


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
        # plot(legend=:outertopright)

        # plot!(contract, color = :blue,label = "Contract", xticks = step_id, linewidth=2.5, yticks = yticks_base, ylims =ylims_base)
        plot(contract, color = :blue,label = "Contract", linewidth=2.5, xticks = (param_ticks,step_id), foreground_color_legend = nothing)
        plot!(fixed_tol_up, color = :blue,label = "Regulated tolerance", linewidth=3.0, linestyle=:dash)
        plot!(fixed_tol_down, color = :blue,label = "", linewidth=3.0, linestyle=:dash)

        if optimparam.flextolflag == 1
            plot!(gen_tol_up, color = :orange,label = "Penalty limits")
            plot!(gen_tol_down, color = :orange,label = "")
        end
        
        hline!([maximum(busdata[con][p].f[k][(year-1)*dimensions.nmonths+month,:])], color = :black,label = "Max and min scenarios")
        hline!([minimum(busdata[con][p].f[k][(year-1)*dimensions.nmonths+month,:])], color = :black,label = "")
        hline!([quantile(busdata[con][p].f[k][(year-1)*dimensions.nmonths+month,:],0.95)], color = :gray,label = "95%, 50% and 5% demand quantiles")
        hline!([quantile(busdata[con][p].f[k][(year-1)*dimensions.nmonths+month,:],0.5)], color = :gray,label = "")
        hline!([quantile(busdata[con][p].f[k][(year-1)*dimensions.nmonths+month,:],0.05)], color = :gray,label = "")

        plot!(xlabel="Undercontracting Risk Parameter", ylabel="MW")

        # Save plots in .png
        out_path = joinpath(param_path, "Resultados", "$study_name", "$con", "risk_sensitivity")
        mkpath(out_path)

        savefig(joinpath(out_path,"risk_sensitivity_$con$(peaksnames[p]).png"))
            
        # ====================================================
        # Total cost plots
        plot(legend=:bottomright, foreground_color_legend = nothing, right_margin = 40Plots.mm, xrotation = 45)
        plot!([NaN.*ones(length(step_id)) fixed_cost range_cost worst_scen_total_cost cvar_scen_total_cost ev_scen_total_cost],
            color = [:black :blue :orange :red :purple :green],
            xticks = (param_ticks,step_id),
            ylabel = "Cost \$",
            label = ["Undercontracting probability" "Fixed cost" "Uncertainty range cost" "Total cost worst scenario" "Total cost CVaR" "Total cost expected value"],
            seriestype = [:scatter :line :line :line :line :line],
            linewidth=2.5)
            
        plot!(xlabel="Undercontracting Risk Parameter")

        scatter!(twinx(), ylabel = "Probability (%)", [round.(100 .*under_prob; digits=2)],
            xticks = (param_ticks,[]),
            xlabel = "",
            markershape = [:circle],
            markersize = 6,
            markercolor = [:black],
            markerstrokewidth = 3,
            markerstrokealpha = 0.2,
            markerstrokecolor = [:black],
            markerstrokestyle = :dot, label="")     

        # Save plots in .png
        out_path = joinpath(param_path, "Resultados", "$study_name", "$con", "risk_sensitivity")
        mkpath(out_path)

        savefig(joinpath(out_path,"totalcost_risk_$con$(peaksnames[p]).png"))
            
        end


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
        # plot(legend=:outertopright)

        # plot!(contract, color = :blue,label = "Contract", xticks = step_id, linewidth=2.5, yticks = yticks_base, ylims =ylims_base)
        plot(contract, color = :blue,label = "Contract", linewidth=2.5, xticks = (param_ticks,step_id), foreground_color_legend = nothing, right_margin = 40Plots.mm)
        plot!(fixed_tol_up, color = :blue,label = "Regulated tolerance", linewidth=3.0, linestyle=:dash)
        plot!(fixed_tol_down, color = :blue,label = "", linewidth=3.0, linestyle=:dash)

        if optimparam.flextolflag == 1
            plot!(gen_tol_up, color = :orange,label = "Penalty limits")
            plot!(gen_tol_down, color = :orange,label = "")
        end
        
        hline!([maximum(busdata[con][p].f[k][(year-1)*dimensions.nmonths+month,:])], color = :black,label = "Max and min scenarios")
        hline!([minimum(busdata[con][p].f[k][(year-1)*dimensions.nmonths+month,:])], color = :black,label = "")
        hline!([quantile(busdata[con][p].f[k][(year-1)*dimensions.nmonths+month,:],0.95)], color = :gray,label = "95%, 50% and 5% demand quantiles")
        hline!([quantile(busdata[con][p].f[k][(year-1)*dimensions.nmonths+month,:],0.5)], color = :gray,label = "")
        hline!([quantile(busdata[con][p].f[k][(year-1)*dimensions.nmonths+month,:],0.05)], color = :gray,label = "")

        plot!(xlabel="Objective Function Risk Parameter", ylabel="MW")

        # Save plots in .png
        out_path = joinpath(param_path, "Resultados", "$study_name", "$con", "risk_fobj_sensitivity")
        mkpath(out_path)

        savefig(joinpath(out_path,"risk_fobj_sensitivity_$con$(peaksnames[p]).png"))
            
        # ====================================================
        # Total cost plots
        plot(legend=:bottomleft, foreground_color_legend = nothing, right_margin = 50Plots.mm, xrotation = 45)
        plot!([NaN.*ones(length(step_id)) fixed_cost range_cost worst_scen_total_cost cvar_scen_total_cost ev_scen_total_cost],
            color = [:black :blue :orange :red :purple :green],
            xticks = (param_ticks,step_id),
            ylabel = "Cost \$",
            label = ["Undercontracting probability" "Fixed cost" "Uncertainty range cost" "Total cost worst scenario" "Total cost CVaR" "Total cost expected value"],
            seriestype = [:scatter :line :line :line :line :line],
            linewidth=2.5)
            
        plot!(xlabel="Objective Function Risk Parameter")

        scatter!(twinx(), ylabel = "Probability (%)", [round.(100 .*under_prob; digits=2)],
            xticks = (param_ticks,[]),
            xlabel = "",
            markershape = [:circle],
            markersize = 6,
            markercolor = [:black],
            markerstrokewidth = 3,
            markerstrokealpha = 0.2,
            markerstrokecolor = [:black],
            markerstrokestyle = :dot, label="")     

        # Save plots in .png
        out_path = joinpath(param_path, "Resultados", "$study_name", "$con", "risk_fobj_sensitivity")
        mkpath(out_path)

        savefig(joinpath(out_path,"totalcost_risk_fobj_$con$(peaksnames[p]).png"))
            
        end

    end    
    