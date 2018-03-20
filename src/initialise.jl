#=
Copyright 2017 INSIGNEO Institute for in silico Medicine

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
=#


# """
#     checkInputFiles(project_name :: String)
#
# Look for project input files in the current directory. If one of them is missing, spawn an
# error.
# """
# function checkInputFiles(project_name :: String)
#     f_const = join([project_name, "_constants.yml"])
#     f_inlet = join([project_name, "_inlet.dat"])
#     f_model = join([project_name, ".csv"])
#
#     # check if all the input files are in the current folder
#     for f in [f_const, f_inlet, f_model]
#         if isfile(f) == false
#             error("$f file missing")
#         end
#     end
# end


"""
    checkInletFiles(project_name :: String, number_of_inlets :: Int,
                    inlets :: Array{String, 1})

Look for as many inlet files as specified in the project description. If one of them is
missing, spawn an error. Returns a list of the inlet file names.
"""
function checkInletFiles(project_name :: String, number_of_inlets :: Int,
                         inlets :: Array{String, 1})

    for inlet_idx = 2:number_of_inlets
        f_additional_inlet = join([project_name, "_", inlet_idx, "_inlet.dat"])

        if isfile(f_additional_inlet) == false
            error("number_of_inlets = $number_of_inlets, but $f file is missing")
        end

        push!(inlets, f_additional_inlet)
    end

    return inlets
end


"""
    copyInputFilesToResultsFolder(project_name :: String, inlets :: Array{String, 1})

Copy input files (including all the inlet files) to the results folder and change current
directory.
"""
function copyInputFilesToResultsFolder(project_name :: String, inlets :: Array{String, 1})
    # make results folder
    r_folder = join([project_name, "_results"])
    if isdir(r_folder) == false
      mkdir(r_folder)
    end

    # copy input files in results folder
    f_const = join([project_name, "_constants.yml"])
    cp(f_const, join([r_folder, "/", f_const]), remove_destination=true)

    f_model = join([project_name, ".csv"])
    cp(f_model, join([r_folder, "/", f_model]), remove_destination=true)

    for f_inlet in inlets
        cp(f_inlet, join([r_folder, "/", f_inlet]), remove_destination=true)
    end

    cd(r_folder)
end


"""
    loadInletData(inlet_file :: String)

Read discretised inlet data from inlet file. Return an `Array{Float64, 2}` whose first
columun contains time variable and second column contains the inlet time function.
"""
function loadInletData(inlet_file :: String)
    return readdlm(inlet_file)
end


# """
#     buildHeart(project_constants :: Dict{Any,Any}, inlet_data :: Array{Float64,2},
#                inlet_number :: Int)
#
# Return an instance of type `::Heart` for a single inlet.
# """
# function buildHeart(project_constants :: Dict{Any,Any}, inlet_data :: Array{Float64,2},
#                     inlet_number :: Int)
#
#     cardiac_period = inlet_data[end, 1]
#     initial_flow = 0.0
#
#     return Heart(project_constants["inlet_type"], cardiac_period, inlet_data,
#                  initial_flow, inlet_number)
# end


"""
    buildHearts(project_constants :: Dict{Any,Any}, inlet_names :: Array{String,1})

Return a list of instances of type `::Heart` given the list of inlets.
"""
function buildHearts(project_constants :: Dict{Any,Any}, inlet_names :: Array{String,1})

    hearts = []
    for i = 1:length(inlet_names)
        inlet_file = inlet_names[i]
        inlet_data = loadInletData(inlet_file)
        push!(hearts, buildHeart(project_constants, inlet_data, i))
    end

    return hearts
end


# """
#     buildBlood(project_constants :: Dict{Any,Any})
#
# Return an instance of type `::Blood`.
# """
# function buildBlood(project_constants :: Dict{Any,Any})
#     mu = project_constants["mu"]
#     rho = project_constants["rho"]
#     gamma_profile = project_constants["gamma_profile"]
#
#     nu = mu/rho
#     Cf = 8*pi*nu
#     rho_inv = 1/rho
#     viscT = 2*(gamma_profile + 2)*pi*mu
#
#     return Blood(mu, rho, rho_inv, Cf, gamma_profile, viscT)
# end
#

