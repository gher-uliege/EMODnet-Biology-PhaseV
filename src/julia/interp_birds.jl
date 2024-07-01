### A Pluto.jl notebook ###
# v0.19.43

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ 4f3afffe-3231-11ef-0aea-8b6c089d68a1
begin
	using CSV
	using PyPlot
	using Dates
	using DelimitedFiles, DataFrames
	const plt = PyPlot
	using Conda
	using PyCall	
	using PlutoUI
	mpl = pyimport("matplotlib")
	mpl.style.use("./emodnet.mplstyle")
	ccrs = pyimport("cartopy.crs")
	cfeature = pyimport("cartopy.feature")
	coast = cfeature.GSHHSFeature(scale="i")
	datacrs = ccrs.PlateCarree();
end

# ╔═╡ fff8d665-c770-4f34-a585-64b912bdb7ac
pwd()

# ╔═╡ 3a20f6b1-2f91-46f8-a32a-920572487c08
begin
	domain = (-40, 21, 14., 65.)
	
	datadir = "/home/ctroupin/data/EMODnet/Biology/dwca-esas-v1.3"
	figdir = "../../figures"
	datafileevent = joinpath(datadir, "event.txt")
	datafileevent2 = joinpath(datadir, "event_small.txt")
	datafileoccur = joinpath(datadir, "occurrence.txt")
	isdir(figdir) ? @debug("Already created") : mkpath(figdir)
	isfile(datafileevent) & isfile(datafileoccur)

end

# ╔═╡ daba0abb-89d1-48e0-83b1-bd0a575302df
function read_data_event(datafile::AbstractString, thedateformat=dateformat"y-m-dTH:M:SZ")
    open(datafile, "r") do df
        firstline = readline(df)
        column_names = split(firstline, "\t")
        
        ncolumns = length(column_names)
        @info("Number of columns: $(ncolumns)")
        
        lon_column = findfirst(occursin.("decimalLongitude", column_names))
        lat_column = findfirst(occursin.("decimalLatitude", column_names))
        date_column = findfirst(occursin.("eventDate", column_names))
        id_column = findfirst(occursin.("eventID", column_names))
        
        @info("Column index for longitude: $(lon_column); for latitude: $(lat_column)")
        
        lon = Float64[]
        lat = Float64[]
        dates = Dates.DateTime[]
        eventID = String[]
        
        for lines in readlines(df)
            linesplit = split(lines, "\t")
            
            if linesplit[2] == "subSample"
                push!(lon, parse(Float64, linesplit[lon_column]))
                push!(lat, parse(Float64,linesplit[lat_column]))
                push!(dates, DateTime(linesplit[date_column], thedateformat))
                push!(eventID, linesplit[id_column])
            end
        end
        
        
        return lon::Array{Float64}, lat::Array{Float64}, dates::Vector{DateTime}, eventID::Vector{String}
    end
end

# ╔═╡ 3f38fd3e-169a-4dad-87a5-6f4944b5fff3
function read_data_occurence(datafile::AbstractString)
    open(datafile, "r") do df
        firstline = readline(df)
        column_names = split(firstline, "\t")
        
        ncolumns = length(column_names)
        println(column_names)
        @info("Number of columns: $(ncolumns)")
        
        scientificName_column = findfirst(column_names .== "scientificName")
        eventID_column = findfirst(column_names .== "eventID")
        individualCount_column = findfirst(column_names .== "individualCount")

        individualCount = Int64[]
        scientificName = String[]
        eventID = String[]
       
        for lines in readlines(df)
            linesplit = split(lines, "\t")
            
            push!(scientificName, linesplit[scientificName_column])
            push!(eventID, linesplit[eventID_column])
            push!(individualCount, parse(Int64, linesplit[individualCount_column]))
        end
        
        
        return scientificName::Vector{String}, eventID::Vector{String}, individualCount::Vector{Int64}
    end
end

# ╔═╡ e0ce750d-f647-4c9e-8298-4854369ef517
@time lon, lat, dates, eventID = read_data_event(datafileevent);

# ╔═╡ d9873211-17ea-4e06-b8fb-33f563d4bd17
md"""
### Time histogram of the observations
"""

