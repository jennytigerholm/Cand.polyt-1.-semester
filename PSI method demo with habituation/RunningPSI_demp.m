
%% Setup (PSI METHODE 1/3) 
clc 
clear 
close all; 

disp('Demo shows PSI method')
disp('Simulated data habituate between stimulation with 0.1% factor')
disp('Habituation continuous between trials'); 

% Sets up variables 
NumStimulation = 100;  % Number of stimulations
coef = 1.002; % Habituation coefficience
windowSize = 10; % Size of the moving window
grain     = 50; % Resolution of the parameters during the code
StimulationResolution = 50; % Resolution of the stimulation

% The psykometric function - saves in a struct "PM"
PM.PF = @LogisticFunc;

%parameter to simulate the subject
paramsGen = [5, 2, .02, .02]; 

%Stimulus values the method can select from
PM.stimRange = (linspace(PM.PF([paramsGen(1) paramsGen(2) 0 0],.01,'inverse'),PM.PF([paramsGen(1) paramsGen(2) 0 0],.99,'inverse'),StimulationResolution));

%Define parameter ranges to be included in posterior
priorAlphaRange = linspace(PM.PF([paramsGen(1) paramsGen(2) 0 0],.01,'inverse'),PM.PF([paramsGen(1) paramsGen(2) 0 0],.99,'inverse'),grain);
priorBetaRange =  linspace(log10(.0625),log10(5),grain); %OBS. Stated in Log!
priorGammaRange = .02;  
priorLambdaRange = .02; 

% saves the prior values in the PM-struct (calculates every possible
% output) - almost the same as a meshgrid
[PM.priorAlphas, PM.priorBetas, PM.priorGammas, PM.priorLambdas] = ndgrid(priorAlphaRange,priorBetaRange,priorGammaRange,priorLambdaRange);

%PDF
    % "First, a prior probability distribution p0(lambda) for the 
    % psychometric functions must be set up" [Kontsevich]
    prior = ones(length(priorAlphaRange),length(priorBetaRange),length(priorGammaRange),length(priorLambdaRange));% Construcs matrix of 1, of the size of the parameters
    % numel: total number of elements - so that 1/40401 = 2.475*10^-5,
    % which is the propability before a stimuli
    prior = prior./numel(prior); % Total number of elements in the prior
    PM.pdf = prior;  % Saves the prior in the PM struct 
  
%LOOK UP TABEL (LUT)
    % "Second, to speed up the method, a look-up table of conditional
    % probabilities p(r|lambda,x) should be computed" [Kontsevich]
    for a = 1:length(priorAlphaRange)
        for b = 1:length(priorBetaRange) %OBS. Not calculated in log!
            for g = 1:length(priorGammaRange)
                for L = 1:length(priorLambdaRange) 
                    for sLevel = 1:length(PM.stimRange)
                        % Probability of a correct response at a given
                        % parameter combination and intensity
                        PM.LUT(a,b,g,L,sLevel) = PM.PF([priorAlphaRange(a), 10.^priorBetaRange(b), priorGammaRange(g), priorLambdaRange(L)], PM.stimRange(sLevel));
                    end
                end
            end
        end 
    end

%% Deletes unessary variables
    clear a b g L sLevel 
    clear StimulationResolution  
%% Ask whether we should present plot or not    
    doPlot = input('Do not plot (0), plot threshold (1) ?: ');
 
%% Setup plot (PSI METHODE 2/3) 

    if (doPlot) 
        figure(1) % Fit to the threshold and responses 
        xlim([1 NumStimulation])
        ylim([min(PM.stimRange) max(PM.stimRange)])

        %set(gcf, 'Position',  [40, 3010, 1000, 600])
        xlabel('Stimulation number') 
        ylabel('Stimulus intensity')
    end 
                  
                
%% Simulate data and update method (PSI METHODE 3/3) 

% Calculates the first window

% Step 1 to 2
    % Uses the function 'PosteriorNextTrialFunc', and puts the data ind the PM
    % struct - Uses the pdf and LUT to calculate the outcomes
    [PM.PosteriorNextTrailSuccess,PM.PosteriorNextTrialFailure,PM.pSuccessGivenx] = PosteriorNextTrailFunc(PM.pdf, PM.LUT);

% Step 3 to 5 
    % Uses the function 'EntropyFunc', to calculate the new intensity index
    % position. ~ is the logical 'not'
    [~, newIntensityIndexPosition] = EntropyFunc(PM.PosteriorNextTrailSuccess,PM.PosteriorNextTrialFailure, PM.pSuccessGivenx);

