close all;
clear all;

%set working directory. It has to contain FES.m and ActiveTouchPattern
%images 
WorkingDirectory = '/home/aos/MyProjects/MegaLab/Code/M';

% set basic parameters
FES_offline = 1;
RefractoryPeriod =2; % refractory period, seconds  
NumberOfTrials = 10; 
TrialDuration =   5; % seconds
HideImage = false;

% load ActiveTouchPatternImages
cd(WorkingDirectory);
atp_files = dir('ATP_*.bmp');

for  k = 1:length(atp_files)
    tmp = imread(atp_files(k).name);
    %invert and downsample
    atp(:,:,k) = ~tmp(1:2:end,1:2:end);
end;

%read question and exclamation  mark image
tmp = imread(strcat(WorkingDirectory ,'/question_mark.bmp'));
question_mark = ~tmp(1:2:end,1:2:end);    

tmp = imread(strcat(WorkingDirectory ,'/exclamation_mark.bmp'));
exclamation_mark = ~tmp(1:2:end,1:2:end);    

%initialize FES device 
fes = FES('COM1', 38400, FES_offline);

%intialize timer
timer = [];

%create UserData structure as a vehicle to transfer information into the
%MotionFcn callback of the figure called every time the cursor moves
UserData.FES = fes;
UserData.Timer = timer;
UserData.GreenLight = 0; % if this one is 1 then stimulation will happen otherwise it will be idle.
UserData.LastStimTime = -1; %clock;
UserData.RefractoryPeriod = RefractoryPeriod;

close all
% load the first image and create the figure
FigTaskH = figure;
FigTaskH.UserData = UserData;
imagesc(exclamation_mark,'Parent', FigTaskH, 'Parent', axes('Parent',FigTaskH));
set(FigTaskH.Children,'Visible','off');
set(get(FigTaskH.Children,'Title'),'Visible','on');
                
% create Answers pane
FigAnswerH = figure;
im = reshape(atp, size(atp,1), size(atp,2)*size(atp,3))+1;
for i=1:size(atp,3)
    im(:,size(atp,2)*i-1:size(atp,2)*i+1) =0;
end; 
h = imagesc(im, 'Parent', axes('Parent',FigAnswerH));
cmap = get(FigAnswerH, 'Colormap');
cmap(1,:) = 0;
set(FigAnswerH,'Colormap',cmap);
set(FigAnswerH.Children,'Visible','off');
set(get(FigAnswerH.Children,'Title'),'Visible','on');

%set the callback function 
set(FigTaskH,'WindowButtonMotionFcn', @MotionFcn);

disp('Resize windows, make patient comfortable and press any button')
pause;

cmap = FigTaskH.Colormap;
Response = zeros(NumberOfTrials,2);
%main loop
for tr = 1:NumberOfTrials
    FigTaskH.Children(1).Children(1).CData = exclamation_mark;
    pause(2)
    k = rem(tr,size(atp,3))+1;
    FigTaskH.UserData.GreenLight = 0;
    FigTaskH.Children(1).Children(1).CData = [atp(:,:,k)];
    if(HideImage==true)
        FigTaskH.Colormap = zeros(size(FigTaskH.Colormap));
    end;
    FigTaskH.UserData.GreenLight = 1;
    [tr,k]
    pause(TrialDuration);
    FigTaskH.UserData.GreenLight = 0;
    FigTaskH.Children(1).Children(1).CData = question_mark;
    if(HideImage==true)
        FigTaskH.Colormap = cmap;
    end;
    set(0, 'currentfigure', FigAnswerH);
    [x y] = ginput(1);
    k_subj = 1 + fix(x/size(atp,2));
    Response(tr,:) = [k k_subj]
end;
    
set(FigTaskH,'WindowButtonMotionFcn', '');
    