# ╔═╡ dc206012-3ca2-4fea-886e-9ecd09353c77
begin 
	fig1 = plt.figure()
	ax1 = plt.subplot(111)
	ax1.hist(dates, bins=40)
	figname1 = joinpath(figdir, "time_histogram.jpg")
	plt.savefig(figname1)
	plt.close(fig1)
	PlutoUI.LocalResource(figname1)
end

# ╔═╡ 57b4b501-fed0-4c63-8ffb-e32ceec7adf6
md"""
### Location of all the observations
"""

# ╔═╡ 594ac3a2-5487-4ea1-8414-aa1a74e7775b
begin
	fig2 = plt.figure(figsize=(12, 8))
	ax2 = plt.subplot(111, projection=ccrs.Mercator())
	ax2.set_extent(domain)
	ax2.plot(lon, lat, "o", color="#00670A", ms=1, transform=datacrs, zorder=5)
	ax2.add_feature(coast, linewidth=.2, color=".5", zorder=4)
	gl2 = ax2.gridlines(crs=ccrs.PlateCarree(), draw_labels=true,
	                  linewidth=.5, color="gray", alpha=0.5, linestyle="--")
	gl2.top_labels = false
	gl2.right_labels = false
	ax2.set_title("All events")
	figname2 = joinpath(figdir, "events.jpg")
	plt.savefig(figname2)
	plt.close(fig2)
	PlutoUI.LocalResource(figname2)
end

# ╔═╡ 6a56938f-0fcd-4e64-a7fe-c21f86af3f38
begin
	@info("Reading data from $(datafileoccur)")
	scientificName, eventID_occurence, count = read_data_occurence(datafileoccur);
	scientificNameUnique = unique(scientificName);
end

# ╔═╡ c3ba8499-d22c-4786-84b2-680670763c6b
md"""
## Select the species of interest in the list
"""

# ╔═╡ 6779ce65-66d6-42c3-b6dd-7c6579d74011
@bind myspecies Select(scientificNameUnique)

# ╔═╡ 95560b10-63f8-437c-b2e1-e164476429ad
@info("Working on species: $(myspecies)")

# ╔═╡ 705ec685-0284-4d37-a6f7-da0a3aff3e72
begin
	speciesindex = findall(scientificName .== myspecies)
	@info("Found $(length(speciesindex)) events for '$(myspecies)'")
	speciesevent = eventID_occurence[speciesindex]
	speciescount = count[speciesindex];

	@time specieseventUnique = unique(speciesevent)
	numEvents = length(specieseventUnique)
	@info("Found $(numEvents) unique events")
	speciesCountTotal = zeros(Int64, numEvents)
	for (iii, ss) in enumerate(specieseventUnique)
	    # Find line indices
	    eventindex = findall(speciesevent .== ss)
	    # Sum the count of those lines
	    speciesCountTotal[iii] = sum(speciescount[eventindex])
	end
	
end

# ╔═╡ fad6ca05-e84b-4342-a5fc-e45cc0127aa2
begin
	nevents = length(specieseventUnique)
	lonspecies = Vector{Float64}(undef, nevents)
	latspecies = Vector{Float64}(undef, nevents)
	datesspecies = Vector{DateTime}(undef, nevents)
	
	for (iii, sss) in enumerate(specieseventUnique)
	    lineindex = findfirst(eventID .== sss)
	    lonspecies[iii] = lon[lineindex]
	    latspecies[iii] = lat[lineindex]
	    datesspecies[iii] = dates[lineindex]
	end
end

# ╔═╡ 8854d048-0288-47fe-ab5a-bb7672be60ea
begin
	fig3 = plt.figure(figsize=(12, 8))
	ax3 = plt.subplot(111, projection=ccrs.Mercator())
	ax3.set_extent(domain)
	scat = ax3.scatter(lonspecies, latspecies, s=3, c=speciesCountTotal, transform=datacrs, zorder=5)
	cb = plt.colorbar(scat)
	ax3.add_feature(coast, linewidth=.2, color=".5", zorder=4)

	ax3.set_extent(domain)
	gl3 = ax3.gridlines(crs=ccrs.PlateCarree(), draw_labels=true,
				  linewidth=.5, color="gray", alpha=0.5, linestyle="--")
	gl3.top_labels = false
	gl3.right_labels = false
	ax3.set_title("Observations of $(myspecies)")
	figname3 = joinpath(figdir, "observations.jpg")
	plt.savefig(figname3)
	plt.close(fig3)
	PlutoUI.LocalResource(figname3)