% Next stimulation intensity - calculates the stim range, from the new
% intensity
    PM.xCurrent = PM.stimRange(newIntensityIndexPosition);

% Redundand? Place the xCurrent on the first of x
    PM.x(1) = PM.xCurrent; 
% Creates a while loop, that loops until the length is not longer than the
% size of the window
while length(PM.x) <= windowSize 
    % Simulates the observer response - returns 1 or 0, if the response is
    % greater (1) or smaller than the output from the PF struct
    % coef^(length(PM.x) applies a linear increase, to the threshold. 
    responses(length(PM.x)) = rand(1) < PM.PF([paramsGen(1)*coef^(length(PM.x)) paramsGen(2) paramsGen(3) paramsGen(4)], PM.xCurrent);    %simulate observer
    
    % Updates the PM based on the response, this is done by the function
    % UpdateFunc
    PM = UpdateFunc(PM, responses(end) );
    
    % Plots data of the first stimuli (before the window starts moving)
    if (doPlot) 
        figure(1) 
        hold on;        
        plot(1:length(PM.x)-1, PM.threshold, 'b') % Threshold
        plot(length(PM.x)-1, paramsGen(1)*coef^(length(PM.x)), '.', 'color','#B1B1B1', 'linewidth',0.1) % Theroticaly assumed habituation

        figure(1) 
        hold on; 
        % Plots responses
        if responses(end) 
            plot(length(PM.x)-1,PM.x(end-1),'ok','MarkerFaceColor','k'); % Felt
        else 
            plot(length(PM.x)-1,PM.x(end-1),'or'); % Not felt
        end
    end
end 

% Makes a for loops that runs the remaining number of stimulations
for curPos = 1:(NumStimulation-windowSize) 
    
    % ???Why PM.x(end) and not PM.xCurrent as in the above??? 
    responses(length(PM.x)) = rand(1) < PM.PF([paramsGen(1)*coef^(length(PM.x)) paramsGen(2) paramsGen(3) paramsGen(4)], PM.x(end));    

    PM.pdf = prior;  % Reset prior values for each time the window moves, such that the probabilities for each point is the same
    
    % Makes for loop that moves the window
    for curWinPos = curPos+1:windowSize+curPos   
        [PM.PosteriorNextTrailSuccess,PM.PosteriorNextTrialFailure,PM.pSuccessGivenx] = PosteriorNextTrailFunc(PM.pdf, PM.LUT);
        if responses(curWinPos) == 1
            PM.pdf = PM.PosteriorNextTrailSuccess(:,:,:,:,find(PM.stimRange == PM.x(curWinPos))); 
        else
            PM.pdf = PM.PosteriorNextTrialFailure(:,:,:,:,find(PM.stimRange == PM.x(curWinPos)));
        end
        PM.pdf = PM.pdf./sum(sum(sum(sum(PM.pdf)))); 
    end 
    
    % Calculates probability of succes and failure from the values of the pdf and LUT
    [PM.PosteriorNextTrailSuccess,PM.PosteriorNextTrialFailure,PM.pSuccessGivenx] = PosteriorNextTrailFunc(PM.pdf, PM.LUT);
    
    % Threshold calculates for each x (x increases after each stimuli)
    PM.threshold(length(PM.x)) = sum(sum(sum(sum(PM.priorAlphas.*PM.pdf))));

    [~, newIntensityIndexPosition] = EntropyFunc(PM.PosteriorNextTrailSuccess,PM.PosteriorNextTrialFailure, PM.pSuccessGivenx);
    
    PM.xCurrent = PM.stimRange(newIntensityIndexPosition);
      
    PM.x(length(PM.x)+1) = PM.xCurrent;
    
    if (doPlot) 
        figure(1) 
        hold on;        
        plot(1:length(PM.x)-1, PM.threshold, 'b') % Threshold
        plot(length(PM.x)-1, paramsGen(1)*coef^(length(PM.x)), '.', 'color','#B1B1B1', 'linewidth',0.1) %theoreticcaly assumed habituation

        figure(1) 
        hold on; 
        if responses(end) 
            plot(length(PM.x)-1,PM.x(end-1),'ok','MarkerFaceColor','k');
        else 
            plot(length(PM.x)-1,PM.x(end-1),'or');
        end
        % Consider to make mesh grid over the pdf? 
    end
end 

