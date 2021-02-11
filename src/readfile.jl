"""
plfoptionsfile, electricdata_file, activepower_filename, reactivepower_filename,
    mustfile, musdfile, jld_filename, tariff_file, contfilename = open_parametersfile(fileopened::String)
Função que abre arquivo de parâmetros e retorna informações
Args.:
fileopened: arquivos de parâmetros em formato .txt
"""
function open_parametersfile(fileopened::String)
    
    file = readchomp(fileopened)
    spl = Meta.parse.(split(file, r"\n"))
    for i = 1:length(spl)
        eval(spl[i])
    end

    return endereco, nome, estudo_completo, sobrecontratacao, topologias, avaliacao, discretizacao, tolerancia_ultrap_flex, periodos, tolerancia_ultrap, tolerancia_sobrec, 
        alfa_cvar, lambda_fobj, limite_contrato_trans, limite_contrato_dist, arquivo_tarifa, arquivo_param_contrato, 
        arquivo_postos, arquivo_fronteira, arquivo_fluxo_transmissao, arquivo_fluxo_distribuicao, arquivo_datas, 
        arquivo_fronteira_unica, arquivo_probtop
end

""" pathinput(path::String, paramfilepath::String)
Função que extrai diretórios de arquivos de dados
Args.:
path: diretório dos arquivos de parâmetros e de dados de entrada
paramfilepath: diretório completo do arquivo de parâmetros "Parametros.txt"
"""
function pathinput(path::String)

    paramfilepath = joinpath(path, "Parametros.txt")
    
    (data_path, study_name, estudo_completo, sobrecontratacao, topologias, avaliacao, discretizacao, tolerancia_ultrap_flex, periodos, tolerancia_ultrap, tolerancia_sobrec, alfa_cvar, lambda_fobj, limite_contrato_trans, 
        limite_contrato_dist, arquivo_tarifa, arquivo_param_contrato, arquivo_postos, arquivo_fronteira, arquivo_fluxo_transmissao,
        arquivo_fluxo_distribuicao, arquivo_datas, arquivo_fronteira_unica, arquivo_probtop) = open_parametersfile(paramfilepath)
    
    # Diretórios dos arquivos de entrada
    pathbussimulate   = joinpath(data_path, arquivo_fronteira)
    pathbussimreduced = joinpath(data_path, arquivo_fronteira_unica)
    pathjlddataT      = joinpath(data_path, arquivo_fluxo_transmissao)
    pathjlddataD      = joinpath(data_path, arquivo_fluxo_distribuicao)
    pathtariff        = joinpath(data_path, arquivo_tarifa)
    pathcontractdata  = joinpath(data_path, arquivo_param_contrato)
    pathpeaks         = joinpath(data_path, arquivo_postos)
    pathdates         = joinpath(data_path, arquivo_datas)
    pathprobtop       = joinpath(data_path, arquivo_probtop)
 
    # Construção do arquivo options.csv
    options = DataFrame(code=String[], value=Any[])
    
    if estudo_completo == "sim"
        push!(options, ["TRIGGERCOMPLETE",1])
    elseif estudo_completo == "nao"
        push!(options, ["TRIGGERCOMPLETE",0])
    end
    
    if sobrecontratacao == "sim"
        push!(options, ["TRIGGEROVERCONT",1])
    elseif sobrecontratacao == "nao"
        push!(options, ["TRIGGEROVERCONT",0])
    end

    if topologias == "sim"
        push!(options, ["TRIGGERTOPOLOGY",1])
    elseif topologias == "nao"
        push!(options, ["TRIGGERTOPOLOGY",0])
    end

    if avaliacao == "sim"
        push!(options, ["TRIGGEREVALUATE",1])
    elseif avaliacao == "nao"
        push!(options, ["TRIGGEREVALUATE",0])
    end

    if tolerancia_ultrap_flex == "sim"
        push!(options, ["TRIGGERFLEXTOL",1])
    elseif avaliacao == "nao"
        push!(options, ["TRIGGERFLEXTOL",0])
    end

    push!(options, ["NUMPER",periodos])
    push!(options, ["UNDERCTOL",tolerancia_ultrap])
    push!(options, ["OVERCTOL",tolerancia_sobrec])
    push!(options, ["ALFA",alfa_cvar])
    push!(options, ["LAMBDA",lambda_fobj])
    push!(options, ["TRANSMINCONT",limite_contrato_trans])
    push!(options, ["DISTMINCONT",limite_contrato_dist])
    
    mkpath(joinpath(path,"Resultados","$study_name"))
    pathoptions = joinpath(path, "Resultados","$study_name", "options.csv")
    CSV.write(pathoptions, options)

    return data_path, study_name, pathbussimulate, pathbussimreduced, pathjlddataT, pathjlddataD, pathtariff, pathcontractdata, pathpeaks, pathdates, 
        pathoptions, pathprobtop