end

# ╔═╡ 5e1ca2cd-7049-42ca-9379-24f5a11ec797
md"""
## Perform DIVAnd heatmap computation
### 
"""

# ╔═╡ 7790b356-05c8-4272-b2d7-30aee0b702b6


# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
CSV = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
Conda = "8f4d0f93-b110-5947-807f-2305c1781a2d"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
Dates = "ade2ca70-3891-5945-98fb-dc099432e06a"
DelimitedFiles = "8bb1440f-4735-579b-a4ab-409b98df4dab"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
PyCall = "438e738f-606a-5dbb-bf0a-cddfbfd45ab0"
PyPlot = "d330b81b-6aea-500a-939a-2ce795aea3ee"

[compat]
CSV = "~0.10.14"
Conda = "~1.10.0"
DataFrames = "~1.6.1"
DelimitedFiles = "~1.9.1"
PlutoUI = "~0.7.50"
PyCall = "~1.96.4"
PyPlot = "~2.11.2"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.11.0-rc1"
manifest_format = "2.0"
project_hash = "7c67f73f666fe84b2183f4dfa2fc53c50240c2f9"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "6e1d2a35f2f90a4bc7c2ed98079b2ba09c35b83a"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.3.2"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.2"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"
version = "1.11.0"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"
version = "1.11.0"

[[deps.CSV]]
deps = ["CodecZlib", "Dates", "FilePathsBase", "InlineStrings", "Mmap", "Parsers", "PooledArrays", "PrecompileTools", "SentinelArrays", "Tables", "Unicode", "WeakRefStrings", "WorkerUtilities"]
git-tree-sha1 = "6c834533dc1fabd820c1db03c839bf97e45a3fab"
uuid = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
version = "0.10.14"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "59939d8a997469ee05c4b4944560a820f9ba0d73"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.4"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "b10d0b65641d57b8b4d5e234446582de5047050d"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.5"

