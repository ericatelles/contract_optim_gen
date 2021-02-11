"""  Cálculos do CVaR para conjunto discreto de valores  """
function calculateCVaR( X, alfa )
    
    X          = sort(X,rev =true)
    n_samples_ = size(X,1)
    qtd        = ceil(Int64, n_samples_*(0.999999-alfa))
    cvar       = sum(X[1:qtd-1])
    cvar       = cvar * (1/(n_samples_*(1-alfa)))
    cvar       = cvar + X[qtd]*(1 -(qtd-1)*(1/(n_samples_*(1-alfa))))

    return cvar
end

""" Calcula indicadores de risco da solução otimizada """
function calculateriskmesur(con::String, optimparam::OptimParameters, dimensions::Dimensions, optimalcontract::Dict)

    # Dicionário de estruturas RiskIndicators por regime tarifário
    riskind_con = Dict{Int64,RiskIndicators}()

    # Declaração dos conjuntos, vetores de indices fixos
    Ω = 1:dimensions.nscen
    K = optimparam.topologyid
    Months = 1:dimensions.nmonths

    for p in optimparam.peaksid
        E_totalcost            = zeros(dimensions.nyear)
        E_penaltycost          = zeros(dimensions.nyear)
        E_overcontcost         = zeros(dimensions.nyear)
        E_maxdemcost           = zeros(dimensions.nyear)
        CVaR_totalcost         = zeros(dimensions.nyear)
        CVaR_penaltycost       = zeros(dimensions.nyear)
        CVaR_overcontcost      = zeros(dimensions.nyear)
        CVaR_maxdemcost        = zeros(dimensions.nyear)
        worstscen_totalcost    = zeros(dimensions.nyear)
        worstscen_penaltycost  = zeros(dimensions.nyear)
        worstscen_overcontcost = zeros(dimensions.nyear)
        worstscen_maxdemcost   = zeros(dimensions.nyear)
        penaltyprob            = zeros(dimensions.nmonths*dimensions.nyear)
        overcontprob           = zeros(dimensions.nmonths*dimensions.nyear)

        for a in 1:dimensions.nyear

            # Valor esperado do custo total e custo de penalidade por ano e posto
            E_totalcost[a]    = sum(optimparam.probscen*optimparam.probtop[k]*optimalcontract[con][p].C_anual[a,ω,k] for ω in Ω, k in K)
            E_penaltycost[a]  = sum(optimparam.probscen*optimparam.probtop[k]*sum(optimalcontract[con][p].CMU[m,ω,k] for m=1+(a-1)*dimensions.nper:a*dimensions.nmonths) for ω in Ω, k in K)
            E_overcontcost[a] = sum(optimparam.probscen*optimparam.probtop[k]*sum(optimalcontract[con][p].CMS[m,ω,k] for m=1+(a-1)*dimensions.nper:a*dimensions.nmonths) for ω in Ω, k in K)
            E_maxdemcost[a]   = sum(optimparam.probscen*optimparam.probtop[k]*sum(optimalcontract[con][p].CMD[m,ω,k] for m=1+(a-1)*dimensions.nper:a*dimensions.nmonths) for ω in Ω, k in K) 

            # CVaR
            vctC_anual = reshape(optimalcontract[con][p].C_anual[a,:,:],:) # Altera os dados da matriz ωXk para um vetor de dimensao ω*k para a funcao "calculateCVaR"
            vctCMU     = reshape(sum(optimalcontract[con][p].CMU[m,:,:] for m=1+(a-1)*dimensions.nper:a*dimensions.nmonths),:) # Altera os dados da matriz ωXk para um vetor de dimensao ω*k para a funcao "calculateCVaR"
            vctCMS     = reshape(sum(optimalcontract[con][p].CMS[a,:,:] for m=1+(a-1)*dimensions.nper:a*dimensions.nmonths),:) # Altera os dados da matriz ωXk para um vetor de dimensao ω*k para a funcao "calculateCVaR"
            vctCMD     = reshape(sum(optimalcontract[con][p].CMD[m,:,:] for m=1+(a-1)*dimensions.nper:a*dimensions.nmonths),:) # Altera os dados da matriz ωXk para um vetor de dimensao ω*k para a funcao "calculateCVaR"

            CVaR_totalcost[a]    = calculateCVaR(vctC_anual,optimparam.α)
            CVaR_penaltycost[a]  = calculateCVaR(vctCMU,optimparam.α)
            CVaR_overcontcost[a] = calculateCVaR(vctCMS,optimparam.α)
            CVaR_maxdemcost[a]   = calculateCVaR(vctCMD,optimparam.α)

            # Pior caso
            worstscen_totalcost[a]    = sort(vctC_anual, rev=true)[1]
            worstscen_penaltycost[a]  = sort(vctCMU, rev=true)[1]
            worstscen_overcontcost[a] = sort(vctCMS, rev=true)[1]
            worstscen_maxdemcost[a]   = sort(vctCMD, rev=true)[1]

            #Probabilidade de penalidade
            for m in Months
                penaltyprob[(a-1)*dimensions.nmonths+m] = sum(length(optimalcontract[con][p].scen_penalty[(a-1)*dimensions.nmonths+m,k]) * (optimparam.probscen*optimparam.probtop[k]) for k in K) # Dentro de uma topologia, os cenários são equiprováveis. Assim a probabilidade de 1 cenário é prob[k], da topologia, multiplicada por probscen dos cenários. 
                overcontprob[(a-1)*dimensions.nmonths+m] = sum(length(optimalcontract[con][p].scen_overcont[(a-1)*dimensions.nmonths+m,k]) * (optimparam.probscen*optimparam.probtop[k]) for k in K)
            end
        end

        riskind_con[p] = RiskIndicators(E_totalcost,E_penaltycost,E_overcontcost,E_maxdemcost,CVaR_totalcost,CVaR_penaltycost,CVaR_overcontcost,
            CVaR_maxdemcost,worstscen_totalcost,worstscen_penaltycost,worstscen_overcontcost,worstscen_maxdemcost,penaltyprob,overcontprob)
    end

    return riskind_con
