""" optimalresults, optimalcontract, riskindicators, plotdatamw, plotdatapercent = optimizecontract(transparam::TransGeneralParam,distparam::DistGeneralParam,
    dimensions::Dimensions,optimparam::OptimParameters,busdata::Dict)
Função que executa os modelos de otimização da contratação do MUST retornando os respectivos resultados
Args.:
transparam: estrutura de dados com dados de fronteira com a transmissão
distparam:estrutura de dados com dados de fronteira com a distribuição
dimensions:estrutura de dados com a dimensão do problema
optimparam:estrutura de dados com os parâmetros da otimização
busdata:estrutura de dados com informações característica dos pontos de conexão
"""
function optimizecontract(transparam::TransGeneralParam,dimensions::Dimensions,optimparam::OptimParameters,busdata::Dict; VERBOSE::Bool = true)

    # Dicionários de armazenamento de resultados
    optimalresults  = Dict()
    optimalcontract = Dict()
    riskindicators  = Dict()
    plotdatamw      = Dict()
    plotdatapercent = Dict()

    # Parâmetros fixos
    tol = 10^-7 # Percentual do MUST que caracteriza a seleção de um cenário para uma faixa de custo. Por exemplo, para que ocorra uma ultrapassagem em um mês m, F_m - 1.1MUST > tol*MUST
    
    # MUST
    for con in transparam.busnames
        if optimparam.evaluateflag == 1 # Avaliação de valor fixo de contrato
            # Ajuste do formato da matrix de valores de contrato
            M = Dict(p => Dict(a => Vector{Float64}(undef, dimensions.nper) for a in 1:dimensions.nyear) for p in optimparam.peaksid)
            for p in optimparam.peaksid, a in 1:dimensions.nyear
                M[p][a][1:dimensions.nper] .= busdata[con][p].givenM[a]
            end

            if(VERBOSE) @info("Início da avalição de MUST fixo para a conexão $con.") end

            optimalresults_con, optimalcont_con = evaluateMUSTD(M,con,optimparam,transparam,busdata,dimensions, "must", "Avalição de contrato fixo.", 0.0, tol)

            if(VERBOSE) @info("Avaliação de contrato fixo completa para a conexão $con.") end

        else
            if(VERBOSE) @info("Início da otimização do MUST para a conexão $con.") end

            optimalresults_con, optimalcont_con = optimizeMUST(con,optimparam,transparam,busdata,dimensions, tol)
            
            if(VERBOSE) @info("Otimização do MUST completa para a conexão $con.") end

        end
        
        # Resultados da otimização
        optimalresults[con]  = optimalresults_con
        optimalcontract[con] = optimalcont_con

        # Indicadores de risco dos resultados
        riskind_con = calculateriskmesur(con, optimparam, dimensions, optimalcontract)
        riskindicators[con] = riskind_con

        # Estrutura de dados para saída gráfica
        plotdatamw_con = plotdatamwconstruct(busdata, optimparam, optimalcontract, con, dimensions, transparam)
        plotdatapercent_con = plotdatapercentconstruct(optimparam, optimalcontract, con, dimensions)
    
        plotdatamw[con]      = plotdatamw_con
        plotdatapercent[con] = plotdatapercent_con

    end

    return optimalresults, optimalcontract, riskindicators, plotdatamw, plotdatapercent
end