[[deps.Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "362a287c3aa50601b0bc359053d5c2468f0e7ce0"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.11"

[[deps.Compat]]
deps = ["TOML", "UUIDs"]
git-tree-sha1 = "b1c55339b7c6c350ee89f2c1604299660525b248"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.15.0"
weakdeps = ["Dates", "LinearAlgebra"]

    [deps.Compat.extensions]
    CompatLinearAlgebraExt = "LinearAlgebra"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.1.1+0"

[[deps.Conda]]
deps = ["Downloads", "JSON", "VersionParsing"]
git-tree-sha1 = "b19db3927f0db4151cb86d073689f2428e524576"
uuid = "8f4d0f93-b110-5947-807f-2305c1781a2d"
version = "1.10.2"

[[deps.Crayons]]
git-tree-sha1 = "249fe38abf76d48563e2f4556bebd215aa317e15"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.1.1"

[[deps.DataAPI]]
git-tree-sha1 = "abe83f3a2f1b857aac70ef8b269080af17764bbe"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.16.0"

[[deps.DataFrames]]
deps = ["Compat", "DataAPI", "DataStructures", "Future", "InlineStrings", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrecompileTools", "PrettyTables", "Printf", "REPL", "Random", "Reexport", "SentinelArrays", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "04c738083f29f86e62c8afc341f0967d8717bdb8"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.6.1"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "1d0a14036acb104d9e89698bd408f63ab58cdc82"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.20"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"
version = "1.11.0"

[[deps.DelimitedFiles]]
deps = ["Mmap"]
git-tree-sha1 = "9e2f36d3c96a820c678f2f1f1782582fcf685bae"
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"
version = "1.9.1"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.FilePathsBase]]
deps = ["Compat", "Dates", "Mmap", "Printf", "Test", "UUIDs"]
git-tree-sha1 = "9f00e42f8d99fdde64d40c8ea5d14269a2e2c1aa"
uuid = "48062228-2e41-5def-b9a4-89aafe57970f"
version = "0.9.21"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"
version = "1.11.0"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "05882d6995ae5c12bb5f36dd2ed3f61c98cbb172"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.5"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"
version = "1.11.0"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "179267cfa5e712760cd43dcae385d7ea90cc25a4"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.5"

[[deps.HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "7134810b1afce04bbc1045ca1985fbe81ce17653"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.5"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "b6d6bfdd7ce25b0f9b2f6b3dd56b2673a66c8770"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.5"

[[deps.InlineStrings]]
deps = ["Parsers"]
git-tree-sha1 = "86356004f30f8e737eff143d57d41bd580e437aa"
uuid = "842dd82b-1e85-43dc-bf29-5d0ee9dffc48"
version = "1.4.1"

    [deps.InlineStrings.extensions]
    ArrowTypesExt = "ArrowTypes"

    [deps.InlineStrings.weakdeps]
    ArrowTypes = "31f734f8-188a-4ce0-8406-c8a06bd891cd"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"
version = "1.11.0"

[[deps.InvertedIndices]]
git-tree-sha1 = "0dc7b50b8d436461be01300fd8cd45aa0274b038"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.3.0"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "31e996f0a15c7b280ba9f76636b3ff9e2ae58c9a"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.4"

[[deps.LaTeXStrings]]
git-tree-sha1 = "50901ebc375ed41dbf8058da26f9de442febbbec"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.3.1"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.4"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "8.6.0+0"

[[deps.LibGit2]]
deps = ["Base64", "LibGit2_jll", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"
version = "1.11.0"

[[deps.LibGit2_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll"]
uuid = "e37daf67-58a4-590a-8e99-b0245dd2ffc5"
version = "1.7.2+0"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.11.0+1"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"
version = "1.11.0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
version = "1.11.0"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"
version = "1.11.0"

[[deps.MIMEs]]
git-tree-sha1 = "65f28ad4b594aebe22157d6fac869786a255b7eb"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "0.1.4"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "2fa9ee3e63fd3a4f7a9a4f4744a52f4856de82df"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.13"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"
version = "1.11.0"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.6+0"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "ec4f7fbeab05d7747bdf98eb74d130a2a2ed298d"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.2.0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"
version = "1.11.0"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2023.12.12"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.27+1"

[[deps.OrderedCollections]]
git-tree-sha1 = "dfdf5519f235516220579f949664f1bf44e741c5"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.6.3"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "8489905bcdbcfac64d1daa51ca07c0d8f0283821"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.8.1"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "Random", "SHA", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.11.0"
weakdeps = ["REPL"]

    [deps.Pkg.extensions]
    REPLExt = "REPL"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "ab55ee1510ad2af0ff674dbcced5e94921f867a9"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.59"

[[deps.PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "36d8b4b899628fb92c2749eb488d884a926614d3"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.3"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "5aa36f7049a63a1528fe8f7c3f2113413ffd4e1f"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.2.1"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "9306f6085165d270f7e3db02af26a400d580f5c6"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.4.3"

[[deps.PrettyTables]]
deps = ["Crayons", "LaTeXStrings", "Markdown", "PrecompileTools", "Printf", "Reexport", "StringManipulation", "Tables"]
git-tree-sha1 = "66b20dd35966a748321d3b2537c4584cf40387c7"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "2.3.2"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"
version = "1.11.0"

[[deps.PyCall]]
deps = ["Conda", "Dates", "Libdl", "LinearAlgebra", "MacroTools", "Serialization", "VersionParsing"]
git-tree-sha1 = "9816a3826b0ebf49ab4926e2b18842ad8b5c8f04"
uuid = "438e738f-606a-5dbb-bf0a-cddfbfd45ab0"
version = "1.96.4"

[[deps.PyPlot]]
deps = ["Colors", "LaTeXStrings", "PyCall", "Sockets", "Test", "VersionParsing"]
git-tree-sha1 = "9220a9dae0369f431168d60adab635f88aca7857"
uuid = "d330b81b-6aea-500a-939a-2ce795aea3ee"
version = "2.11.2"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "StyledStrings", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"
version = "1.11.0"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
version = "1.11.0"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.SentinelArrays]]
deps = ["Dates", "Random"]
git-tree-sha1 = "90b4f68892337554d31cdcdbe19e48989f26c7e6"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.4.3"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"
version = "1.11.0"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"
version = "1.11.0"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "66e0a8e672a0bdfca2c3f5937efb8538b9ddc085"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.2.1"

[[deps.Statistics]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "ae3bb1eb3bba077cd276bc5cfc337cc65c3075c0"
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.11.1"

    [deps.Statistics.extensions]
    SparseArraysExt = ["SparseArrays"]

    [deps.Statistics.weakdeps]
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.StringManipulation]]
deps = ["PrecompileTools"]
git-tree-sha1 = "a04cabe79c5f01f4d723cc6704070ada0b9d46d5"
uuid = "892a3eda-7b42-436c-8928-eab12a02cf0e"
version = "0.3.4"

[[deps.StyledStrings]]
uuid = "f489334b-da3d-4c2e-b8f0-e476e12c162b"
version = "1.11.0"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "OrderedCollections", "TableTraits"]
git-tree-sha1 = "cb76cf677714c095e535e3501ac7954732aeea2d"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.11.1"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
version = "1.11.0"

[[deps.TranscodingStreams]]
git-tree-sha1 = "d73336d81cafdc277ff45558bb7eaa2b04a8e472"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.10.10"
weakdeps = ["Random", "Test"]

    [deps.TranscodingStreams.extensions]
    TestExt = ["Test", "Random"]

[[deps.Tricks]]
git-tree-sha1 = "eae1bb484cd63b36999ee58be2de6c178105112f"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.8"

[[deps.URIs]]
git-tree-sha1 = "67db6cc7b3821e19ebe75791a9dd19c9b1188f2b"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.5.1"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"
version = "1.11.0"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"
version = "1.11.0"

[[deps.VersionParsing]]
git-tree-sha1 = "58d6e80b4ee071f5efd07fda82cb9fbe17200868"
uuid = "81def892-9a0e-5fdd-b105-ffc91e053289"
version = "1.3.0"

[[deps.WeakRefStrings]]
deps = ["DataAPI", "InlineStrings", "Parsers"]
git-tree-sha1 = "b1be2855ed9ed8eac54e5caff2afcdb442d52c23"
uuid = "ea10d353-3f73-51f8-a26c-33c1cb351aa5"
version = "1.4.2"

[[deps.WorkerUtilities]]
git-tree-sha1 = "cd1659ba0d57b71a464a29e64dbc67cfe83d54e7"
uuid = "76eceee3-57b5-4d4a-8e66-0e911cebbf60"
version = "1.6.1"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+1"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.8.0+1"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.59.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+2"
"""

# ╔═╡ Cell order:
# ╠═4f3afffe-3231-11ef-0aea-8b6c089d68a1
# ╠═fff8d665-c770-4f34-a585-64b912bdb7ac
# ╠═3a20f6b1-2f91-46f8-a32a-920572487c08
# ╟─daba0abb-89d1-48e0-83b1-bd0a575302df
# ╟─3f38fd3e-169a-4dad-87a5-6f4944b5fff3
# ╠═e0ce750d-f647-4c9e-8298-4854369ef517
# ╟─d9873211-17ea-4e06-b8fb-33f563d4bd17
# ╠═dc206012-3ca2-4fea-886e-9ecd09353c77
# ╟─57b4b501-fed0-4c63-8ffb-e32ceec7adf6
# ╠═594ac3a2-5487-4ea1-8414-aa1a74e7775b
# ╠═6a56938f-0fcd-4e64-a7fe-c21f86af3f38
# ╟─c3ba8499-d22c-4786-84b2-680670763c6b
# ╠═6779ce65-66d6-42c3-b6dd-7c6579d74011
# ╟─95560b10-63f8-437c-b2e1-e164476429ad
# ╠═705ec685-0284-4d37-a6f7-da0a3aff3e72
# ╠═fad6ca05-e84b-4342-a5fc-e45cc0127aa2
# ╠═8854d048-0288-47fe-ab5a-bb7672be60ea
# ╟─5e1ca2cd-7049-42ca-9379-24f5a11ec797
# ╠═7790b356-05c8-4272-b2d7-30aee0b702b6
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002