function wildcard_preprocess()
% wildcard_preprocess   a function designed to preprocess a group of
%                       subjects using a custom designed preprocessing 
%                       routine in SPM12 or SPM8
%
% This script is designed to batch multiple subjects through a preprocessing
% pipeline designed to collect ALL AVAIABLE FUNCTIONAL RUNS USING WILDCARDS,
% and PREPROCESSING THEM ALLTOGETHER, realightning the images to the first
% image of the first run of the first collected functional run (caps added for empahsis).
%
% Assumes each subject has a high resolution anatomical in its 'anat' folder.
% If this is not the case this script will error out.
%
% Written by Kyle Kurkela, kyleakurkela@gmail.com 7/20/2015
% Updated 9/10/2015
% Updated Again, 5/2/2016
%
% See also: wildcard_parameters8, wildcard_parameters12

%% User Input

% User Input Step 1: The subjects array
% List the subjects to preprocess in a cell array
subjects = {   '20y415'  '20y297' '21y437' '22y422'  '21y299'   '18y404'  '20y461' '20y444'  '21y521'  '18y566' '21y534' '25y543' '23y546' '20y441' '20y455'  '23y452' '78o113' '80o128' '70o118'  '79o108'   '76o162' '81o125' '67o153' '71o193' '72o164'  '73o165' '80o121' '67o178'  '71o152' '69o144' '76o120' }; %     '20y396' '20y439' };%  }; % List of Subject IDs to batch through

% User Input Step 2: The Flag
% Set the flag to 1 to look at the parameters interactively in the GUI
% and 2 to actually run the parameters through SPM 12
flag     = 2;

% User Input 3: Wildcards
% Please specify a regular expression (google regular expressions) that
% will select only the the raw image functional series and the raw
% anatomical image respectively.
regularexpr.func = '^run.*\.img'; % \.nii 
regularexpr.anat = '^T1.*\.img';  % \.nii
wildcards.runs   = 'run*';

% User Input 4: Directories
%CHANGE for each new study
% Please secify the paths to the directories that hold the functional
% images and anatomic images respectively
directories.func    = 'S:\nad12\FAME8\Func_ret\';
directories.anat    = 'S:\nad12\FAME8\Anat_ret\';  %do I need to put in 'run2' in this path?  I tried it and it didn't work, but I'm not sure why it is errring out
directories.psfiles = 'S:\nad12\FAME8\psfiles\psfiles12\';
directories.spm     = 'S:\nad12\spm12\'; %added in from previous script
    
%% Routine

spm('defaults', 'FMRI'); % load SPM default options
spm_jobman('initcfg')    % Configure the SPM job manger

for csub = 1:length(subjects) % for each subject...
    
    subject_funcfolder = fullfile(directories.func,subjects{csub}); % create the path to this subjects' functional folder

    runs               = CollectFolderNames(subject_funcfolder, wildcards.runs); % using Kyle's function "CollectFolderNames" (see below)

    matlabbatch        = wildcard_parameters12_FAME(runs, subjects{csub}, regularexpr, directories); % using Kyle's "wilcard_parameters" subfuncion which is located in the same directory as this script,
                                                                                      % set the preprocessing parameters for this routine
    if flag == 1
        spm_jobman('interactive', matlabbatch)
        pause
    elseif flag == 2
        spm_figure('GetWin','Graphics');  % configure spm graphics window. Ensures a .ps file is saved during preprocessing
        cd(directories.psfiles)           % make psfiles the working directory. Ensures .ps file is saved in this directory
        spm_jobman('run', matlabbatch);   % run preprocessing
        
        % Rename the ps file from "spm_CurrentDate.ps" to "SubjectID.ps"
        temp = date;
        date_rearranged = [temp(end-3:end) temp(4:6) temp(1:2)];
        movefile(['spm_' date_rearranged '.ps'],sprintf('%s.ps',subjects{csub}))
    end

end


    
%% Sub Functions

    function foldernamecellarray = CollectFolderNames(folder,wildcard)
    % CollectFolderNames: Function designed for collecting folder names 
    % within a directory 'folder' using a specified wildcard 'wildcard'. 
    % Folder names are returned in a cell array. 
    %
    % Kyle A Kurkela, kyleakurkela@gmail.com

        fp      = fullfile(folder, wildcard);
        listing = dir(fp);
        count   = 0;
        for curLis = 1:length(listing)
            if strcmp(listing(curLis).name,'..') || strcmp(listing(curLis).name,'.')
            elseif listing(curLis).isdir
                count = count + 1;
                foldernamecellarray{count} = listing(curLis).name; %#ok<AGROW>
            end
        end
        
    end

end