end

""" dimensions,optimparam,transparam,distparam,busdata,peaksnames = readdata(param_path::String)
Função de leitura de dados de entrada para o modelo geneneralizado de contratação

Args.:
param_path: diretório do arquivo de parâmetros
contcicleflag: flag que define a estrutura de ciclo contratual

""" 
function readdata(param_path::String)

    # Leitura de parâmetros gerais
    data_path, study_name, pathbussimulate, pathbussimreduced, pathjlddataT, ~, pathtariff, pathcontractdata, pathpeaks, pathdates, pathoptions, ~ = pathinput(param_path)

    @info("Leitura de parâmetros completa.")

    completeflag,~,evaluateflag, flextolflag, overcontflag, nmonthper, ϵU, ϵS, α, λ, ηcontT, ηcontD = readintcsv(pathoptions,["TRIGGERCOMPLETE";
        "TRIGGERTOPOLOGY";"TRIGGEREVALUATE";"TRIGGERFLEXTOL";"TRIGGEROVERCONT";"NUMPER";"UNDERCTOL";"OVERCTOL";"ALFA";"LAMBDA";"TRANSMINCONT";"DISTMINCONT"])
    completeflag = Int(completeflag)

    # Restrição do número de meses em um ciclo de contratação. Deve ser 1, 2, 3, 6 ou 12
    if isempty(findall((in)(nmonthper),[1,2,3,4,6,12]))
        error("O número de meses que carateriza um ciclo de contratação deve ser 1, 2, 3, 4, 6 ou 12.")
    else
        nper = Int(1) # número de períodos contratuais (contratos) dentro de um ciclo de contrato
        nmonths = Int(nmonthper) # número de meses que formam um ciclo contratual
    end

    # Aquisição de dados de acordo com o tipo de simulação de cenários
    if completeflag == 1 # Cenários via fluxo de potência
        # Leitura de pontos de conexão para os quais o contrato será otimizado
        busnames = Array{String}(unique(CSV.read(pathbussimulate)[:,:conexoes])) # Conversão para Array{String}

        # Leitura da saida do módulo PLFMUST
        plfT, busnamesT, peaksid, dimensions, topologyid = readplfresults(pathjlddataT, busnames, pathdates, nper, nmonths)

        vector_sim_dates = load(pathdates)
        vector_sim_dates = vector_sim_dates["dates"]

    else #Cenários via simulação de longo prazo

        # Leitura de informações sobre a otimizacao
        if isfile(pathbussimreduced)
            businfo = CSV.read(pathbussimreduced)
        else
            error("O arquivo de identificação das fronteiras para o estudo simplificado não existe.")
        end

        # Definicao de vetores e grandezas
        busnames = Array{String}(unique(businfo[:,:conexoes])) #pontos de conexão para os quais o contrato será otimizado # Conversão para Array{String}

        peaksid = Array{Int64}(unique(businfo[:,:regime_tarifario])) #identificacao dos regimes tarifarios # Conversão para Array{Int}

        npeaks = length(peaksid) # numero de regimes tarifarios

        # Divisão entre fronetiras de transmissão e distribuição
        indexT = findall(x -> x == "transmissao", businfo[:,:tipo])
        busnamesT = Array{String}(unique(businfo[:,:conexoes][indexT])) # Conversão para Array{String}

        # Leitura dos dados vindos do módulo Simulation
        plfT,vector_sim_dates = readsimresults(businfo,busnamesT,peaksid,npeaks,DIR)

        # Quantidade e identificação dos postos tarifários, número de cenário, número de anos
        if length(busnamesT) != 0 # Há barras de conexão com a transmissão
            dimensions, peaksid, topologyid = calculatedim(plfT, nmonths, nper)
        elseif length(busnamesT) == 0
            error("Não foram selecinadas fronteiras para o estudo.")
        end
    end

    # Definição das probabilidades
    probscen = 1/dimensions.nscen # Cenários. Fixado à simulação de cenários equiprováveis, que é o caso do projeto.
    probtop = Dict(1 => 1.0) # Topologia. Fixo no caso de topologia única.
    
    # Dicionário com os nomes dos regimes tarifários
    peaksinfo = CSV.read(pathpeaks)
    peaksnames = Dict(peaksinfo[:,:regime_tarifario][i] => peaksinfo[:,:nome][i] for i=1:length(peaksinfo[:,:regime_tarifario]))

    # Estrutura OptimParameters
    optimparam = OptimParameters(overcontflag,evaluateflag,flextolflag,probscen,probtop,α,λ,peaksid,peaksnames,topologyid)

    # Estruturas TransGeneralParam e DistGeneralParam
    ϵU_gen = Dict(t => Dict(p => Dict(a => Vector{Float64}(undef, dimensions.nmonths) for a in 1:dimensions.nyear) for p in optimparam.peaksid) for t in busnamesT)
    ϵS_gen = Dict(t => Dict(p => Dict(a => Vector{Float64}(undef, dimensions.nmonths) for a in 1:dimensions.nyear) for p in optimparam.peaksid) for t in busnamesT)

    transparam = TransGeneralParam(busnamesT,[], length(busnamesT),ϵU_gen, ϵU,ϵS_gen,ϵS,ηcontT)

    # Dicionário de estruturas BusData
    busdata = createbusdata(busnames,busnamesT,dimensions,optimparam,pathtariff,pathcontractdata,plfT,peaksnames)

    return dimensions,optimparam,transparam,busdata,peaksnames,study_name