"""
    checkConstants(project_constants :: Dict{Any,Any})

Parse and return the constants file while checking if all the parameters are correctly specified.
"""
function checkConstants(project_constants :: Dict{Any,Any})

    fundamental_parameters = ["inlet_type", "mu", "rho", "number_of_inlets"]
    for key in fundamental_parameters
        if ~haskey(project_constants, key)
            error("$key not defined in <project>.yml")
        end
    end

    not_so_important_parameters = ["gamma_profile", "Ccfl", "cycles", "initial_pressure"]
    default_values = [9, 0.9, 100, 0.0]
    for i = 1:length(not_so_important_parameters)
        key = not_so_important_parameters[i]
        if ~haskey(project_constants, key)
            default_value = default_values[i]
            warn("$key not defined in <project>.yml, assuming $default_value")
            project_constants[key] = default_values[i]
        end
    end

    return project_constants
end


"""
    loadConstants(project_constants_file :: String)

Load the YAML constants file.
"""
function loadConstants(project_constants_file :: String)
    return YAML.load(open(project_constants_file))
end

#
# """
#     loadSimulationFiles(project_name :: String)
#
# Wrapper function for simulation initialisation. Load all the simulation files and run
# sanity checks. Return list of constants, model definition, inlets, blood properties and
# expected total computing time.
# """
# function loadSimulationFiles(project_name :: String)
#
#     checkInputFiles(project_name)
#
#     f_inlet = join([project_name, "_inlet.dat"])
#     inlets = [f_inlet]
#
#     # load constants
#     f_const = join([project_name, "_constants.yml"])
#     project_constants = loadConstants(f_const)
#     project_constants = checkConstants(project_constants)
#
#     # check for additional inlets
#     number_of_inlets = project_constants["number_of_inlets"]
#     if number_of_inlets > 1
#         inlets = checkInletFiles(project_name, number_of_inlets, inlets)
#     end
#
#     # load inlets data
#     hearts = buildHearts(project_constants, inlets)
#
#     # load blood data
#     blood = buildBlood(project_constants)
#
#     # estimate total simulation time
#     total_time = project_constants["cycles"]*hearts[1].cardiac_T
#
#     # make results folder and copy input files
#     copyInputFilesToResultsFolder(project_name, inlets)
#
#     f_model = join([project_name, ".csv"])
#     model, model_header = readModelData(f_model)
#
#     return [project_constants, model, hearts, blood, total_time]
# end


"""
    parseModelRow(model_row :: Array{Any,1})

Parse a row from the `.csv` regarding a single vessel, run sanity checks, and return
vessel properties in a list.
"""
function parseModelRow(model_row :: Array{Any,1})
    vessel_name = model_row[1]

    if typeof(vessel_name) != SubString{String}
        error("vessel $vessel_name: the vessel name must be a string beginning with a literal (a,..., z, A,..., Z)")
    else
        vessel_name = convert(String, vessel_name)
    end

    sn = convert(Int, model_row[2])
    tn = convert(Int, model_row[3])
    rn = convert(Int, model_row[4])
    L = convert(Float64, model_row[5])
    M = convert(Int, model_row[6])
    Rp = convert(Float64, model_row[7])
    Rd = convert(Float64, model_row[8])
    E = convert(Float64, model_row[9])
    Pext = convert(Float64, model_row[10])

    if model_row[11] == ""
        Rt = ""
        R1 = ""
        R2 = ""
        Cc = ""
    elseif model_row[11] != "" && model_row[12] == ""
        Rt = convert(Float64, model_row[11])
        R1 = ""
        R2 = ""
        Cc = ""
    elseif model_row[11] != "" && model_row[12] != "" && model_row[13] == ""
        Rt = ""
        R1 = ""
        R2 = convert(Float64, model_row[11])
        Cc = convert(Float64, model_row[12])
    elseif model_row[11] != "" && model_row[12] != "" && model_row[13] != ""
        Rt = ""
        R1 = convert(Float64, model_row[11])
        R2 = convert(Float64, model_row[12])
        Cc = convert(Float64, model_row[13])
    end

    return vessel_name, sn, tn, rn, L, M, Rp, Rd, E, Pext, [Rt, R1, R2, Cc]
end


# """
#     meshVessel(L :: Float64, M :: Int)
#
# Pre-compute `dx`, `1/dx`, and `0.5*dx` for the
# current vessel. The `dx` is computed as `L/M` where `M` is the maximum value
# between `5` (the minimum needed by the solver), the value defined in the `.csv`, and
# `ceil(L*1e3)` (which would make `dx=1`mm).
# """
# function meshVessel(L :: Float64, M :: Int)
#     M = maximum([5, M, convert(Int, ceil(L*1e3))])
#     dx = L/M
#     invDx = M/L
#     halfDx = 0.5*dx
#
#     return dx, invDx, halfDx
# end