""" Constrói o dicionário de estruturas OptimalContract por regime tarifário """
function filloptimalcont(vlM::Dict{Int64,Dict{Int64,Vector{Float64}}}, vlCT::Dict{Int64,Array{Float64,4}}, vlCMU::Dict{Int64,Array{Float64,4}},
    vlCF::Dict{Int64,Array{Float64,2}}, vlCR::Dict{Int64,Array{Float64,2}}, vlCMD::Dict{Int64,Array{Float64,4}}, vlCMS::Dict{Int64,Array{Float64,4}}, 
    optimparam::OptimParameters, dimensions::Dimensions, con::String,transparam::TransGeneralParam)

    # Inicialização do dicionário de estruturas OptimalContract (posto tarifário p => estrutura OptimalContract())
    optimalcont_con = Dict{Int64,OptimalContract}()

    # Declaração dos conjuntos de indices fixos
    P = optimparam.peaksid
    Ω = 1:dimensions.nscen
    Months = 1:dimensions.nmonths
    A = 1:dimensions.nyear
    K = optimparam.topologyid

    # Construção do dicionário de estruturas OptimalContract (posto tarifário p => estrutura OptimalContract())
    for p in P

        # Contrato ótimo
        optimalM = Array{Float64}(undef,dimensions.nmonths,dimensions.nyear)
        for m in Months,a in A
            optimalM[m,a] = vlM[p][a][m]
        end

        # Custo total
        C_anual = Array{Float64}(undef,dimensions.nyear,dimensions.nscen,dimensions.ntop) # Custo total anual
        
        for a in A, ω in Ω, k in K # Preenchimento dos custos total e de sobrecontratação por topologia
            C_anual[a,ω,k] = sum(vlCT[p][m,a,ω,k] for m in Months)  
        end
        
        # Preenchimento das grandezas de ocorrência mensal - custo de ultrapassagem, custo de sobrecontratação, custo de máxima demanda, custo da faixa de incerteza, e cenários de ultrapassagem e tolerância
        CMU     = Array{Float64}(undef,dimensions.nyear*dimensions.nmonths,dimensions.nscen,dimensions.ntop) # Inicialização da variável que armazana o custo de penalidade por ultrapassagem mensal (por mês, cenário e topologia)
        CMS     = Array{Float64}(undef,dimensions.nyear*dimensions.nmonths,dimensions.nscen,dimensions.ntop) # Custo de penalidade por sobrecontratação anual
        CMD     = Array{Float64}(undef,dimensions.nyear*dimensions.nmonths,dimensions.nscen,dimensions.ntop) # Inicialização da variável que armazana o custo de máxima demanda mensal (por mês, cenário e topologia)
        CMR     = Array{Float64}(undef,dimensions.nyear*dimensions.nmonths) # Inicialização da variável que armazana o custo de banda de incerteza mensal (por mês)
        C_fixed = Array{Float64}(undef,dimensions.nyear) # Inicialização da variável que armazana o custo fixo mensal (por ano)
        C_mensal = Array{Float64}(undef,dimensions.nyear*dimensions.nmonths,dimensions.nscen,dimensions.ntop) # Custo total mensal

        scen_penalty = Array{Vector{Int64}}(undef,dimensions.nyear*dimensions.nmonths,dimensions.ntop) # Inicialização da variável que armazena o números dos cenários onde há ultrapassagem
        scen_overcont = Array{Vector{Int64}}(undef,dimensions.nyear*dimensions.nmonths,dimensions.ntop) # Inicialização da variável que armazena o números dos cenários onde há sobrecontratação
        scen_tolerance_up = Array{Vector{Int64}}(undef,dimensions.nyear*dimensions.nmonths,dimensions.ntop) # Inicialização da variável que armazena o números dos cenários que ficam na faixa de tolerância de ultrapassagem
        scen_tolerance_dwn = Array{Vector{Int64}}(undef,dimensions.nyear*dimensions.nmonths,dimensions.ntop) # Inicialização da variável que armazena o números dos cenários que ficam na faixa de tolerância de ultrapassagem

        for a in A, k in K
            
            # Selecao dos cenarios onde há ultrapassagem
            if optimparam.flextolflag == 1 # para contratos de MUST usar dados da estrutura transparam
                factor = transparam.ϵU.+transparam.ϵU_gen[con][p][a]

            elseif optimparam.flextolflag == 0
                factor = ones(length(transparam.ϵU_gen[con][p][a])).*transparam.ϵU
            end

            # Seleção dos cenários com ultrapassagem e localizados na faixas de tolerância
            for m in Months
                scen_penalty[(a-1)*dimensions.nmonths+m,k] = Vector{Int64}()
                scen_overcont[(a-1)*dimensions.nmonths+m,k] = Vector{Int64}()
                scen_tolerance_up[(a-1)*dimensions.nmonths+m,k] = Vector{Int64}()
                scen_tolerance_dwn[(a-1)*dimensions.nmonths+m,k] = Vector{Int64}()
                
                for ω in Ω
                    flag = true

                    # Ultrapassagem
                    if vlCMU[p][m,a,ω,k] > 0.0
                        push!(scen_penalty[(a-1)*dimensions.nmonths+m,k],ω)
                        flag = false
                    end

                    # Tolerância up - Cenário entre o contrato e 110% do contrato
                    if flag
                        if vlCMD[p][m,a,ω,k] > 0.0
                            push!(scen_tolerance_up[(a-1)*dimensions.nmonths+m,k],ω)
                            flag = false
                        end
                    end

                    # Sobrecontratação
                    if vlCMS[p][m,a,ω,k] > 0.0
                        push!(scen_overcont[(a-1)*dimensions.nmonths+m,k],ω)
                        flag = false
                    end
                
                    # Torelância down - Cenário entre o 90% do docntrato e o contrato
                    if flag
                        push!(scen_tolerance_dwn[(a-1)*dimensions.nmonths+m,k],ω)
                    end
                end
            end
            
            # Custos de ultrapassagem
            CMU[dimensions.nmonths*(a-1)+1:dimensions.nmonths*a,:,k] = vlCMU[p][1:dimensions.nmonths,a,:,k]

            # Custos de sobrecontratação
            CMS[dimensions.nmonths*(a-1)+1:dimensions.nmonths*a,:,k] = vlCMS[p][1:dimensions.nmonths,a,:,k]

            # Custos de máxima demanda
            CMD[dimensions.nmonths*(a-1)+1:dimensions.nmonths*a,:,k] = vlCMD[p][1:dimensions.nmonths,a,:,k]

            # Custos da banda de incerteza
            CMR[dimensions.nmonths*(a-1)+1:dimensions.nmonths*a] = vlCR[p][1:dimensions.nmonths,a]

            # Custo fixo
            C_fixed[a] = sum(vlCF[p][1:dimensions.nmonths,a])

            # Custo total mensal
            C_mensal[dimensions.nmonths*(a-1)+1:dimensions.nmonths*a,:,k] = vlCT[p][1:dimensions.nmonths,a,:,k]
        end

        optimalcont_con[p] = OptimalContract(optimalM, C_fixed, C_anual, C_mensal, CMU, CMS, CMD, CMR, scen_penalty, scen_overcont, scen_tolerance_up, scen_tolerance_dwn) # Estrutura OptimalContract para o posto tarifario p (chave do dict)
    end

    return optimalcont_con