end

""" Aquisição de dados iniciais - Inicialização de parametros inteiros """
function readintcsv(path::String, data_names::Vector{String})
    
    data_table = CSV.read(path)
    data_values = Vector{Float64}(undef,size(data_names,1))
    for (i,name) in enumerate(data_names)
        idx = findfirst(x -> x==name,data_table[:,:code])
        if !(idx == 0)
            data_values[i] = data_table[idx,2]
        end
    end
    return data_values
end

""" Inicializa o dicionário de estruturas BusData """
function busdatainit(dimensions::Dimensions,optimparam::OptimParameters,busnames::Vector{String})

    base_busdata = BusData(
        zeros(dimensions.nyear),
        zeros(dimensions.nyear),
        zeros(dimensions.nyear),
        zeros(dimensions.nyear),
        zeros(dimensions.nyear),
        Dict(),
        zeros(dimensions.nyear-1),
        zeros(dimensions.nyear),
        zeros(dimensions.nyear),
        zeros(dimensions.nyear),
        zeros(dimensions.nyear))

    busdata = Dict(busnames[i] =>
        Dict(optimparam.peaksid[j] => deepcopy(base_busdata) for j=1:dimensions.npeaks) for i=1:length(busnames))

    return busdata
end

""" Cria e preenche o dicionário de estruturas BusData """
function createbusdata(busnames::Vector{String}, busnamesT::Vector{String}, dimensions::Dimensions, optimparam::OptimParameters,
    pathtariff::String, pathcontractdata::String, plfT::Dict,peaksnames::Dict)

    # Inicialização do dicionário de estruturas BusData
    busdata = busdatainit(dimensions,optimparam,busnames)

    # Leitura de dados de tarifa por ponto de conexão
    tariffdata = CSV.read(pathtariff)

    # Leitura de dados de contrato por ponto de conexão
    contractdata = CSV.read(pathcontractdata)

    # Preenchimento do dicionario de estruturas BusData (as chaves são as conexoes e postos tarifarios) - barras transmissão
    for con in busnamesT, peak in optimparam.peaksid
        
        # tarifas
        indexT_T = intersect(findall((in)([con]),tariffdata[:,:nome_conexao]) , findall((in)([peak]),tariffdata[:,:regime_tarifario]) , findall((in)(["regular"]),tariffdata[:,:tipo_tarifa]))
        indexT_U = intersect(findall((in)([con]),tariffdata[:,:nome_conexao]) , findall((in)([peak]),tariffdata[:,:regime_tarifario]) , findall((in)(["ultrapassagem"]),tariffdata[:,:tipo_tarifa]))
        indexT_S = intersect(findall((in)([con]),tariffdata[:,:nome_conexao]) , findall((in)([peak]),tariffdata[:,:regime_tarifario]) , findall((in)(["sobrecontratacao"]),tariffdata[:,:tipo_tarifa]))
        indexT_rangeU = intersect(findall((in)([con]),tariffdata[:,:nome_conexao]) , findall((in)([peak]),tariffdata[:,:regime_tarifario]) , findall((in)(["faixa_ultrap"]),tariffdata[:,:tipo_tarifa]))
        indexT_rangeS = intersect(findall((in)([con]),tariffdata[:,:nome_conexao]) , findall((in)([peak]),tariffdata[:,:regime_tarifario]) , findall((in)(["faixa_sobrec"]),tariffdata[:,:tipo_tarifa]))

        # Verificação da consistência dos dados - ausência de dados
        if isempty(indexT_T)
            error("Não foram fornecidos dados de tarifa regular para a conexão $con, posto tarifário $(peaksnames[peak]).")
        elseif isempty(indexT_U)
            error("Não foram fornecidos dados de tarifa de ultrapassagem para a conexão $con, posto tarifário $(peaksnames[peak]).")
        elseif isempty(indexT_S)
            error("Não foram fornecidos dados de tarifa de sobrecontratação para a conexão $con, posto tarifário $(peaksnames[peak]).")
        elseif isempty(indexT_rangeU)
            error("Não foram fornecidos dados de tarifa da faixa de ultrapassagem para a conexão $con, posto tarifário $(peaksnames[peak]).")
        elseif isempty(indexT_rangeS)
            error("Não foram fornecidos dados de tarifa da fixa de sobrecontratação para a conexão $con, posto tarifário $(peaksnames[peak]).")
        end

        # Verificação da consistência dos dados - número de anos
        if length(indexT_T) < dimensions.nyear
            error("Não foram fornecidos dados de tarifa regular para todos os ciclos de contratação do estudo na conexão $con, posto tarifário $(peaksnames[peak]).")
        elseif length(indexT_U) < dimensions.nyear
            error("Não foram fornecidos dados de tarifa de ultrapassagem para todos os ciclos de contratação do estudo na conexão $con, posto tarifário $(peaksnames[peak]).")
        elseif length(indexT_S) < dimensions.nyear
            error("Não foram fornecidos dados de tarifa de sobrecontratação para todos os ciclos de contratação do estudo na conexão $con, posto tarifário $(peaksnames[peak]).")
        elseif length(indexT_rangeU) < dimensions.nyear
            error("Não foram fornecidos dados de tarifa da faixa de ultrapassagem para todos os ciclos de contratação do estudo na conexão $con, posto tarifário $(peaksnames[peak]).")
        elseif length(indexT_rangeS) < dimensions.nyear
            error("Não foram fornecidos dados de tarifa da fixa de sobrecontratação para todos os ciclos de contratação do estudo na conexão $con, posto tarifário $(peaksnames[peak]).")
        end

        # Preenchimento do dicionario
        busdata[con][peak].T_T = tariffdata[:,:valor][indexT_T]
        busdata[con][peak].T_U = tariffdata[:,:valor][indexT_U]
        busdata[con][peak].T_S = tariffdata[:,:valor][indexT_S]
        busdata[con][peak].T_rangeU = tariffdata[:,:valor][indexT_rangeU]
        busdata[con][peak].T_rangeS = tariffdata[:,:valor][indexT_rangeS]

        # fluxo
        topology = collect(keys(plfT))
        busdata[con][peak].f = Dict(k => plfT[k][con][peak] for k in topology)
            
        # parametros de contratos
        indexconpeak = intersect(findall((in)([con]),contractdata[:,:nome_conexao]) , findall((in)([peak]),contractdata[:,:regime_tarifario]))
        
        # Verificação da consistência dos dados - ausência de dados e número de anos
        if isempty(indexconpeak)
            error("Não foram fornecidos dados de contrato para a conexão $con, posto tarifário $(peaksnames[peak]).")
        elseif length(indexconpeak) < dimensions.nyear
            error("Não foram fornecidos dados de contrato para todos os ciclos de contratação do estudo na conexão $con, posto tarifário $(peaksnames[peak]).")
        end

        # Preenchimento do dicionário
        busdata[con][peak].lastcontract = contractdata[:,:contrato_vigente][indexconpeak]
        busdata[con][peak].μ_underpenalty = contractdata[:,:limite_cvar_multa][indexconpeak]
        busdata[con][peak].μ_maxdem = contractdata[:,:limite_cvar_maxdem][indexconpeak]
        busdata[con][peak].givenM = contractdata[:,:contrato_avaliacao][indexconpeak]
        busdata[con][peak].Mreliability = contractdata[:,:contrato_confiabilidade][indexconpeak]
    end

    return busdata