"""
    detectCapillaries(BCout, blood :: Blood, A0 :: Array{Float64,1},
                     gamma :: Array{Float64,1})

Identify the type of outlet boundary condition used for the current vessel (none,
reflection site, or three element windkessel).
"""
function detectCapillaries(BCout :: Array{String,1}, blood :: Blood,
                          A0 :: Array{Float64,1}, gamma :: Array{Float64,1})
    BCout = [0.0, 0.0, 0.0, 0.0]
    return BCout, "none"
end

function detectCapillaries(BCout :: Array{Any,1}, blood :: Blood, A0 :: Array{Float64,1}, gamma :: Array{Float64,1})

    if BCout[1] != "" && BCout[2] == ""
        BCout[2:4] = [0.0, 0.0, 0.0]
        return BCout, "reflection"

    elseif BCout[1] == "" && BCout[2] == "" && BCout[3] != ""
        BCout[1] = 0.0
        BCout[2] = blood.rho*waveSpeed(A0[end], gamma[end])/A0[end]
        BCout[3] -= BCout[2]
        return BCout, "wk3"

    elseif BCout[1] == "" && BCout[2] != ""
        BCout[1] = 0.0
        return BCout, "wk3"
    end
end


# """
#     buildArterialNetwork(model :: Array{Any,2}, heart :: Heart, blood :: Blood)
#
# Build a `::Vessel` for each row in the project `.csv`. Return a list of `::Vessel`s and
# a list of the edges in the network graph.
# """
# function buildArterialNetwork(model :: Array{Any,2}, heart :: Heart, blood :: Blood)
#
#     vessels = [buildVessel(1, model[1,:], heart, blood)]
#     edges = zeros(Int, size(model)[1], 4)
#     edges[1,1] = vessels[1].ID
#     edges[1,2] = vessels[1].sn
#     edges[1,3] = vessels[1].tn
#     edges[1,4] = vessels[1].inlet_idx
#
#     for i = 2:size(model)[1]
#         push!(vessels, buildVessel(i, model[i,:], heart, blood))
#         edges[i,1] = vessels[i].ID
#         edges[i,2] = vessels[i].sn
#         edges[i,3] = vessels[i].tn
#         edges[i,4] = vessels[i].inlet_idx
#     end
#
#     return vessels, edges
# end