end

""" Função que avalia um valor dado de contrato """
function evaluateMUSTD(vlM::Dict{Int64,Dict{Int64,Vector{Float64}}},con::String,optimparam::OptimParameters,transparam::TransGeneralParam,busdata::Dict,
    dimensions::Dimensions, id::String, status::String, objfun::Float64, tol::Float64)
       
    # Declaração dos conjuntos de indices fixos
    P = optimparam.peaksid
    Ω = 1:dimensions.nscen
    Months = 1:dimensions.nmonths
    A = 1:dimensions.nyear
    K = optimparam.topologyid
    
    # Custo fixo de contrato
    vlCF = Dict(p => Array{Float64}(undef, dimensions.nmonths,dimensions.nyear) for p in P)
    
    for m in Months,a in A,p in P
        vlCF[p][m,a] = vlM[p][a][m] * busdata[con][p].T_T[a]
    end

    # Custo da banda de incerteza
    vlCR = Dict(p => zeros(Float64, dimensions.nmonths,dimensions.nyear) for p in P)
    vldCRU = 0.
    vldCRS = 0.
    
    if optimparam.flextolflag == 1 # com otimização da faixa de tolerância
        
        for m in Months,a in A,p in P
            vldCRU = transparam.ϵU_gen[con][p][a][m] * vlM[p][a][m]
            vldCRS = transparam.ϵS_gen[con][p][a][m] * vlM[p][a][m]

            if vldCRU > vlM[p][a][m] * tol
                vlCR[p][m,a] = vlCR[p][m,a] + vldCRU*busdata[con][p].T_rangeU[a]
            end

            if vldCRS > vlM[p][a][m] * tol
                vlCR[p][m,a] = vlCR[p][m,a] + vldCRS*busdata[con][p].T_rangeS[a]
            end
        end
    end

    # Custo de máxima demanda
    vlCMD = Dict(p =>  Array{Float64}(undef, dimensions.nmonths,dimensions.nyear,dimensions.nscen,length(K)) for p in P)
    vldMD = 0.

    for m in Months,a in A,p in P,ω in Ω, k in K
        vldMD = busdata[con][p].f[k][(dimensions.nmonths*(a-1))+m,ω] - vlM[p][a][m] # montante de demanda que caracteriza a máxima demanda

        if vldMD > vlM[p][a][m] * tol # se o montante é positivo, há custo de máxima demanda. A tolerância de 10^-7 equivale a menos de 1 W (considerando cenário de fluxo em MW), valor a partir do qual o montante é despezível
            vlCMD[p][m,a,ω,k] = vldMD*busdata[con][p].T_T[a]
        else
            vlCMD[p][m,a,ω,k] = 0.
        end
    end

    # Custo de ultrapassagem
    vlCMU = Dict(p => Array{Float64}(undef, dimensions.nmonths,dimensions.nyear,dimensions.nscen,length(K)) for p in P)
    vldU = 0.

    for m in Months,a in A,p in P,ω in Ω, k in K
        if optimparam.flextolflag == 1 # com otimização da faixa de tolerância
            vldU = busdata[con][p].f[k][(dimensions.nmonths*(a-1))+m,ω] - vlM[p][a][m]*(1+transparam.ϵU+transparam.ϵU_gen[con][p][a][m]) # montante de demanda que caracteriza a ultrapassagem

        elseif optimparam.flextolflag == 0 # sem otimizaçãoda faixa de tolerância
            vldU = busdata[con][p].f[k][(dimensions.nmonths*(a-1))+m,ω] - vlM[p][a][m]*(1+transparam.ϵU) # montante de demanda que caracteriza a ultrapassagem

        end

        if vldU > vlM[p][a][m] * tol  # se o montante é positivo, há custo de ultrapassagem. A tole rância de 10^-7 equivale a menos de 1 W (considerando cenário de fluxo em MW), valor a partir do qual o montante é despezível
            vlCMU[p][m,a,ω,k] = vldU*busdata[con][p].T_U[a]
        else
            vlCMU[p][m,a,ω,k] = 0.
        end
    end

    # Custo de sobrecontratação
    vlCMS = Dict(p => zeros(Float64, dimensions.nmonths,dimensions.nyear,dimensions.nscen,length(K)) for p in P)
    
    if optimparam.overcontflag == 1 # só há sobrecontratação nos casos de must e o usuário seleciona se a sobrecontratação deve ser considerada. 1 => há ssobrecontratação, 0 => não há sobrecontratação 
        vldS = 0.

        for m in Months,a in A,p in P,ω in Ω, k in K

            if optimparam.flextolflag == 1 # com otimização da faixa de tolerância
                vldS = vlM[p][a][m]*(1-transparam.ϵS-transparam.ϵS_gen[con][p][a][m]) - (busdata[con][p].f[k][dimensions.nmonths*(a-1)+m,ω]) # montante de demanda que caracteriza a sobrecontratação

            else # sem otimizaçãoda faixa de tolerância
                vldS = vlM[p][a][m]*(1-transparam.ϵS) - (busdata[con][p].f[k][dimensions.nmonths*(a-1)+m,ω]) # montante de demanda que caracteriza a sobrecontratação
            end

            if vldS > vlM[p][a][m] * tol # se o montante é positivo, há custo de máxima demanda. A tolerância de 10^-7 equivale a menos de 1 W (considerando cenário de fluxo em MW), valor a partir do qual o montante é despezível em termos de custo
                vlCMS[p][m,a,ω,k] = vldS*busdata[con][p].T_S[a]
            end
        end
    end

    # Custo total
    vlCT = Dict(p => Array{Float64}(undef,dimensions.nmonths,dimensions.nyear,dimensions.nscen,length(K)) for p in P)

    for m in Months,a in A,p in P,ω in Ω, k in K
        vlCT[p][m,a,ω,k] = vlCF[p][m,a]+vlCR[p][m,a]+vlCMD[p][m,a,ω,k]+vlCMU[p][m,a,ω,k]+vlCMS[p][m,a,ω,k]
    end

    optimalcont_con = filloptimalcont(vlM, vlCT, vlCMU, vlCF, vlCR, vlCMD, vlCMS, optimparam, dimensions, con, transparam)
    optimalresults_con = OptimalResults(objfun,status)

    return optimalresults_con, optimalcont_con