end

""" Calcula quantos meses devem ser retirados do início e fim das máximas injeções para que se tenha sempre anos completos de análise """
function datesadjust(pathdates::String)
    
    # Conferência de datas
    dates = load(pathdates)
    dates = dates["dates"]
    initmonthsexclude = 0
    finalmonthsexclude = 0

    # Meses iniciais - O primeiro mês deve ser janeiro
    if ~(Dates.month(dates[1]) == 1)
        initmonthsexclude = 12 - Dates.month(dates[1]) + 1
    end

    # Meses finais - O último mês deve ser dezembro
    if ~(Dates.month(dates[end]) == 12)
        finalmonthsexclude = Dates.month(dates[end])
    end

    return initmonthsexclude, finalmonthsexclude
end

""" Lê os arquivos .jld simulados via sorteio de contingências no módulo PLFMUST """
function readplf(pathjlddata::String, busnames::Vector{String}, initmonthsexclude::Int64, finalmonthsexclude::Int64)

    # Leitura do .jld do módulo PowerFlow
    vlplf = load(pathjlddata)

    # Identificação das barras de conexão com a transmissão e a distribuição
    busnamessim = collect(keys(vlplf))

    # Aquisição dos dados apenas para as barras escolhidas pelo usuário para otimizar o contrato
    busnamessim = intersect(busnamessim,busnames)

    # Aquisição dos dados vindo do PLFMUST
    if length(busnamessim) != 0 # Se há conexões a serem otimizadas
        
        # Vetor de topologias (nesse caso há sempre apenas uma topologia sinalizada pelo id 1)
        topology = [1]
        
        # Identificação dos regimes tarifarios
        peaksid = collect(keys(vlplf[busnamessim[1]]))

        # Aquisição dos valores de máximo fluxo
        plf = Dict(k => Dict(con => Dict(p => vlplf[con][p][initmonthsexclude+1:end-finalmonthsexclude,:] for p in peaksid) 
            for con in busnamessim) for k in topology) # Ajuste de datas para manter anos completos

    else # Se não há conexões
        plf = Dict()
        busnamessim = Vector{String}()
    end
    
    return plf, busnamessim