"""
    buildVessel(ID :: Int, model_row :: Array{Any,1}, heart :: Heart, blood :: Blood)

Build a `::Vessel` given a row from the project `.csv`.
"""
function buildVessel(ID :: Int, model_row :: Array{Any,1}, heart :: Heart,
                     blood :: Blood)

    vessel_name, sn, tn, rn, L, M, Rp, Rd, E, Pext, BCout = parseModelRow(model_row)

    dx, invDx, halfDx = meshVessel(L, M)

    Q = zeros(Float64, M)
    P = zeros(Float64, M)
    A = zeros(Float64, M)
    u = zeros(Float64, M)
    c = zeros(Float64, M)
    A0 = zeros(Float64, M)
    R0 = zeros(Float64, M)
    h0 = zeros(Float64, M)
    beta = zeros(Float64, M)
    vA = zeros(Float64, M+2)
    vQ = zeros(Float64, M+2)
    Al = zeros(Float64, M+2)
    Ar = zeros(Float64, M+2)
    Ql = zeros(Float64, M+2)
    Qr = zeros(Float64, M+2)
    gamma = zeros(Float64, M)
    dA0dx = zeros(Float64, M)
    slope = zeros(Float64, M)
    dTaudx = zeros(Float64, M)
    inv_A0 = zeros(Float64, M)
    dU = zeros(Float64, 2, M+2)
    Fl = zeros(Float64, 2, M+2)
    Fr = zeros(Float64, 2, M+2)
    s_inv_A0 = zeros(Float64, M)
    slopesA = zeros(Float64, M+2)
    slopesQ = zeros(Float64, M+2)
    flux  = zeros(Float64, 2, M+2)
    uStar = zeros(Float64, 2, M+2)
    gamma_ghost = zeros(Float64, M+2)
    half_beta_dA0dx = zeros(Float64, M)

    s_pi = sqrt(pi)
    s_pi_E_over_sigma_squared = s_pi*E/0.75
    one_over_rho_s_p = 1/(3*blood.rho*s_pi)
    radius_slope = (Rd-Rp)/(M-1)
    ah = 0.2802
    bh = -5.053e2
    ch = 0.1324
    dh = -0.1114e2

    for i = 1:M
      R0[i] = radius_slope*(i - 1)*dx + Rp
      h0[i] = R0[i]*(ah*exp(bh*R0[i]) + ch*exp(dh*R0[i]))
      A0[i] = pi*R0[i]*R0[i]
      A[i] = A0[i]
      Q[i] = heart.initial_flow
      u[i] = Q[i]/A[i]
      inv_A0[i] = 1/A0[i]
      s_inv_A0[i] = sqrt(inv_A0[i])
      dA0dx[i] = 2*pi*R0[i]*radius_slope
      dTaudx[i] = sqrt(pi)*E*radius_slope*1.3*(h0[i]/R0[i] + R0[i]*(ah*bh*exp(bh*R0[i]) + ch*dh*exp(dh*R0[i])))
      beta[i] = s_inv_A0[i]*h0[i]*s_pi_E_over_sigma_squared
      gamma[i] = beta[i]*one_over_rho_s_p/R0[i]
      gamma_ghost[i+1] = gamma[i]
      half_beta_dA0dx[i] = beta[i]*0.5*dA0dx[i]
      P[i] = pressure(A[i], A0[i], beta[i], Pext)
      c[i] = waveSpeed(A[i], gamma[i])
    end

    gamma_ghost[1] = gamma[1]
    gamma_ghost[end] = gamma[end]

    BCout, outlet = detectCapillaries(BCout, blood, A0, gamma)
    Rt = BCout[1]
    R1 = BCout[2]
    R2 = BCout[3]
    Cc = BCout[4]

    U00A = A0[1]
    U01A = A0[2]
    UM1A = A0[M]
    UM2A = A0[M-1]

    U00Q = heart.initial_flow
    U01Q = heart.initial_flow
    UM1Q = heart.initial_flow
    UM2Q = heart.initial_flow

    W1M0 = u[end] - 4*c[end]
    W2M0 = u[end] + 4*c[end]

    node2 = convert(Int, floor(M*0.25))
    node3 = convert(Int, floor(M*0.5))
    node4 = convert(Int, floor(M*0.75))

    Pcn = 0.

    temp_A_name = join((vessel_name,"_A.temp"))
    temp_Q_name = join((vessel_name,"_Q.temp"))
    temp_u_name = join((vessel_name,"_u.temp"))
    temp_c_name = join((vessel_name,"_c.temp"))
    temp_P_name = join((vessel_name,"_P.temp"))

    last_A_name = join((vessel_name,"_A.last"))
    last_Q_name = join((vessel_name,"_Q.last"))
    last_u_name = join((vessel_name,"_u.last"))
    last_c_name = join((vessel_name,"_c.last"))
    last_P_name = join((vessel_name,"_P.last"))

    out_A_name = join((vessel_name,"_A.out"))
    out_Q_name = join((vessel_name,"_Q.out"))
    out_u_name = join((vessel_name,"_u.out"))
    out_c_name = join((vessel_name,"_c.out"))
    out_P_name = join((vessel_name,"_P.out"))

    temp_A = open(temp_A_name, "w")
    temp_Q = open(temp_Q_name, "w")
    temp_u = open(temp_u_name, "w")
    temp_c = open(temp_c_name, "w")
    temp_P = open(temp_P_name, "w")

    last_A = open(last_A_name, "w")
    last_Q = open(last_Q_name, "w")
    last_u = open(last_u_name, "w")
    last_c = open(last_c_name, "w")
    last_P = open(last_P_name, "w")

    out_A = open(out_A_name, "w")
    out_Q = open(out_Q_name, "w")
    out_u = open(out_u_name, "w")
    out_c = open(out_c_name, "w")
    out_P = open(out_P_name, "w")

    close(last_A)
    close(last_Q)
    close(last_u)
    close(last_c)
    close(last_P)

    close(out_A)
    close(out_Q)
    close(out_u)
    close(out_c)
    close(out_P)

    return Vessel(vessel_name, ID, sn, tn, rn, M,
                  dx, invDx, halfDx,
                  beta, gamma, gamma_ghost, half_beta_dA0dx,
                  A0, inv_A0, s_inv_A0, dA0dx, dTaudx, Pext,
                  A, Q, u, c, P,
                  W1M0, W2M0,
                  U00A, U00Q, U01A, U01Q, UM1A, UM1Q, UM2A, UM2Q,
                  temp_P_name, temp_Q_name, temp_A_name,
                  temp_c_name, temp_u_name,
                  last_P_name, last_Q_name, last_A_name,
                  last_c_name, last_u_name,
                  out_P_name, out_Q_name, out_A_name,
                  out_c_name, out_u_name,
                  temp_P, temp_Q, temp_A, temp_c, temp_u,
                  last_P, last_Q, last_A, last_c, last_u,
                  node2, node3, node4,
                  Rt, R1, R2, Cc,
                  Pcn,
                  slope, flux, uStar, vA, vQ,
                  dU, slopesA, slopesQ,
                  Al, Ar, Ql, Qr, Fl, Fr,
                  outlet)
