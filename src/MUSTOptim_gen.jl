module MUSTOptim_gen
    using JLD, JuMP, Cbc, CSV, DataFrames, DelimitedFiles, Dates, Statistics, PyPlot#, StatsPlots
    
    # Comandos para tratamento de uma issue em aberto para o julia 0.7 ou superior (https://github.com/JuliaIO/JLD.jl/issues/216)
    Core.eval(Main, :(import JLD))
    Core.eval(Main, :(import Dates))

    const SOLVER = Cbc.Optimizer
    
    # Exportações
    export OptimParameters, TransGeneralParam, DistGeneralParam, BusData, OptimalResults, 
        RiskIndicators, PlotDatamw, PlotDatapercent, Dimensions # arquivo structs.jl
    export readintcsv, busdatainit, createbusdata, datesadjust, readplftop, readplf, calculatedim,
        readplfresults, calculateprobtop, readsimresults, readdata, pathinput, open_parametersfile # arquivo readfile.jl
    export optimizeMUST, baseMUSTmodel, filloptimalcont, evaluateMUSTD, optimizecontract  # arquivo optimization.jl
    export calculateCVaR, calculateriskmesur, writeresultscsv # arquivo output.jl
    export plotdatamwconstruct, plotcen, plotcenMUST, plotultrapcenMUST, plotsobreccenMUST,
        plotdatapercentconstruct, plotpercentmonth, plotpercentyear, plotdemvariation # arquivo plots.jl
    export demandcontract, sensitivity_tariff, sensitivity_risk
    export tariff_sensitivity, plot_tariff_sensitivity, risk_sensitivity, plot_risk_sensitivity, risk_fobj_sensitivity, plot_risk_fobj_sensitivity
        
    # Arquivos de funções
    include("structs.jl")
    include("readfile.jl")
    include("optimization.jl")
    include("output.jl")
    include("plots.jl")
    include("sensitivity.jl")


    """ contract(path::String)
    Função principal de execução da contratação ótima do MUST
    Args.:
    path: diretório dos arquivos de parâmetros e de dados de entrada
    """
    function demandcontract(path::String)
        
        # Script de execução
        @info("Início do estudo de contratação do MUST.")

        
        # Definição de regra de peridicidade de contrato
        # "contcicleflag" é uma flag que define se o ciclo contratual será igual ao número de meses de periodicidade do contrato (Flag = 1)(ex: a sobrecontratação é avaliada para cada ciclo de nper meses); 
        # ou se ciclo do contrato é sempre anual e com um ou mais contratos por ano (Flag = 0)(ex: a sobrecontratação é sempre avaliada a cada 12 meses)
        # Para o projeto Energisa MUST será fixada (Flag = 0). Entretanto todo o código está preparado para tratar a contcicleflag = 1.
            
        # Leitura dos arquivos de dados
        dimensions, optimparam, transparam, busdata, peaksnames, study_name = readdata(path)
        
        @info("Leitura de dados completa.")

        # Otimização dos contratos
        optimalresults, optimalcontract, riskindicators, plotdatamw, plotdatapercent = optimizecontract(transparam,dimensions,optimparam,busdata)
        
        # Escrita de saídas
        infotuple = (dimensions, optimparam, peaksnames)

        for con in transparam.busnames # fronteiras de MUST
            # Pasta de saída dos resultados
            out_path = joinpath(path, "Resultados", "$study_name", "$con")
            mkpath(out_path)

            @info("Início da escrita de arquivos de saída para a conexão $con.")

            # Escrita do relatório de sáida
            writeresultscsv(out_path, riskindicators, con, optimparam, dimensions, optimalcontract, peaksnames, transparam)

            # Geração dos gráficos de saída
            plotdatamwtuple = (out_path, con, plotdatamw[con])
            plotdatapercenttuple = (out_path, con, plotdatapercent[con])

            plotcen(infotuple, plotdatamwtuple, transparam)
            # plotcenMUST(infotuple, plotdatamwtuple, transparam)
            # plotpercentmonth(infotuple,plotdatapercenttuple)

            @info("Fim da escrita de arquivos de saída para a conexão $con.")
        end
        
        @info("Fim da execução do módulo de otimização e escrita de arquivos de saída para todas as conexões.")

        return nothing
        
    end

    """ sensitivityanalisys_tariff(path::String, tariffoptions::Array{String}, initialvalue::FLoat64, finalvalue::Float64, step::Float64)
    Performs a tariff sensitivity analisys on tariff values
    Args.:
    path: diretório dos arquivos de parâmetros e de dados de entrada
    """
    function sensitivity_tariff(path::String,tariff_options::Array{String},initial_value::Float64,final_value::Float64,step::Float64, month::Int64, year::Int64)
        for tariff_in_analisys in tariff_options

            dimensions, optimparam, transparam, busdata, peaksnames, study_name = readdata(path)
            
            # Tariff sensitivity study
            optimalresults_sensitivity, optimalcontract_sensitivity, riskindicators_sensitivity, plotdatamw_sensitivity, plotdatapercent_sensitivity, optimparam, transparam = 
                tariff_sensitivity(tariff_in_analisys, initial_value, final_value, step, optimparam, busdata, transparam, dimensions)

            plot_tariff_sensitivity(path, study_name, tariff_in_analisys, initial_value, final_value, step, optimalcontract_sensitivity, plotdatamw_sensitivity, optimparam, 
                busdata, transparam, peaksnames, riskindicators_sensitivity, month, year, dimensions)
        end
    end

    """ sensitivityanalisys_risk(path::String, initialvalue::FLoat64, finalvalue::Float64, step::Float64)
    Performs a tariff sensitivity analisys on risk parameters 
    Args.:
    path: diretório dos arquivos de parâmetros e de dados de entrada
    """
    function sensitivity_risk(path::String,initial_value::Float64,final_value::Float64,step::Float64, month::Int64, year::Int64)
        # Risk sensitivity study
        dimensions, optimparam, transparam, busdata, peaksnames, study_name = readdata(path)

        optimalresults_risk, optimalcontract_risk, riskindicators_risk, plotdatamw_risk, plotdatapercent_risk, optimparam, transparam = risk_sensitivity(initial_value, final_value,
            step, optimparam, busdata, transparam, dimensions)

        plot_risk_sensitivity(path, study_name, initial_value, final_value, step, optimalcontract_risk, plotdatamw_risk, optimparam, busdata, transparam, peaksnames,
            riskindicators_risk, month, year, dimensions)

        # Risk sensitivity objective function study
        dimensions, optimparam, transparam, busdata, peaksnames, study_name = readdata(path)
            
        optimalresults_risk, optimalcontract_risk, riskindicators_risk, plotdatamw_risk, plotdatapercent_risk, optimparam, transparam = risk_fobj_sensitivity(initial_value, final_value,
            step, optimparam, busdata, transparam, dimensions)

        plot_risk_fobj_sensitivity(path, study_name, initial_value, final_value, step, optimalcontract_risk, plotdatamw_risk, optimparam, busdata, transparam, peaksnames,
            riskindicators_risk, month, year, dimensions)
    end
end