end

""" Calcula as as dimensões do problema de otimização """
function calculatedim(plf::Dict, nmonths::Int64, nper::Int64)

    # Chaves do dicionário plf
    topologyid = collect(keys(plf))
    busnamessim = collect(keys(plf[topologyid[1]]))
    peaksid = sort(collect(keys(plf[topologyid[1]][busnamessim[1]])))

    # Quantidade e identificação dos postos tarifários, número de cenário, número de anos (geral para MUST e MUSD)
    ntotalmonths,nscen = size(plf[topologyid[1]][busnamessim[1]][peaksid[1]])
    nyear = ntotalmonths/nmonths
    ntop = length(topologyid)
    npeaks = length(peaksid)

    # Estruturas Dimensions
    dimensions = Dimensions(npeaks,nscen,nper,nmonths,nyear,ntop)

    return dimensions, peaksid, topologyid
end

""" Lê os arquivos .jld vindos do módulo PowerFlow"""
function readplfresults(pathjlddataT::String, busnames::Vector{String}, pathdates::String,nper::Int64,nmonths::Int64)

    # Verificação da existência dos arquivos .jld
    if !isfile(pathjlddataT) # Confere o caso de não existir nenhum arquivo .jld para conexões
        error("Não há arquivos de dados .jld no diretório indicado.")
    end
    
    # Conferência de datas
    initmonthsexclude, finalmonthsexclude = datesadjust(pathdates)

    # Leitura para as fronteiras de transmissão
    if isfile(pathjlddataT) # Confere se há arquivo .jld para conexões com a transmissão
        # Simulacao do PLFMUST via sorteio de contingências
        # Leitura do .jld do tipo sorteio de contingências
        plfT, busnamesT = readplf(pathjlddataT, busnames, initmonthsexclude, finalmonthsexclude)            
    else # Se não há arquivo .jld para a transmissão
        plfT = Dict()
        busnamesT = Vector{String}()
    end

    # Quantidade e identificação dos postos tarifários, número de cenário, número de anos (geral para MUST e MUSD)
    if length(busnamesT) != 0 # Há barras de conexão com a transmissão
        dimensions, peaksid, topologyid= calculatedim(plfT, nmonths, nper)
    else
        error("Uma ou mais barras selecionadas para o estudo não existem nos dados .jld.")
    end

    return plfT, busnamesT, peaksid, dimensions, topologyid