end


"""
    readModelData(model_csv :: String)

Return the content of the project `.csv` as `::Array{Any,2}`.
"""
function readModelData(model_csv :: String)

  m, h = readdlm(model_csv, ',', header=true)

  for i = 1:length(h)
      h[i] = strip(h[i])
  end

  return m, h
end

#-----------------------------------------------------------------------------------------

# http://carlobaldassi.github.io/ArgParse.jl/stable/index.html
function parseCommandline()
    s = ArgParseSettings()

    @add_arg_table s begin
        "input_filename"
            help = ".yml input file name"
            required = true
        "--verbose", "-v"
            help = "Print STDOUT - default false"
            action = :store_true
        "--clean", "-c"
            help = "Clean input, .out, and .temp files at the end - default false"
            action = :store_true
    end

    return parse_args(s)
end


"""
    loadYAMLFile(filename :: String)

Open a YAML file and return the content as `Dict{Any,Any}`.
"""
function loadYAMLFile(filename :: String)
    if ~isfile(filename)
        error("missing $filename")
    end

    return YAML.load(open(filename))
end


"""
    checkInputFile(input_filename :: String)

Check YAML input file.
"""
function checkInputFile(data :: Dict{Any,Any})
    checkSections(data)
    checkNetwork(data["network"])
end


"""
    laodSimulationFiles(input_filename :: String)

Load and return YAML input file content.
"""
function loadSimulationFiles(input_filename :: String)
    data = loadYAMLFile(input_filename)

    checkInputFile(data)

    return data
end


"""
    makeResultsFolder(data :: Dict{Any,Any})

Create results folder and cd in.
"""
function makeResultsFolder(data :: Dict{Any,Any})
    project_name = data["project name"]
    r_folder = join([project_name, "_results"])

    if isdir(r_folder) == false
      mkdir(r_folder)
    end

    cd(r_folder)
end

"""
    buildBlood(project_constants :: Dict{Any,Any})

Return an instance of type `::Blood`.
"""
function buildBlood(blood_data :: Dict{Any,Any})
    mu = blood_data["mu"]
    rho = blood_data["rho"]
    rho_inv = 1.0/rho
    #

    return Blood(mu, rho, rho_inv)#, Cf, gamma_profile, viscT)
end

"""
    computeViscousTerm(vessel_data :: Dict{Any,Any}, blood :: Blood)

Return `2*(gamma_profile + 2)*pi*blood.mu` where `gamma_profile` is either specified in
the vessel definition or assumed equal to `9` (plug-flow).
"""
function computeViscousTerm(vessel_data :: Dict{Any,Any}, blood :: Blood)
    if haskey(vessel_data, "gamma_profile")
        gamma_profile = vessel_data["gamma_profile"]
    else
        gamma_profile = 9
    end
        return 2*(gamma_profile + 2)*pi*blood.mu
end


"""
    buildHeart(vessel_data)

If the current vessel is an inlet vessel, return `true` flag and an `Heart` struct.
"""
function buildHeart(vessel :: Dict{Any,Any})
    if haskey(vessel, "inlet")
        inlet_type = vessel["inlet"]
        input_data = loadInletData(vessel["inlet file"])
        cardiac_period = input_data[end, 1]
        inlet_number = vessel["inlet number"]

        return true, Heart(inlet_type, cardiac_period, input_data, inlet_number)
    else
        return false, Heart("none", 0.0, zeros(1,2), 0)
    end
end

"""

"""
function buildArterialNetwork(network :: Array{Dict{Any,Any},1}, blood :: Blood)

    vessels = [buildVessel(1, network[1], blood)]
    edges = zeros(Int, length(network), 4)
    edges[1,1] = vessels[1].ID
    edges[1,2] = vessels[1].sn
    edges[1,3] = vessels[1].tn
    edges[1,4] = vessels[1].heart.inlet_number

    for i = 2:length(network)
        push!(vessels, buildVessel(i, network[i], blood))
        edges[i,1] = vessels[i].ID
        edges[i,2] = vessels[i].sn
        edges[i,3] = vessels[i].tn
        edges[i,4] = vessels[i].heart.inlet_number
    end

    return vessels, edges
end

