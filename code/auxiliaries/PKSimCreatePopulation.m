function [isCanceled, individuals] = PKSimCreatePopulation(populationSettings, xmlFile)
%PKSIMCREATEPOPULATION Creates physiology parameters of a population
%
%   [isCanceled, individuals] = PKSimCreatePopulation(populationSettings)
%
%       populationSettings (structure) : description of population demographics
%       (create default settings by the function DefaultPopulationSettings)
%       xmlFile (string): path of the simulation file -> generate ontogeny information
%           if xmlFile is empty, no ontogenies are generated

% Open Systems Pharmacology Suite;  http://open-systems-pharmacology.org 

individuals=[];

try
    
    isCanceled = loadPKSimMatlabDLL;
    if isCanceled
        return
    end
    
    %Simulation file
    if ~exist('xmlFile','var') || isempty(xmlFile) 
        % take default method and no ontogenies
        onto_path={};
    else
        initSimulation(xmlFile,'none','report','none');
        % ontogeniesInfo
        simulationIndex=1;
        [ise,descr]=existsParameter('*Ontogeny factor GI',simulationIndex,'parameterType','readOnly');
        if ise
            jCol=strcmpi(descr(1,:),'Path');
            onto_path=descr(2:end,jCol);
        else
            onto_path={};
        end
    end

    PopulationFactory=PKSim.Matlab.MatlabPopulationFactory;
    
    ontogenies = NET.createArray('PKSim.Matlab.MoleculeOntogeny', length(onto_path));
    for iO=1:length(onto_path)
        jj_tmp = strfind(onto_path{iO},object_path_delimiter);
        Molecule = onto_path{iO}(jj_tmp(end-1)+1:jj_tmp(end)-1);
        
        % at the moment, "Ontogeny like" is set = "Molecule". Later, this can be changed
        ontogeny = PKSim.Matlab.MoleculeOntogeny(Molecule, Molecule);
            
        ontogenies(iO) = ontogeny;
    end
        
    %---- create new population
    PKSimPopulationSettings = pksimPopulationSettingsFrom(populationSettings);
    result=PopulationFactory.CreatePopulation(PKSimPopulationSettings, ontogenies);
    
    %check no of individuals
    if result.Count ~= populationSettings.NumberOfIndividuals
        error('Could not create required number of individuals');
    end
    
    %---- convert returned values (NET array) into matlab struct array
    covariates=NET.invokeGenericMethod('System.Linq.Enumerable', 'ToArray', {'PKSim.Core.Model.IndividualCovariates'}, result.AllCovariates);
    parameterPaths=NET.invokeGenericMethod('System.Linq.Enumerable', 'ToArray', {'System.String'}, result.AllParameterPaths);
    
    allParameterInfos=NET.invokeGenericMethod('System.Linq.Enumerable', 'ToArray', {'PKSim.Core.Model.ParameterValues'},  result.AllParameterValues);
        
    numberOfParams = parameterPaths.Length;
    
    for individualIdx=1:result.Count
        individuals(individualIdx).Gender = char(covariates(individualIdx).Gender.Name);
        individuals(individualIdx).Race = char(covariates(individualIdx).Race.Name);
        
        individuals(individualIdx).ParameterInfos = [];
        
        for paramIdx=1:numberOfParams
            
            parameterInfo = allParameterInfos(paramIdx);
            
            individuals(individualIdx).ParameterInfos(paramIdx).Path  = char(parameterPaths(paramIdx));
            individuals(individualIdx).ParameterInfos(paramIdx).Value = double(parameterInfo.Values.Item(individualIdx-1));
            individuals(individualIdx).ParameterInfos(paramIdx).Percentile = double(parameterInfo.Percentiles.Item(individualIdx-1));
        end
    end
    
catch e
    if(isa(e, 'NET.NetException'))
        eObj = e.ExceptionObject;
        error(char(eObj.ToString));
    else
        rethrow(e);
    end
end

function PKSimPopulationSettings = pksimPopulationSettingsFrom(populationSettings)
    PKSimPopulationSettings = PKSim.Core.Snapshots.PopulationSettings;
    
    PKSimPopulationSettings.NumberOfIndividuals = populationSettings.NumberOfIndividuals;
    PKSimPopulationSettings.ProportionOfFemales = populationSettings.ProportionOfFemales;
    
    PKSimPopulationSettings.Age = parameterRangeFrom(populationSettings.MinAge, populationSettings.MaxAge, populationSettings.AgeUnit);
    PKSimPopulationSettings.Weight = parameterRangeFrom(populationSettings.MinWeight, populationSettings.MaxWeight, populationSettings.WeightUnit);
    PKSimPopulationSettings.Height = parameterRangeFrom(populationSettings.MinHeight, populationSettings.MaxHeight, populationSettings.HeightUnit);
    PKSimPopulationSettings.GestationalAge = parameterRangeFrom(populationSettings.MinGestationalAge, populationSettings.MaxGestationalAge, populationSettings.GestationalAgeUnit);
    PKSimPopulationSettings.BMI = parameterRangeFrom(populationSettings.MinBMI, populationSettings.MaxBMI, populationSettings.BMIUnit);

    originData = PKSim.Core.Snapshots.OriginData;
    originData.Species    = populationSettings.Species;
    originData.Population = populationSettings.Population;
    calculationMethods = NET.createArray('System.String', 1);
    calculationMethods(1)='SurfaceAreaPlsInt_VAR1';
    AddCalculationMethods(originData, calculationMethods);

    PKSimPopulationSettings.Individual = PKSim.Core.Snapshots.Individual;
    PKSimPopulationSettings.Individual.OriginData = originData;
 
function parameterRange = parameterRangeFrom(minValue, maxValue, unit)
    parameterRange      = PKSim.Core.Snapshots.ParameterRange;

    if ~isnan(minValue)
        parameterRange.Min  = minValue;
    end

    if ~isnan(maxValue)
        parameterRange.Max  = maxValue;
    end
    
    parameterRange.Unit = unit;
