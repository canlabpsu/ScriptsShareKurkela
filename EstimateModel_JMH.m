function [] = EstimateModel()
% EstimateModel     function for estimating a GLM specified using the
%                   SpecifyModel. Allows user to display the
%                   trial type onsets/durations in the SPM Batch GUI
%
% See also:  SpecifyModel
%% User Input
% You should ONLY (!!!!!!) need to edit this highlighted section of the
% script.

% User Input Step 1: Directories

% Please specify the name of the current analysis, the directory the
% current analysis is in, and the directoy which houses the behavioral
% data.

Analysis.name = 'FAME_categorymodel_ret_hrf';
Analysis.dir  = fullfile('S:\nad12\FAME8\Analysis_ret\', Analysis.name);

Func.dir         = 'S:\nad12\FAME8\Func_ret\';
Func.wildcard    = '^wa.*\.nii'; %IS THIS SUPPOSED TO BE NII, HDR, or IMG?

% ^^^ This is supposed to be whatever file ending your data is. Look at the
% functional images. If they are .hdr and .img files, then use '^wa.*\.img'
% -Kyle

Func.motwildcard = '^rp_.*\.txt';

Mask.on   = 0;
Mask.dir  = 'path\to\mask\directory';
Mask.name = 'name_of_mask.img';

% User Input Step 2: Subjects

% Please list the subjects to model in a 1 x N cell array.

Subjects = {'20y396'}; %'20y439' '81o312' '83o197' '20y415' '21y437' '20y297' '22y422' '21y299' '18y404' '20y441' '20y444' '21y521' '18y566' '21y534' '25y543' '23y546' '20y441' '20y455' '23y452' '78o113' '80o128' '70o118' '79o108' '76o162' '81o125' '67o153' '71o193' '72o164' '73o165' '80o121' '67o178' '71o152' '69o144' '76o120' }; % List of Subject IDs to batch through
Runs	 = { 'run1' 'run2' 'run3' 'run4' 'run5' 'run6' };

% User Input Step 3: Model Specifics

% Each study is different, with a unique TR and a unique onset and
% duration unit. Please specify:
% -The units used (i.e., 'scans' or 'secs')
% -The TR or repition time

Model.units = 'secs';
Model.TR    = 2;

% User Input Step 4: Options

% Set the following jobman_option to 'interactive' to view in SPM parameters the GUI. 
% Press any key into the command window to continue to next one sample t test.
% Set the following jobman option to 'run' to skip the viewing of the
% SPM parameters in the GUI and go directly to running of the one
% sample t-tests

show          = 0; % 0 = input as multiple conditions file, 1 = input parameters for showing in GUI
jobman_option = 'interactive'; % interactive = show in GUI, run = run through SPM

% ^^^ Have you tried running this script in interactive mode? The script
% will try to display your estimate parameters in SPM's batch GUI. That way
% you can see if you are grabbing your functional images successfully -Kyle

    
%% Routine

clc
fprintf('Analysis: %s\n\n', Analysis.name)

fprintf('Gathering Data...\n\n')

spm('Defaults','FMRI')
spm_jobman('initcfg')

for curSub = 1:length(Subjects)
    % Set Study Specific Series Numbers

    fprintf('\n')
    fprintf('Subject: %s\n\n',Subjects{curSub})

    % Model Directory: directory containing this subject's model
    Model.directory = fullfile(Analysis.dir, Subjects{curSub});
    
    % If we are using a mask, create a path to the mask
    if Mask.on == 1
        Model.mask  = fullfile(Mask.dir, Subjects{curSub}, Mask.name);
    end

    % Find the SpecModel *.mat files. These should be in the model
    % directory, defined above
    SpecModelMats   = cellstr(spm_select('List', Model.directory, ['.*' Subjects{curSub} '.*\.mat']));
    
    %JMH commented out below bc of error later near LINE 118 where error
    %appears again: "error" previously appeared to be used as a function or command, conflicting with its use here as the name of a variable. A possible cause of this error is that you forgot to initialize the variable, or you have initialized it implicitly using load or eval.
    % If we do not find any *.mat files, give an error informing the user
    % that this has occured
    if cellfun('isempty', SpecModelMats)
        error('Could not find Specify Model *.mat files') %#ok<*NODEF>
    end
    
    % Determine number of runs from number of Model Spec *.mat files found
    NumOfRuns          = length(SpecModelMats);

    for i = 1:NumOfRuns
        fprintf('Run: %d\n', i)
        curFuncDir              = fullfile(Func.dir, Subjects{curSub}, Runs{i});
        Model.runs{i}.scans     = cellstr(spm_select('ExtFPList', curFuncDir, Func.wildcard, Inf));
        Model.runs{i}.multicond = fullfile(Model.directory, SpecModelMats{i});        % from Model Spec
        Model.runs{i}.motion    = spm_select('FPList', curFuncDir, Func.motwildcard); % from realignment
    end

    %% Set and Save the SPM job

    matlabbatch = setModelparams(Model, show, Mask.on);
    save(fullfile(Model.directory, 'Job.mat'), 'matlabbatch')

    %% Run the SPM job

    if strcmp(jobman_option,'interactive')
        fprintf('\n')
        fprintf('Displaying SPM Job...\n')
        spm_jobman(jobman_option, matlabbatch)
        pause
    elseif strcmp(jobman_option,'run')
        try
            spm_jobman(jobman_option, matlabbatch)
        catch ER %#ok<*NASGU>
            disp(ER)
            fprintf('ERROR ON: %s', Subjects{curSub})
        end
    end