end


""" Calcula as probabilidades de ocorrência das topologias do sistema elétrico """
function calculateprobtop(pathprobtop::String, topologyflag::Int64, topologyid::Vector{Int64}, completeflag::Int64)
    
    if topologyflag == 1 && completeflag == 1 # Se o resultado do PLFMUST é por topologia e o estudo é completo
        # Leitura das probabilidades de falha (saída do PLFMUST)
        probtop = load(pathprobtop)["probresults"]

        # Normalização das probabilidades
        totalprob = sum(probtop[k] for k in topologyid)

        for k in topologyid
            probtop[k] = probtop[k]/totalprob
        end
    elseif (topologyflag == 0 && completeflag == 1) || completeflag == 0 # Se o resultado do PLFMUST é simulação de contingência (topologia única) ou se o estudo é simplificado
        if topologyflag == 1 # Warning para o caso de o usuário selecionar a variação de topologias quando o estudo é simplificado
            @warn("Foi selecionado a consideração de variação topologias de rede para o estudo simplificado. 
                Essa seleção foi ignorada, uma vez que o estudo sismplificado não considera a rede elétrica.")
        end
        
        probtop = Dict(1 => 1.0) # Se não foi feita a simulacao por topologia, a probabilidade e 1.
    end

    return probtop
end

""" Lê os arquivos .csv vindos do módulo Simulation"""
function readsimresults(businfo::DataFrame,busnamesT::Vector{String}, peaksid::Vector{Int64}, npeaks::Int64,DIR::String)

    # Dicionários vazios
    plfT = Dict(1 => Dict(busnamesT[i] => Dict(peaksid[j] => Array{Float64}(undef,0,0) for j=1:npeaks) for i=1:length(busnamesT))) # O 1 da primeira chave reperesenta a topologia, que nesse caso e unica
    
    # Números de meses a excluir
    initmonthsexcludeT = 0
    finalmonthsexcludeT = 0
    dates = []

    # Preenchimento dos dicionário a cada linha do arquivo BarrasSim_reduced.csv
    for i = 1:length(businfo[:,:conexoes])
        if businfo[:,:tipo][i] == "transmissao"
            fTpath = joinpath(DIR,businfo[:,:file][i])
            fT = CSV.read(fTpath,header = false) # Leitura do arquivo vindo do módulo Simulation
            dates = fT[:,1]

            # Meses iniciais - O primeiro mês deve ser janeiro
            if Dates.month(dates[1]) != 1
                initmonthsexcludeT = 12 - parse(Int64,dates[1][6:end]) + 1
            end

            # Meses finais - O último mês deve ser dezembro
            if Dates.month(dates[end]) != 12
                finalmonthsexcludeT = parse(Int64,dates[end][6:end])
            end

            # Ajuste das datas na matriz de cenários e retirada da coluna de datas
            fT = fT[initmonthsexcludeT+1:end-finalmonthsexcludeT,2:end]

            # Preenchimento do dicionário
            plfT[1][businfo[:,:conexoes][i]][businfo[:,:regime_tarifario][i]] = fT
        else
            error("Os único tipo aceito para as conexões é transmissão")
        end
    end

    return plfT,dates
end