end

""" Função que define o modelo base de otimização do MUST """
function baseMUSTmodel(con::String, busdata::Dict, optimparam::OptimParameters, dimensions::Dimensions, transparam::TransGeneralParam)
    
    # Declaração dos conjuntos de indices fixos
    P = optimparam.peaksid
    Ω = 1:dimensions.nscen
    Months = 1:dimensions.nmonths
    Per = 1:dimensions.nper
    A = 1:dimensions.nyear
    K = optimparam.topologyid
    per_map = Dict(i => Int(ceil(i/(dimensions.nmonths/dimensions.nper))) for i in Months) # mapa dos períodos de contrato em função do mês

    # Tupla de retorno dos conjuntos índices
    sets = (P, Ω, Months, Per, A, K, per_map)
    
    # MODELO MATEMÁTICO
    contract_optim_MUST = Model(solver = CbcSolver())

    # Declaração e Domínio das variáveis de decisão
    @variables contract_optim_MUST begin
        σ[A,P,Ω,K] >= 0
        CT[Months,A,P,Ω,K]
        ztotal[A,P]
        CF[Months,A,P] >= 0
        M[Per,A,P] >= 0
        CMD[Months,A,P,Ω,K] >= 0
        dMD[Months,A,P,Ω,K] >= 0
        costmetric[A,P]
    end

    # Definição do CVaR dos cenários de custo total anual na função objetivo
    @constraint(contract_optim_MUST, cvar_total[a in A,p in P,ω in Ω,k in K],
        σ[a,p,ω,k] >= sum(CT[m,a,p,ω,k] for m in Months) - ztotal[a,p])

    # Definição do custo fixo
    @constraint(contract_optim_MUST, fixed_cost[m in Months,a in A,p in P],
        CF[m,a,p] == M[per_map[m],a,p]*busdata[con][p].T_T[a])

    # Definição do custo de máxima demanda
    @constraint(contract_optim_MUST, maxdem_cost[m in Months,a in A,p in P,ω in Ω, k in K],
        CMD[m,a,p,ω,k] == dMD[m,a,p,ω,k]*busdata[con][p].T_T[a])

    # Regra de faturamento da demanda máxima
    @constraint(contract_optim_MUST, maxdem_def[m in Months,a in A,p in P,ω in Ω,k in K],
        dMD[m,a,p,ω,k] >= busdata[con][p].f[k][(dimensions.nmonths*(a-1))+m,ω] - M[per_map[m],a,p])

    # Combinação convexa entre CVaR e valor esperado
    @constraint(contract_optim_MUST, convexcomb[a in A,p in P],
        costmetric[a,p] == (optimparam.λ*(ztotal[a,p] +
        (1/(1-optimparam.α))*sum(optimparam.probscen*optimparam.probtop[k]*σ[a,p,ω,k] for ω in Ω,k in K))) +
        ((1-optimparam.λ)*sum(optimparam.probscen*optimparam.probtop[k]*sum(CT[m,a,p,ω,k] for m in Months) for ω in Ω,k in K)))

    # Função objetivo - Minimização da métrica de risco
    @objective(contract_optim_MUST, Min, sum(costmetric[a,p] for a in A,p in P))
    
    return contract_optim_MUST, sets

