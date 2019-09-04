function MotionFcn(FigH, EventData)
   
get(FigH, 'CurrentPoint');

%get current position within the figure
p = get(get(FigH, 'CurrentAxes'), 'CurrentPoint');

% get the bitmap matrix
I = FigH.Children(1).Children(1).CData;

%get FES device handle
FES = FigH.UserData.FES;

% check if in bounds
if(size(I,1)>= fix(p(1,2)) & size(I,2)>= fix(p(1,1)) & fix(p(1,1))>0 &   fix(p(1,2))>0 )
    %check if above white line
   if(FigH.Children(1).Children(1).CData( fix(p(1,2)),fix(p(1,1))))
        
        sound(sin(0.5*[0:200]),2000);
       
        if(FigH.UserData.LastStimTime>0)
            dt = etime(clock, FigH.UserData.LastStimTime);
            bMayStim = dt > FigH.UserData.RefractoryPeriod;
        else
            bMayStim = true;
        end;
            
        if(FigH.UserData.GreenLight==1 & bMayStim)
            sound(sin(1.5*[0:200]),2000);
            FES.displayTextTopScreen('text');
            disp('stim')
            FigH.UserData.LastStimTime = clock;
        else
            disp('no stim');
        end
        
   end;
end;
   
    