end

"""  Escreve os resultados da otimização em arquivo .csv """
function writeresultscsv(out_path::String,riskindicators::Dict,con::String,
    optimparam::OptimParameters,dimensions::Dimensions,optimalcontract::Dict,peaksnames::Dict, transparam::TransGeneralParam)

    reportdf = DataFrame(ANO = Int[], MES = Any[], REGIME_TARIFARIO = String[], INDICADOR = String[], VALOR = Float64[])

    for a in 1:dimensions.nyear, p in optimparam.peaksid

        # Contrato ótimo
        push!(reportdf, [a, "-", peaksnames[p], "CONTRATO OTIMO", optimalcontract[con][p].optimalM[a]])

        # Faixa de tolerância ótima de ultrapassagem contratada
        if optimparam.flextolflag == 1
            for m in 1:dimensions.nmonths
                push!(reportdf, [a, m, peaksnames[p], "FAIXA DE TOLERANCIA SOBRECONTRATAÇÃO", transparam.ϵS_gen[con][p][a][m]])
                push!(reportdf, [a, m, peaksnames[p], "FAIXA DE TOLERANCIA ULTRAPASSAGEM", transparam.ϵU_gen[con][p][a][m]])
                push!(reportdf, [a, m, peaksnames[p], "CUSTO DAS FAIXAS DE TOLERANCIA", optimalcontract[con][p].CMR[(a-1)*dimensions.nmonths+m]])
            end
        end

        # Custo fixo
        push!(reportdf, [a, "-", peaksnames[p], "CUSTO FIXO", optimalcontract[con][p].C_fixed[a]])

        # Indicadores de média
        push!(reportdf, [a, "-", peaksnames[p], "MEDIA DO CUSTO TOTAL", riskindicators[con][p].E_totalcost[a]])
        push!(reportdf, [a, "-", peaksnames[p], "MEDIA DO CUSTO DE MAXIMA DEMANDA", riskindicators[con][p].E_maxdemcost[a]])
        push!(reportdf, [a, "-", peaksnames[p], "MEDIA DO CUSTO DE ULTRAPASSAGEM", riskindicators[con][p].E_penaltycost[a]])

        if optimparam.overcontflag == 1# Só escreve indicadores de sobrecontratação se o usuário incluir 
            push!(reportdf, [a, "-", peaksnames[p], "MEDIA DO CUSTO DE SOBRECONTRATACAO", riskindicators[con][p].E_overcontcost[a]])
        end

        # Indicadores de CVaR
        push!(reportdf, [a, "-", peaksnames[p], "CVaR DO CUSTO TOTAL", riskindicators[con][p].CVaR_totalcost[a]])
        push!(reportdf, [a, "-", peaksnames[p], "CVaR DO CUSTO DE MAXIMA DEMANDA", riskindicators[con][p].CVaR_maxdemcost[a]])
        push!(reportdf, [a, "-", peaksnames[p], "CVaR DO CUSTO DE ULTRAPASSAGEM", riskindicators[con][p].CVaR_penaltycost[a]])

        if optimparam.overcontflag == 1 # Só escreve indicadores de sobrecontratação se o usuário incluir
            push!(reportdf, [a, "-", peaksnames[p], "CVaR DO CUSTO DE SOBRECONTRATACAO", riskindicators[con][p].CVaR_overcontcost[a]])
        end

        # Indicadores de PIOR CENÁRIO
        push!(reportdf, [a, "-", peaksnames[p], "PIOR CENARIO DE CUSTO TOTAL", riskindicators[con][p].worstscen_totalcost[a]])
        push!(reportdf, [a, "-", peaksnames[p], "PIOR CENARIO DE CUSTO DE ULTRAPASSAGEM", riskindicators[con][p].worstscen_penaltycost[a]])
        push!(reportdf, [a, "-", peaksnames[p], "PIOR CENARIO DE CUSTO DE MAXIMA DEMANDA", riskindicators[con][p].worstscen_maxdemcost[a]])

        if optimparam.overcontflag == 1 # Só escreve indicadores de sobrecontratação se o usuário incluir ou se for otimização do must
            push!(reportdf, [a, "-", peaksnames[p], "PIOR CENARIO DE CUSTO DE SOBRECONTRATACAO", riskindicators[con][p].worstscen_overcontcost[a]])
        end

        # Indicadores de probabilidade
        push!(reportdf, [a, "-", peaksnames[p], "PROBABILIDADE DE ULTRAPASSAGEM", riskindicators[con][p].penaltyprob[a]])

        if optimparam.overcontflag == 1 # Só escreve indicadores de sobrecontratação se o usuário incluir ou se for otimização do must
            push!(reportdf, [a, "-", peaksnames[p], "PROBABILIDADE DE SOBRECONTRATACAO", riskindicators[con][p].overcontprob[a]])
        end
        
    end

    # Escrita no arquivo
    filepath = joinpath(out_path,"RELATORIO_" * con *".csv")
    CSV.write(filepath,reportdf)

    return nothing
end
