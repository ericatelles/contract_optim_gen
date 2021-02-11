""" Dimensões do problema """
mutable struct Dimensions
    npeaks::Int64 # Número de postos tarifários (geralmente "PONTA" e "FORA PONTA")
    nscen::Int64 # Número de cenários
    nper::Int64 # Número de períodos de contrato dentro do ciclo de contratação
    nmonths::Int64 # Número de meses do ciclo de contratação
    nyear::Int64 # Número de anos
    ntop::Int64 # Número de topologias
end

""" Parâmetros gerais da otimização """
mutable struct OptimParameters
    overcontflag::Int64 # Flag (0 ou 1) que indica se restrições de sobrecontratação devem ser utilizadas ou não no modelo de otimização
    evaluateflag::Int64 # Flag -> 0 - otimização do contrato ; 1 - avaliação de contrato dado
    flextolflag::Int64 # Flag -> 0 - faixa de tolerância para a ultrapassagem fixa ; 1 - faixa de tolerância para a ultrapassagem otimizada
    probscen::Float64 # Probabilidade de ocorrência dos cenários
    probtop::Dict{Int64,Float64} # Probabilidade de ocorrência das topologias de rede (topologia => valor)
    α::Float64 # Nível de confiança do CVaR do custo total
    λ::Float64 # Ponderação entre CVaR e Valor Esperado na função obj de otimização do MUST
    peaksid::Vector{Int64} # Identificação numérica dos postos tarifários
    peaksnames::Dict{Int64,String} # Nome dos postos tarifários
    topologyid::Vector{Int64} # Identificação numérica das topologias
end

""" Parâmetros da otimização com a transmissão """
mutable struct TransGeneralParam
    busnames::Vector{String} # Nomes das barras de fronteira com o sistema de transmissão a serem simuladas
    busid::Vector{Int64} # Código de identificação das fronteiras com a transmissão
    nbuses::Int # Número de barras de fronteira com o sistema de transmissão
    ϵU_gen::Dict{String,Dict{Int64,Dict{Int64,Array{Float64}}}} # Tolerância a contratatar para caracterização de ultrapassagem
    ϵU::Float64 # Tolerância fixa de contrato para caracterização de ultrapassagem
    ϵS_gen::Dict{String,Dict{Int64,Dict{Int64,Array{Float64}}}} # Tolerância a contratatar para caracterização de ultrapassagem
    ϵS::Float64 # Tolerância fixa de contrato para caracterização de sobrecontratação
    ηcont::Float64 # Limite de redução do contrato em relação aos contratos vigentes
end

""" Parâmetros da otimização com a distribuição """
mutable struct DistGeneralParam
    busnames::Vector{String} # Nomes das barras de fronteira com o sistema de distribuição a serem simuladas
    busid::Vector{Int64} # Código de identificação das fronteiras com a transmissão
    nbuses::Int # Número de barras de fronteira com o sistema de distribuição
    ϵU::Float64 # Tolerância de contrato para caracterização de ultrapassagem
    ηcont::Float64 # Limite de redução do contrato em relação aos contratos vigentes
end

""" Dados por ponto de conexão e posto tarifário """
mutable struct BusData
    T_T::Vector{Float64} # Tarifas das fronteiras com a transmissão para o posto fora ponta
    T_U::Vector{Float64} # Tarifas de ultrapassagem com a transmissão para o posto fora ponta
    T_S::Vector{Float64} # Tarifas de ultrapassagem com a transmissão para o posto ponta
    T_rangeU::Vector{Float64} # Tarifas de ultrapassagem com a transmissão para o posto ponta
    T_rangeS::Vector{Float64} # Tarifas de ultrapassagem com a transmissão para o posto ponta
    f::Dict{Int64,Array{Float64,2}} # Cenários de máximos fluxos mensais por topologia (topologia => matriz de fluxos)
    lastcontract::Vector{Float64} # Contratos estabelecidos para o ano anterior ao início da análise no posto fora ponta
    μ_underpenalty::Vector{Float64} # Percentual do custo fixo de contrato admitido (limite superior) para o cvar dos cenários de custos de ultrapassagem
    μ_maxdem::Vector{Float64} # Percentual do custo fixo de contrato admitido (limite superior) para o cvar dos cenários de custos de máxima demanda
    givenM::Vector{Float64} # Valores dados de contrato fixos para avaliação
    Mreliability::Vector{Float64} # Valores de contrato confiabilidade para o critério de sobrecontratação
end

""" Dados de repasse por posto tarifário """
mutable struct RefoundData
    dem_hist::Vector{Float64} # Histórico de máxima demanda mensal dos consumidores (1 ano)
    dem_sim::Array{Float64} # Simulação de máxima demanda mensal dos consumidores (oriundo do módulo de Desagregação)
    dem_add::Float64 # Valor adicional de demanda dos consumidores a ser acrecentada em cada cenários simulado (cobre as demanda que se mantem fixas no pwf)
    M_hist::Dict{Any, Float64} # Valor histórico de contrato por ponto de conexão (identificador da conx => valor MUST)
    T_T_hist::Dict{Any, Float64} # Valor histórico de tarifa por ponto de conexão (identificador da conx => valor tarifa)
end