"""
    buildVessel(vessel_data :: Dict{Any,Any}, blood :: Blood)

"""
function buildVessel(ID :: Int, vessel_data :: Dict{Any,Any}, blood :: Blood)
    vessel_name = vessel_data["label"]
    sn = vessel_data["sn"]
    tn = vessel_data["tn"]
    L = vessel_data["L"]
    E = vessel_data["E"]

    Rp, Rd = computeRadii(vessel_data)
    Pext = computePext(vessel_data)
    M, dx, invDx, halfDx = meshVessel(vessel_data, L)
    outlet, Rt, R1, R2, Cc = addOutlet(vessel_data)
    viscT = computeViscousTerm(vessel_data, blood)

    inlet, heart = buildHeart(vessel_data)

    # allocate arrays
    Q = zeros(Float64, M)
    P = zeros(Float64, M)
    A = zeros(Float64, M)
    u = zeros(Float64, M)
    c = zeros(Float64, M)
    A0 = zeros(Float64, M)
    R0 = zeros(Float64, M)
    h0 = zeros(Float64, M)
    beta = zeros(Float64, M)
    vA = zeros(Float64, M+2)
    vQ = zeros(Float64, M+2)
    Al = zeros(Float64, M+2)
    Ar = zeros(Float64, M+2)
    Ql = zeros(Float64, M+2)
    Qr = zeros(Float64, M+2)
    gamma = zeros(Float64, M)
    dA0dx = zeros(Float64, M)
    slope = zeros(Float64, M)
    dTaudx = zeros(Float64, M)
    inv_A0 = zeros(Float64, M)
    dU = zeros(Float64, 2, M+2)
    Fl = zeros(Float64, 2, M+2)
    Fr = zeros(Float64, 2, M+2)
    s_inv_A0 = zeros(Float64, M)
    slopesA = zeros(Float64, M+2)
    slopesQ = zeros(Float64, M+2)
    flux  = zeros(Float64, 2, M+2)
    uStar = zeros(Float64, 2, M+2)
    gamma_ghost = zeros(Float64, M+2)
    half_beta_dA0dx = zeros(Float64, M)

    # useful constants
    s_pi = sqrt(pi)
    s_pi_E_over_sigma_squared = s_pi*E/0.75
    one_over_rho_s_p = 1/(3*blood.rho*s_pi)
    radius_slope = (Rd-Rp)/(M-1)
    ah = 0.2802
    bh = -5.053e2
    ch = 0.1324
    dh = -0.1114e2

    # fill arrays
    for i = 1:M
      R0[i] = radius_slope*(i - 1)*dx + Rp
      h0[i] = R0[i]*(ah*exp(bh*R0[i]) + ch*exp(dh*R0[i]))
      A0[i] = pi*R0[i]*R0[i]
      A[i] = A0[i]
      inv_A0[i] = 1/A0[i]
      s_inv_A0[i] = sqrt(inv_A0[i])
      dA0dx[i] = 2*pi*R0[i]*radius_slope
      dTaudx[i] = sqrt(pi)*E*radius_slope*1.3*(h0[i]/R0[i] + R0[i]*(ah*bh*exp(bh*R0[i]) + ch*dh*exp(dh*R0[i])))
      beta[i] = s_inv_A0[i]*h0[i]*s_pi_E_over_sigma_squared
      gamma[i] = beta[i]*one_over_rho_s_p/R0[i]
      gamma_ghost[i+1] = gamma[i]
      half_beta_dA0dx[i] = beta[i]*0.5*dA0dx[i]
      P[i] = pressure(A[i], A0[i], beta[i], Pext)
      c[i] = waveSpeed(A[i], gamma[i])
    end

    gamma_ghost[1] = gamma[1]
    gamma_ghost[end] = gamma[end]

    if outlet == "wk2"
        R1, R2 = computeWindkesselInletImpedance(R2, blood, A0, gamma)
    end

    U00A = A0[1]
    U01A = A0[2]
    UM1A = A0[M]
    UM2A = A0[M-1]

    U00Q = 0.0
    U01Q = 0.0
    UM1Q = 0.0
    UM2Q = 0.0

    W1M0 = u[end] - 4*c[end]
    W2M0 = u[end] + 4*c[end]

    node2 = convert(Int, floor(M*0.25))
    node3 = convert(Int, floor(M*0.5))
    node4 = convert(Int, floor(M*0.75))

    Pcn = 0.0

    temp_A_name = join((vessel_name,"_A.temp"))
    temp_Q_name = join((vessel_name,"_Q.temp"))
    temp_u_name = join((vessel_name,"_u.temp"))
    temp_c_name = join((vessel_name,"_c.temp"))
    temp_P_name = join((vessel_name,"_P.temp"))

    last_A_name = join((vessel_name,"_A.last"))
    last_Q_name = join((vessel_name,"_Q.last"))
    last_u_name = join((vessel_name,"_u.last"))
    last_c_name = join((vessel_name,"_c.last"))
    last_P_name = join((vessel_name,"_P.last"))

    out_A_name = join((vessel_name,"_A.out"))
    out_Q_name = join((vessel_name,"_Q.out"))
    out_u_name = join((vessel_name,"_u.out"))
    out_c_name = join((vessel_name,"_c.out"))
    out_P_name = join((vessel_name,"_P.out"))

    temp_A = open(temp_A_name, "w")
    temp_Q = open(temp_Q_name, "w")
    temp_u = open(temp_u_name, "w")
    temp_c = open(temp_c_name, "w")
    temp_P = open(temp_P_name, "w")

    last_A = open(last_A_name, "w")
    last_Q = open(last_Q_name, "w")
    last_u = open(last_u_name, "w")
    last_c = open(last_c_name, "w")
    last_P = open(last_P_name, "w")

    out_A = open(out_A_name, "w")
    out_Q = open(out_Q_name, "w")
    out_u = open(out_u_name, "w")
    out_c = open(out_c_name, "w")
    out_P = open(out_P_name, "w")

    close(last_A)
    close(last_Q)
    close(last_u)
    close(last_c)
    close(last_P)

    close(out_A)
    close(out_Q)
    close(out_u)
    close(out_c)
    close(out_P)

    return Vessel(vessel_name, ID, sn, tn, inlet, heart,
                  M, dx, invDx, halfDx,
                  beta, gamma, gamma_ghost, half_beta_dA0dx,
                  A0, inv_A0, s_inv_A0, dA0dx, dTaudx, Pext,
                  viscT,
                  A, Q, u, c, P,
                  W1M0, W2M0,
                  U00A, U00Q, U01A, U01Q, UM1A, UM1Q, UM2A, UM2Q,
                  temp_P_name, temp_Q_name, temp_A_name,
                  temp_c_name, temp_u_name,
                  last_P_name, last_Q_name, last_A_name,
                  last_c_name, last_u_name,
                  out_P_name, out_Q_name, out_A_name,
                  out_c_name, out_u_name,
                  temp_P, temp_Q, temp_A, temp_c, temp_u,
                  last_P, last_Q, last_A, last_c, last_u,
                  node2, node3, node4,
                  Rt, R1, R2, Cc,
                  Pcn,
                  slope, flux, uStar, vA, vQ,
                  dU, slopesA, slopesQ,
                  Al, Ar, Ql, Qr, Fl, Fr,
                  outlet)
    end