end

""" Funçao de otimização do MUST para uma barra de conexão i considerando a possibilidade de mais de uma topologia """
function optimizeMUST(con::String,optimparam::OptimParameters,transparam::TransGeneralParam,busdata::Dict,dimensions::Dimensions, tol::Float64)

    # MODELO MATEMÁTICO
    contract_optim, (P, Ω, Months, Per, A, K, per_map) = baseMUSTmodel(con, busdata, optimparam, dimensions, transparam)

    # Declaração e Domínio das variáveis de decisão
    @variables contract_optim begin
        σU[Months,A,P,Ω,K] >= 0
        dU[Months,A,P,Ω,K] >= 0
        zU[Months,A,P]
        CMU[Months,A,P,Ω,K] >= 0
        dS[Months,A,P,Ω,K] >= 0
        CMS[Months,A,P,Ω,K] >= 0
        ΔMU[Per,A,P] >= 0
        ΔMS[Per,A,P] >= 0
        CRU[Months,A,P] >= 0
        CRS[Months,A,P] >= 0
    end

    # Definição do custo de ultrapassagem
    @constraint(contract_optim, penU_cost[m in Months,a in A,p in P,ω in Ω, k in K], CMU[m,a,p,ω,k] == dU[m,a,p,ω,k]*busdata[con][p].T_U[a])
    
    # Restrições de limite do CVaR mensal para os cenários de custo de ultrapassagem
    @constraint(contract_optim, cvar_monthU[a in A,m in Months,p in P,ω in Ω,k in K], σU[m,a,p,ω,k] >= (dU[m,a,p,ω,k]*busdata[con][p].T_U[a]) - zU[m,a,p])

    @constraint(contract_optim, lim_cvar_monthU[m in Months,a in A,p in P,k in K], zU[m,a,p] + (1/(1-optimparam.α))*sum(optimparam.probscen*σU[m,a,p,ω,k] for ω in Ω) <=
        busdata[con][p].μ_underpenalty[a]*busdata[con][p].T_T[a]*contract_optim[:M][per_map[m],a,p])

    # Regra de faturamento da ultrapassagem
    if optimparam.flextolflag == 0
        @constraint(contract_optim, penU_def[m in Months,a in A,p in P,ω in Ω, k in K], dU[m,a,p,ω,k] >= busdata[con][p].f[k][(dimensions.nmonths*(a-1))+m,ω] - (contract_optim[:M][per_map[m],a,p]*(1+transparam.ϵU)))
        @constraint(contract_optim, tolU_def[per in Per,a in A,p in P], ΔMU[per,a,p] == 0)
    else
        @constraint(contract_optim, penU_def[m in Months,a in A,p in P,ω in Ω, k in K], dU[m,a,p,ω,k] >= busdata[con][p].f[k][(dimensions.nmonths*(a-1))+m,ω] - (contract_optim[:M][per_map[m],a,p]*(1+transparam.ϵU)+ΔMU[per_map[m],a,p]))
    end

    # Custo da banda de incerteza de ultrapassagem
    @constraint(contract_optim, rangeU_cost[m in Months,a in A,p in P], CRU[m,a,p] == ΔMU[per_map[m],a,p] * busdata[con][p].T_rangeU[a])   

    # Restrições de penalidade por sobrecontratação
    if optimparam.overcontflag == 1 # com sobrecontratação
        # Definição do custo de sobrecontratação
        @constraint(contract_optim, penS_cost[m in Months,a in A,p in P,ω in Ω,k in K], CMS[m,a,p,ω,k] == dS[m,a,p,ω,k] * (busdata[con][p].T_S[a]))

        # Regra de faturamento da sobrecontratação
        if optimparam.flextolflag == 0
            @constraint(contract_optim, penS_def[m in Months, a in A,p in P,ω in Ω,k in K], dS[m,a,p,ω,k] >= contract_optim[:M][per_map[m],a,p]*(1-transparam.ϵS) - 
            busdata[con][p].f[k][(dimensions.nmonths*(a-1))+m,ω])
            @constraint(contract_optim, tolS_def[per in Per,a in A,p in P], ΔMS[per,a,p] == 0)
        else
            @constraint(contract_optim, penS_def[m in Months, a in A,p in P,ω in Ω,k in K], dS[m,a,p,ω,k] >= contract_optim[:M][per_map[m],a,p]*(1-transparam.ϵS) - ΔMS[per_map[m],a,p] - 
            busdata[con][p].f[k][(dimensions.nmonths*(a-1))+m,ω])
        end
    else # sem sobrecontratação
        # Definição do custo de sobrecontratação
        @constraint(contract_optim, penS_cost[m in Months,a in A,p in P,ω in Ω,k in K], CMS[m,a,p,ω,k] == 0)
        @constraint(contract_optim, tolS_def[per in Per,a in A,p in P], ΔMS[per,a,p] == 0)
    end

    # Custo da banda de incerteza de sobrecontratação
    @constraint(contract_optim, rangeS_cost[m in Months,a in A,p in P], CRS[m,a,p] == ΔMS[per_map[m],a,p] * busdata[con][p].T_rangeS[a])

    # Custo total
    @constraint(contract_optim, total_cost[m in Months,a in A,p in P,ω in Ω,k in K],
    contract_optim[:CT][m,a,p,ω,k] == contract_optim[:CF][m,a,p]+contract_optim[:CMD][m,a,p,ω,k]+CMU[m,a,p,ω,k]+CMS[m,a,p,ω,k]+CRS[m,a,p]+CRU[m,a,p])

    # Otimização
    status = solve(contract_optim)

    # Verificação do status da otimização
    # if status != 1
    #     error("O problema não chegou ao ótimo no MUST na conexão $con. Status: $status")
    # end

    # Preenchimento das estruturas OptimalResults e OptimalContract
    objfun = getobjectivevalue(contract_optim)
    
    # Aquisição dos valores ótimos de contrato
    vlM = Dict(p => Dict(a => Vector{Float64}(undef, dimensions.nmonths) for a in 1:dimensions.nyear) for p in optimparam.peaksid)
    vlϵU_gen = Dict(p => Dict(a => Vector{Float64}(undef, dimensions.nmonths) for a in 1:dimensions.nyear) for p in optimparam.peaksid)
    vlϵS_gen = Dict(p => Dict(a => Vector{Float64}(undef, dimensions.nmonths) for a in 1:dimensions.nyear) for p in optimparam.peaksid)
    
    for a in 1:dimensions.nyear, p in optimparam.peaksid, m in 1:dimensions.nmonths
        vlM[p][a][m] = getvalue(contract_optim[:M][per_map[m],a,p])
        vlϵS_gen[p][a][m] = getvalue(contract_optim[:ΔMS][per_map[m],a,p]) / vlM[p][a][m]
        vlϵU_gen[p][a][m] = getvalue(contract_optim[:ΔMU][per_map[m],a,p]) / vlM[p][a][m]
    end

    transparam.ϵU_gen[con] = deepcopy(vlϵU_gen)
    transparam.ϵS_gen[con] = deepcopy(vlϵS_gen)

    optimalresults_con, optimalcont_con = evaluateMUSTD(vlM,con,optimparam,transparam,busdata,dimensions, "must","optimal", objfun, tol)

    return optimalresults_con, optimalcont_con
end