""" Resultados de contratação ótima por ponto de conexão e posto tarifário """
mutable struct OptimalContract
    optimalM::Array{Float64,2} # contrato de MUST/D ótimo
    C_fixed::Vector{Float64} # Custo mensal do contrato de MUST/D ótimo
    C_anual::Array{Float64,3} # custo anual total de contrato
    C_mensal::Array{Float64,3} # custo mensal total
    CMU::Array{Float64,3} # custo mensal de ultrapassagem
    CMS::Array{Float64,3} # custo anual de sobrecontratação
    CMD::Array{Float64,3} # custo mensal de máxima demanda
    CMR::Array{Float64} # custo mensal de banda de incerteza
    scen_penalty::Array{Vector{Int64},2} # Cenários, por ano e por topologia, para os quais ocorre ultrapassagem
    scen_overcont::Array{Vector{Int64},2} # Cenários, por ano e por topologia, para os quais ocorre sobrecontratacao
    scen_tolerance_up::Array{Vector{Int64},2} # Cenários, por ano e topologia, que atingem a tolerância de penalidade
    scen_tolerance_dwn::Array{Vector{Int64},2} # Cenários, por ano e topologia, que atingem a tolerância de penalidade
end

""" Saída do problema de otimização por ponto de conexao """
mutable struct OptimalResults
    objfun::Float64 # Valor ótimo da função objetivo
    status::String # status da otimização
end

""" Indicadores de risco por ponto de conexão e posto tarifário """
mutable struct RiskIndicators
    E_totalcost::Vector{Float64} # Valor esperado dos cenarios de custo total (agrega cenarios e topologia)
    E_penaltycost::Vector{Float64} # Media dos cenarios de custo de multa (agrega cenarios e topologia)
    E_overcontcost::Vector{Float64} # Media dos cenarios de custo de sobrecontratacao (agrega cenarios e topologia)
    E_maxdemcost::Vector{Float64} # Media dos cenarios de custo de máxima demanda (agrega cenarios e topologia)
    CVaR_totalcost::Vector{Float64} # CVaR dos cenarios de custo total (agrega cenarios e topologia)
    CVaR_penaltycost::Vector{Float64} # CVaR dos cenarios de custo de multa (agrega cenarios e topologia)
    CVaR_overcontcost::Vector{Float64} # CVaR dos cenarios de custo de sobrecontratacao (agrega cenarios e topologia)
    CVaR_maxdemcost::Vector{Float64} # CVaR dos cenarios de máxima demanda (agrega cenarios e topologia)
    worstscen_totalcost::Vector{Float64} # Pior cenario de custo total (agrega cenarios e topologia)
    worstscen_penaltycost::Vector{Float64} # Pior cenario de custo de multa (agrega cenarios e topologia)
    worstscen_overcontcost::Vector{Float64} # Pior cenario de custo de multa (agrega cenarios e topologia)
    worstscen_maxdemcost::Vector{Float64} # Pior cenario de custo de máxima demanda (agrega cenarios e topologia)
    penaltyprob::Vector{Float64} # Probabilidade de ocorrencia de multa (agrega cenarios e topologia)
    overcontprob::Vector{Float64} # Probabilidade de ocorrencia de sobrecontratação (agrega cenarios e topologia)
end

""" Dados para plots MW por posto tarifário """
mutable struct PlotDatamw
    optimalM::Vector{Float64} # contrato otimo mes a mes
    penalty::Vector{Float64} # limite de ultrapassagem otimizado
    overcont::Vector{Float64} # limite de sobrecontratação otimizado
    f::Array{Float64} # cenarios de maximos mensais (agrega cenarios e topologia)
    penalty_f::Dict{Int64, Array{Float64}} # cenarios de maximos mensais para os quais ocorre ultrapassagem por ano (ano => matriz de maximos mensais que agrega cenarios e topologia) 
    overcont_f::Dict{Int64, Array{Float64}} # cenarios de maximos mensais para os quais ocorre sobrecontratacao por ano (ano => matriz de maximos mensais que agrega cenarios e topologia) 
    quantile5_f::Vector{Float64} # Quantil 5% mensal dos cenarios de maximo fluxo (agrega cenarios e topologia)
    quantile50_f::Vector{Float64} # Quantil 50% mensal dos cenarios de maximo fluxo (agrega cenarios e topologia)
    quantile95_f::Vector{Float64} # Quantil 95% mensal dos cenarios de maximo fluxo (agrega cenarios e topologia)
    max_f::Vector{Float64} # Maximo dos cenarios de maximo fluxo (agrega cenarios e topologia)
    min_f::Vector{Float64} # Minimo dos cenarios de maximo fluxo (agrega cenarios e topologia)
    histyear::Vector{Int64} # Vetor com os anos para os quais há historico 
    hist::Array{Float64,2} # Matriz (mesesXposto tarifario) com o historico de maximos mensais em uma fronteira
    reliability::Vector{Float64} # limite de tolorância para a sobrecontratação com MUST confiabilidade
end

""" Dados para plots de probabilidade por posto tarifário """
mutable struct PlotDatapercent
    overcont::Vector{Float64} # Probabilidade mensal de o máximo fluxo estar abaixo de 90% do MUST (agrega cenarios e topologias) 
    tolerance_up::Vector{Float64} # Probabilidade mensal de o máximo fluxo estar entre 100% e 110% do MUST (agrega cenarios e topologias)
    tolerance_dwn::Vector{Float64} # Probabilidade mensal de o máximo fluxo estar entre 100% e 110% do MUST (agrega cenarios e topologias)
    penalty::Vector{Float64} # Probabilidade mensal de ultrapassagem (agrega cenarios e topologias)
end