"""
    computeWindkesselInletImpedance(R1 :: Float64, R2 :: Float64, blood :: Blood,
                                    A0 :: Array{Float64,1}, gamma :: Array{Float64,1})
"""
function computeWindkesselInletImpedance(R2 :: Float64, blood :: Blood,
    A0 :: Array{Float64,1}, gamma :: Array{Float64,1})

    R1 = blood.rho*waveSpeed(A0[end], gamma[end])/A0[end]
    R2 -= R1

    return R1, R2
end


"""
    addOutlet(vessel :: Dict{Any,Any})

Parse outlet information for the current vessel and return windkessel and reflection
coeffiecient values.
"""
function addOutlet(vessel :: Dict{Any,Any})
    if haskey(vessel, "outlet")
        outlet = vessel["outlet"]
        if outlet == "wk3"
            Rt = 0.0
            R1 = vessel["R1"]
            R2 = vessel["R2"]
            Cc = vessel["Cc"]
        elseif outlet == "wk2"
            Rt = 0.0
            R1 = 0.0
            R2 = vessel["R1"]
            Cc = vessel["Cc"]
        elseif outlet == "reflection"
            Rt = vessel["Rt"]
            R1 = 0.0
            R2 = 0.0
            Cc = 0.0
        end
    else
        outlet = "none"
        Rt = 0.0
        R1 = 0.0
        R2 = 0.0
        Cc = 0.0
    end

    return outlet, Rt, R1, R2, Cc
end