end

%% Sub Functions

function matlabbatch = setModelparams(Model,show,mask)
    % Function designed to set the SPM parameters necessary to run a first
    % level model. Takes in structure Model:
    % Model
    %   .directory
    %   .units
    %   .TR
    %   .runs (1 x # of runs)
    %       .scans
    %       .multicond
    %       .motion

    onsets = [];
    durations = [];
    names = [];
    pmod = [];

    % Directory
    matlabbatch{1}.spm.stats.fmri_spec.dir = {Model.directory};

    % Model Parameters
    matlabbatch{1}.spm.stats.fmri_spec.timing.units   = Model.units;
    matlabbatch{1}.spm.stats.fmri_spec.timing.RT      = Model.TR;
    matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t  = 16;
    matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t0 = 1;

    % Session Specific
    for curRun = 1:length(Model.runs)
        matlabbatch{1}.spm.stats.fmri_spec.sess(curRun).scans = Model.runs{curRun}.scans; %#ok<*AGROW>
        if show == 0
            matlabbatch{1}.spm.stats.fmri_spec.sess(curRun).cond  = struct('name', {}, 'onset', {}, 'duration', {}, 'tmod', {}, 'pmod', {});
            matlabbatch{1}.spm.stats.fmri_spec.sess(curRun).multi = {Model.runs{curRun}.multicond};
        elseif show == 1
            load(Model.runs{curRun}.multicond)
            for curTrialType = 1:length(names)
                matlabbatch{1}.spm.stats.fmri_spec.sess(curRun).cond(curTrialType).name     = names{curTrialType};
                matlabbatch{1}.spm.stats.fmri_spec.sess(curRun).cond(curTrialType).onset    = onsets{curTrialType};
                matlabbatch{1}.spm.stats.fmri_spec.sess(curRun).cond(curTrialType).duration = durations{curTrialType};
                matlabbatch{1}.spm.stats.fmri_spec.sess(curRun).cond(curTrialType).tmod     = 0;
                if isempty(pmod(curTrialType).name{1})
                    matlabbatch{1}.spm.stats.fmri_spec.sess(curRun).cond(curTrialType).pmod = struct('name', {}, 'param', {}, 'poly', {});
                else
                    matlabbatch{1}.spm.stats.fmri_spec.sess(curRun).cond(curTrialType).pmod.name  = pmod(curTrialType).name{1};
                    matlabbatch{1}.spm.stats.fmri_spec.sess(curRun).cond(curTrialType).pmod.param = pmod(curTrialType).param{1};
                    matlabbatch{1}.spm.stats.fmri_spec.sess(curRun).cond(curTrialType).pmod.poly  = pmod(curTrialType).poly{1};
                end
            end
        end
        matlabbatch{1}.spm.stats.fmri_spec.sess(curRun).regress   = struct('name', {}, 'val', {});
        matlabbatch{1}.spm.stats.fmri_spec.sess(curRun).multi_reg = {Model.runs{curRun}.motion};
        matlabbatch{1}.spm.stats.fmri_spec.sess(curRun).hpf       = 128;
    end

    % Misc
    matlabbatch{1}.spm.stats.fmri_spec.fact = struct('name', {}, 'levels', {});
    matlabbatch{1}.spm.stats.fmri_spec.bases.hrf.derivs = [0 0];
    matlabbatch{1}.spm.stats.fmri_spec.volt = 1;
    matlabbatch{1}.spm.stats.fmri_spec.global = 'None';
    if mask == 1
        matlabbatch{1}.spm.stats.fmri_spec.mask = {Model.mask};
    else
        matlabbatch{1}.spm.stats.fmri_spec.mask = {''};
    end
    matlabbatch{1}.spm.stats.fmri_spec.cvi = 'AR(1)';

    % Estimation
    matlabbatch{2}.spm.stats.fmri_est.spmmat(1) = cfg_dep;
    matlabbatch{2}.spm.stats.fmri_est.spmmat(1).tname = 'Select SPM.mat';
    matlabbatch{2}.spm.stats.fmri_est.spmmat(1).tgt_spec{1}(1).name  = 'filter';
    matlabbatch{2}.spm.stats.fmri_est.spmmat(1).tgt_spec{1}(1).value = 'mat';
    matlabbatch{2}.spm.stats.fmri_est.spmmat(1).tgt_spec{1}(2).name  = 'strtype';
    matlabbatch{2}.spm.stats.fmri_est.spmmat(1).tgt_spec{1}(2).value = 'e';
    matlabbatch{2}.spm.stats.fmri_est.spmmat(1).sname = 'fMRI model specification: SPM.mat File';
    matlabbatch{2}.spm.stats.fmri_est.spmmat(1).src_exbranch = substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1});
    matlabbatch{2}.spm.stats.fmri_est.spmmat(1).src_output = substruct('.','spmmat');
    matlabbatch{2}.spm.stats.fmri_est.method.Classical = 1;


end
    
end