"""
    meshVessel(vessel :: Dict{Any,Any}, L :: Float64)

Pre-compute `dx`, `1/dx`, and `0.5*dx` for the current vessel. The `dx` is computed as
`L/M` where `M` is the maximum value between `5` (the minimum needed by the solver), the value defined in the `.yml`, and `ceil(L*1e3)` (which would make `dx=1`mm).
"""
function meshVessel(vessel :: Dict{Any,Any}, L :: Float64)

    if ~haskey(vessel, "M")
        M = maximum([5, convert(Int, ceil(L*1e3))])
    else
        m = vessel["M"]
        M = maximum([5, m, convert(Int, ceil(L*1e3))])
    end

    dx = L/M
    invDx = M/L
    halfDx = 0.5*dx

    return M, dx, invDx, halfDx
end


"""
    computeRadii(vessel_data :: Dict{Any,Any})

If only a constant lumen radius is defined, return the same value for proximal and
distal variables, `Rp` and `Rd`, respectively.
"""
function computeRadii(vessel :: Dict{Any,Any})

    if ~haskey(vessel, "R0")
        Rp = vessel["Rp"]
        Rd = vessel["Rd"]
        return Rp, Rd
    else
        R0 = vessel["R0"]
        return R0, R0
    end
end


"""
    computePext(vessel :: Dict{Any,Any})

Extract Pext value for current vessels; return default `Pext = 0.0` if no value is
specified.
"""
function computePext(vessel :: Dict{Any,Any})
    if ~haskey(vessel, "Pext")
        return 0.0
    else
        return vessel["Pext"]
    end
end

"""
    checkSections(data :: Dict{Any,Any})

Look for the four sections in the input data. Run integrity checks for `blood` and
`solver` sections.
"""
function checkSections(data :: Dict{Any,Any})
    keys = ["project name", "network", "blood", "solver"]
    for key in keys
        if ~haskey(data, key)
            error("missing section $key in YAML input file")
        end
    end

    checkSection(data, "blood", ["mu", "rho"])
    checkSection(data, "solver", ["Ccfl", "cycles", "jump", "convergence tollerance"])
end


"""
    checkSection(data :: Dict{Any,Any}, section :: String, keys :: Array{String,1})

Look for a list of keys in the generic data section.
"""
function checkSection(data :: Dict{Any,Any}, section :: String, keys :: Array{String,1})
    for key in keys
        if ~haskey(data[section], key)
            error("missing $key in $section section")
        end
    end
end


"""
    checkNetwork(network :: Array{Dict{Any,Any},1})

Loop trough the network and run check on each single vessel. Check also if at least one
inlet and one oulet has been defined.
"""
function checkNetwork(network :: Array{Dict{Any,Any},1})
    has_inlet = false
    has_outlet = false
    for i = 1:length(network)
        checkVessel(i, network[i])

        if haskey(network[i], "inlet")
            has_inlet = true
        end
        if haskey(network[i], "outlet")
            has_outlet = true
        end
    end

    if ~has_inlet
        error("missing inlet(s) definition")
    end

    if ~has_outlet
        error("missing outlet(s) definition")
    end
end


"""
    checkVessel(i :: Int, vessel :: Dict{Any,Any})

Check if all the important parameters are defined for the current vessel. If the vessel
has been indicated to be an inlet/outlet segment, check also for the definition of
boundary condition parameters.
"""
function checkVessel(i :: Int, vessel :: Dict{Any,Any})
    keys = ["label", "sn", "tn", "L", "E"]
    for key in keys
        if ~haskey(vessel, key)
            error("vessel $i is missing $key value")
        end
    end

    if ~haskey(vessel, "R0")
        if ~haskey(vessel, "Rp") || ~haskey(vessel, "Rd")
            error("vessel $i is missing lumen radius value(s)")
        end
    end

    if haskey(vessel, "inlet")
        if ~haskey(vessel, "inlet file")
            error("inlet vessel $i is missing the inlet file path")
        elseif ~isfile(vessel["inlet file"])
            file_path = vessel["inlet file"]
            error("vessel $i inlet file $file_path not found")
        end

        if ~haskey(vessel, "inlet number")
            error("inlet vessel $i is missing the inlet number")
        end
    end

    if haskey(vessel, "outlet")
        outlet = vessel["outlet"]
        if outlet == "wk3"
            if ~haskey(vessel, "R1") || ~haskey(vessel, "Cc")
                error("outlet vessel $i is missing three-element windkessel values")
            end
        elseif outlet == "wk2"
            if ~haskey(vessel, "R1") || ~haskey(vessel, "Cc")
                error("outlet vessel $i is missing two-element windkessel values")
            end
        elseif outlet == "reflection"
            if ~haskey(vessel, "Rt")
                error("outlet vessel $i is missing reflection coefficient value")
            end
        end
    end
end
