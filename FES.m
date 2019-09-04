classdef FES<matlab.mixin.Copyable & matlab.mixin.Heterogeneous  
            %This module is designed as an interface between the MotionStim8 and PC. 
            %Each command used for MotionStim8 manipulation has the following name structure: 
            %[set][Attribute(Amplitude, Frequence and/or Pulswidth][Channel Range]
    
            
    properties(Access='private')
        baudrate;
        serial_device;
        serial_data;
        channel_count;
        myoffline_modus;
    end
    
    %------------------------------------------------------------------------
    %Constructor, Deconstructor, Getter
    
    
    methods
        function obj=FES(serialPort,baudrate,offlineModus)
            %FES constructor:
            %INPUT: serial_port: A char variable containing the name of the serial port the MotionStim 8 is connected to
            %INPUT: baudrate: An integer variable containing the serial port's baudrate (normaly around 38400)
            %INPUT: offlineModus when no FES-devise is connected set this to 1
            %DEFAULT SETTING: COM1 38400
%            obj.myoffline_modus = 0;
             obj.myoffline_modus = 1;
            if nargin < 3
                offlineModus = 0;
            elseif nargin == 3
                obj.myoffline_modus = offlineModus;
                if (offlineModus ~= 0 && offlineModus ~= 1)
                    obj.myoffline_modus = 0;
                end
            end
            if nargin<2
                baudrate=38400;
            end
            if nargin<1
                serialPort='COM1';
            end
            obj.serial_data = 0;
            obj.baudrate = baudrate;
            obj.channel_count = 8;
            
            if obj.myoffline_modus == 0
                obj.serial_device=serial(serialPort);
                try
                    fopen(obj.serial_device);
                    set(obj.serial_device,'BaudRate',obj.baudrate,'DataBits',8,'Parity','none','FlowControl','none','StopBits',1,'Timeout',1); %baudrate 38400
                    obj.readVersion();
                    
                catch
                    msgID = 'FES:inputError';
                    msgtext = 'Couldnt open serial port';
                    display(['Please check FES!!!' msgtext]);
                    ME = MException(msgID,msgtext);
                    throw(ME);
                end
                pause(0.5);
            end
        end
        
        function delete(obj)
            %Deactivates (amplitude and pulsewidth to 0) all known channels and closes the port
            if obj.myoffline_modus == 0
                for n = 1:obj.channel_count
                    obj.setAmpPwidthSingle(n,0,0);
                end
                fclose(obj.serial_device);
            end
        end
        %get_baudrate
        function baudrate = getBaudrate(obj)
            %Read the baudrate
            baudrate = obj.baudrate;
        end
        
        %serial_device = get_serial_device
        function serialDevice=getSerialDevice(obj)
            %Get the opened port
            if obj.myoffline_modus == 0
                serialDevice = obj.serial_device;
            else
                serialDevice = NaN;
            end
        end
        %serial_data = get_serial_data
        function serialData=getSerialData(obj)
            %Read data from port
            serialData = obj.serial_data;
        end
        %channel_count = get_channel_count
        function channelN=getChannelN(obj)
            %Get the channel count%Get the number of stimulationchannels
            channelN = obj.channel_count;
        end
        
        
        
        %------------------------------------------------------------------------
        %       Interface Program|Stimulation
        %setAmpAndPwidth_Single 
        function setAmpPwidthSingle(obj,channelNr,mA,pulsewidth)
            %Set the amplitude and pulsewidth for a single channel. 
            %INPUT: channelNr: Between 1 and maximal channel count
            %INPUT: mA: Between 0 and 125 
            %INPUT: pulswidth: Between 0 and 500.
            %           Below 10 the channel will not be activated
            if obj.myoffline_modus == 0
                sof=[255,255];
                databytesCount=4;
                cmdNr=1;
                performComputung=1;

                %deleting prior data
                obj.serial_data = 0;

                %Input Controll
                if(channelNr<1 || channelNr>obj.channel_count)
                    performComputung=0;
                end
                if(mA<0 || mA>125)
                    performComputung=0;
                end
                if((mA-floor(mA))==0.5)
                    mA=mA+127;
                end
                if(pulsewidth<0 || pulsewidth>500)
                    performComputung=0;
                end

                %Command
                if(performComputung)
                    %Variable preparation
                    pulseWithC=[0, 0];
                    if(pulsewidth>256)
                        pulseWithC(1)=1;
                        pulsewidth=pulsewidth-256;
                        pulseWithC(2)=pulsewidth;
                    else
                        pulseWithC(2)=pulsewidth;
                    end
                    %Try to write to serial port
                    try
                        checksum=mod(sum([databytesCount,cmdNr,channelNr,mA,pulseWithC(1),pulseWithC(2)]),256 );
                        cmd=[sof(1),sof(2),databytesCount,cmdNr,channelNr,mA,pulseWithC(1),pulseWithC(2),checksum];
                        fwrite(obj.serial_device,cmd);
                        %Wait for writeback
                        timer_setAmpAndPwidth_Single = tic;
                        time_notchanged = 0;
                        bytes=0;
                        while (time_notchanged < 6 || bytes < 3)%obj.serial_device.BytesAvailable<6)
                            time_notchanged = round(toc(timer_setAmpAndPwidth_Single) * 1000);
                            if (bytes < obj.serial_device.BytesAvailable)
                                bytes = obj.serial_device.BytesAvailable;
                                time_notchanged = 0;
                                timer_setAmpAndPwidth_Single = tic;
                            end
                            if (time_notchanged > 3000)
                                msgID = 'FES:outputError';
                                msgtext = 'Couldnt write Amplitude and Pulsewidth to FES Channel';
                                ME = MException(msgID,msgtext);
                                throw(ME);
                            end
                        end
                        %                     while (obj.serial_device.BytesAvailable<3)
                        %                         pause(0.01);
                        %                     end
                        obj.serial_data = fread(obj.serial_device,obj.serial_device.BytesAvailable);
                    catch e
                        display(e);
                    end

                end
            end
        end
        
        %setAmp_Multi
        function setAmpMulti(obj,mA)
            %Set the amplitude for multiple channels. 
            %INPUT: mA: A vector of values between 0 and 125. 
            %SHORT DESCRIPTION: set the amplitude for the first X channel, 
            %where X is the number of values in the amplitude vector. 
            %E.g.: The vector [10 20 1] will add the
            %given mA settings to the channels 1 - 3 respectively
            if obj.myoffline_modus == 0
                sof=[255,255];
                databytesCount=length(mA);
                cmdNr=5;
                performComputung=1;

                %deleting prior data
                obj.serial_data = 0;

                %Input Controll
                if (length(mA)<0||length(mA)>obj.channel_count)
                    performComputung=0;
                end

                for m = 1:length(mA)
                    if(mA(m)<0 || mA(m)>125)
                        performComputung=0;
                    end
                    if((mA(m)-floor(mA(m)))==0.5)
                        mA(m)=mA(m)+127;
                    end
                end

                %Command
                if(performComputung)
                    %Variable preparation
                    %Try to write to serial port

                    try
                        checksum=mod(sum([databytesCount,cmdNr,mA]),256 );
                        cmd=[sof(1),sof(2),databytesCount,cmdNr,mA,checksum];
                        fwrite(obj.serial_device,cmd);
                        %Wait for writeback
                        timer_setAmp_Multi = tic;
                        time_notchanged = 0;
                        bytes=0;
                        while (time_notchanged < 6 || bytes < 3)%obj.serial_device.BytesAvailable<6)
                            time_notchanged = round(toc(timer_setAmp_Multi) * 1000);
                            if (bytes < obj.serial_device.BytesAvailable)
                                bytes = obj.serial_device.BytesAvailable;
                                time_notchanged = 0;
                                timer_setAmp_Multi = tic;
                            end
                            if (time_notchanged > 3000)
                                msgID = 'FES:outputError';
                                msgtext = 'Couldnt write Amplitudes to FES';
                                ME = MException(msgID,msgtext);
                                throw(ME);
                            end
                        end
                        obj.serial_data = fread(obj.serial_device,obj.serial_device.BytesAvailable);
                    catch e
                        display(e);
                    end

                end
            end
        end
        
        %setAmp_Global
        function setAmpGlobal(obj,mA)
            %Set the amplitude for all MotionStim channels. 
            %INPUT: mA: Between 0 and 125. 
            
            %deleting prior data
            if obj.myoffline_modus == 0
                obj.serial_data = 0;
                performComputung = 1;
                %Input Controll
                if(mA<0 || mA>125)
                    performComputung=0;
                end
                if((mA-floor(mA))==0.5)
                    mA=mA+127;
                end
                mAC = ones(1,obj.channel_count)*mA;
%                 for m = 1:obj.channel_count
%                     mAC = [mAC mA];
%                 end

                %Command
                if(performComputung)
                    %Variable preparation
                    %Try to write to serial port

                    try
                        obj.setAmpMulti(mAC);
                    catch ME
                        msgID = 'FES:outputError';
                        msgtext = 'Couldnt write Amplitudes to FES';
                        ME = MException(msgID,msgtext);
                        throw(ME);
                    end

                end
            end
        end
        
        
        
        %setFreq_Global
        function setFreqGlobal(obj,freq)
            %Set the frequency for each MotionStim channel
            %INPUT: freq: Between 1 and 99
            if obj.myoffline_modus == 0
                sof=[255,255];
                databytesCount=1;
                cmdNr=2;
                performComputung=1;

                %deleting prior data
                obj.serial_data = 0;

                %Input Controll
                if(freq<1 || freq>99)
                    performComputung=0;
                end

                %Command
                if(performComputung)
                    %Variable preparation
                    %Try to write to serial port
                    %
                    try
                        checksum=mod(sum([databytesCount,cmdNr,freq]),256 );
                        cmd=[sof(1),sof(2),databytesCount,cmdNr,freq,checksum];
                        fwrite(obj.serial_device,cmd);
                        %Wait for writeback
                        timer_setFreq_Global = tic;
                        time_notchanged = 0;
                        bytes=0;
                        while (time_notchanged < 6 || bytes < 3)%obj.serial_device.BytesAvailable<6)
                            time_notchanged = round(toc(timer_setFreq_Global) * 1000);
                            if (bytes < obj.serial_device.BytesAvailable)
                                bytes = obj.serial_device.BytesAvailable;
                                time_notchanged = 0;
                                timer_setFreq_Global = tic;
                            end
                            if (time_notchanged > 10000)
                                msgID = 'FES:outputError';
                                msgtext = 'Couldnt write Frequency to FES';
                                ME = MException(msgID,msgtext);
                                throw(ME);
                            end
                        end
                        %                      while (obj.serial_device.BytesAvailable<3)
                        %                          pause(0.01);
                        %                      end
                        obj.serial_data = fread(obj.serial_device,obj.serial_device.BytesAvailable);
                    catch e
                        display(e);
                    end

                end
            end
        end
        
        %setFreq_Single
        function setFreqSingle(obj,channelNr,freq)
            %Set the frequency for a single channel 
            %INPUT: freq: Between 1 and 500, frequencies > 100 only possible if just 1 channel is activated 
            %INPUT: channelNr: Between 1 and maximal channel count
            if obj.myoffline_modus == 0
                sof=[255,255];
                databytesCount=3;
                cmdNr=3;
                performComputung=1;

                %deleting prior data
                obj.serial_data = 0;

                %Input Controll
                if(freq<1 || freq>500)
                    performComputung=0;
                end
                if(channelNr<1 || channelNr>obj.channel_count)
                    performComputung=0;
                end

                %Command
                if(performComputung)
                    %Variable preparation
                    freqC=[0, 0];
                    if(freq>256)
                        freqC(1)=1;
                        freq=freq-256;
                        freqC(2)=freq;
                    else
                        freqC(2)=freq;
                    end
                    %Try to write to serial port

                    try
                        checksum=mod(sum([databytesCount,cmdNr,channelNr,freqC(1),freqC(2)]),256 );
                        cmd=[sof(1),sof(2),databytesCount,cmdNr,channelNr,freqC(1),freqC(2),checksum];
                        fwrite(obj.serial_device,cmd);
                        %                    Wait for writeback
                        timer_setFreq_Single = tic;
                        time_notchanged = 0;
                        bytes=0;
                        while (time_notchanged < 6 || bytes < 3)%obj.serial_device.BytesAvailable<6)
                            time_notchanged = round(toc(timer_setFreq_Single) * 1000);
                            if (bytes < obj.serial_device.BytesAvailable)
                                bytes = obj.serial_device.BytesAvailable;
                                time_notchanged = 0;
                                timer_setFreq_Single = tic;
                            end
                            if (time_notchanged > 3000)
                                msgID = 'FES:outputError';
                                msgtext = 'Couldnt write Frequency to FES Channel';
                                ME = MException(msgID,msgtext);
                                throw(ME);
                            end
                        end
                        while (obj.serial_device.BytesAvailable<3)
                            pause(0.01);
                        end
                        obj.serial_data = fread(obj.serial_device,obj.serial_device.BytesAvailable);
                    catch e
                        display(e);
                    end

                end
            end
        end
        
        %setPwidth_Global -> Please sort, e.g. here setPwidthMulti and single should
        %appear right after
        function setPwidthGlobal(obj,pulsewidth)
            %Set the pulsewidth for all MotionStim Channels. 
            %INPUT: pulswidth: Between 0 and to 500
            %           Below 10 the channel will not be activated
            if obj.myoffline_modus == 0
                sof=[255,255];
                databytesCount=2;
                cmdNr=4;
                performComputung=1;

                %deleting prior data
                obj.serial_data = 0;

                %Input Controll
                if(pulsewidth<0 || pulsewidth>500)
                    performComputung=0;
                end

                %Command
                if(performComputung)
                    %Variable preparation
                    pulseWithC=[0, 0];
                    if(pulsewidth>256)
                        pulseWithC(1)=1;
                        pulsewidth=pulsewidth-256;
                        pulseWithC(2)=pulsewidth;
                    else
                        pulseWithC(2)=pulsewidth;
                    end
                    %Try to write to serial port

                    try
                        checksum=mod(sum([databytesCount,cmdNr,pulseWithC(1),pulseWithC(2)]),256 );
                        cmd=[sof(1),sof(2),databytesCount,cmdNr,pulseWithC(1),pulseWithC(2),checksum];
                        fwrite(obj.serial_device,cmd);
                        %Wait for writeback
                        timer_setPwidth_Global = tic;
                        time_notchanged = 0;
                        bytes=0;
                        while (time_notchanged < 6 || bytes < 3)%obj.serial_device.BytesAvailable<6)
                            time_notchanged = round(toc(timer_setPwidth_Global) * 1000);
                            if (bytes < obj.serial_device.BytesAvailable)
                                bytes = obj.serial_device.BytesAvailable;
                                time_notchanged = 0;
                                timer_setPwidth_Global = tic;
                            end
                            if (time_notchanged > 3000)
                                msgID = 'FES:outputError';
                                msgtext = 'Couldnt write Amplitude and Pulsewidth to FES Channel';
                                ME = MException(msgID,msgtext);
                                throw(ME);
                            end
                        end
                        %                     while (obj.serial_device.BytesAvailable<3)
                        %                         pause(0.01);
                        %                     end
                        obj.serial_data = fread(obj.serial_device,obj.serial_device.BytesAvailable);
                    catch e
                        display(e);
                    end

                end
            end
        end
        
        
        %setPwidthMulti
        function setPwidth_Multi(obj,pulsewidth)
            %set the pulsewidth for the first X channel, where X is the number of values in the pulsewidth vector.
            %INPUT: pulsewidth: A vector of values between 0 and 500.
            %The pulsewidth has to be between 0 and 500
            %           Below 10 the channel will not be activated
            %SHORT DESCRIPTION: set the pulsewidth for the first X channel, 
            %where X is the number of values in the pulsewidth vector. 
            %E.g.: The vector [10 20 1] will add the
            %given pulsewidth settings to the channels 1 - 3 respectively
            if obj.myoffline_modus == 0

                sof=[255,255];
                databytesCount=length(pulsewidth);
                cmdNr=6;
                performComputung=1;

                %deleting prior data
                obj.serial_data = 0;

                %Input Controll

                for m = 1:length(pulsewidth)
                    if(pulsewidth(m)<0 || pulsewidth(m)>500)
                        performComputung=0;
                    end
                    pulsewidth(m)=floor(pulsewidth(m)*0.5);
                end

                %Command
                if(performComputung)
                    %Variable preparation
                    %Try to write to serial port

                    try
                        checksum=mod(sum([databytesCount,cmdNr,pulsewidth]),256 );
                        cmd=[sof(1),sof(2),databytesCount,cmdNr,pulsewidth,checksum];
                        fwrite(obj.serial_device,cmd);
                        %Wait for writeback
                        timer_setPwidth_Multi = tic;
                        time_notchanged = 0;
                        bytes=0;
                        while (time_notchanged < 6 || bytes < 3)%obj.serial_device.BytesAvailable<6)
                            time_notchanged = round(toc(timer_setPwidth_Multi) * 1000);
                            if (bytes < obj.serial_device.BytesAvailable)
                                bytes = obj.serial_device.BytesAvailable;
                                time_notchanged = 0;
                                timer_setPwidth_Multi = tic;
                            end
                            if (time_notchanged > 3000)
                                msgID = 'FES:outputError';
                                msgtext = 'Couldnt write Pulsewidth to FES Channels';
                                ME = MException(msgID,msgtext);
                                throw(ME);
                            end
                        end
                        %                     while (obj.serial_device.BytesAvailable<3)
                        %                         pause(0.01);
                        %                     end
                        obj.serial_data = fread(obj.serial_device,obj.serial_device.BytesAvailable);
                    catch e
                        display(e);
                    end

                end
            end
        end
              
        %setPwidth_Single
        function setPwidthSingle(obj,channelNr, pulsewidth)
            %set the pulsewidth for a specific channel. The channel number has to be between 1 and the maximum channel count. 
            %Pulsewidth has to be between 0 and 500
            %           Below 10 the channel will not be activated
            if obj.myoffline_modus == 0
                sof=[255,255];
                databytesCount=3;
                cmdNr=7;
                performComputung=1;

                %deleting prior data
                obj.serial_data = 0;

                %Input Controll
                if(pulsewidth<0 || pulsewidth>500)
                    performComputung=0;
                end
                if (channelNr<1 || channelNr > obj.channel_count)
                    performComputung=0;
                end

                %Command
                if(performComputung)
                    %Variable preparation
                    pulseWithC=[0, 0];
                    if(pulsewidth>256)
                        pulseWithC(1)=1;
                        pulsewidth=pulsewidth-256;
                        pulseWithC(2)=pulsewidth;
                    else
                        pulseWithC(2)=pulsewidth;
                    end
                    %Try to write to serial port

                    try
                        checksum=mod(sum([databytesCount,cmdNr,channelNr,pulseWithC(1),pulseWithC(2)]),256 );
                        cmd=[sof(1),sof(2),databytesCount,cmdNr,channelNr,pulseWithC(1),pulseWithC(2),checksum];
                        fwrite(obj.serial_device,cmd);
                        %Wait for writeback
                        timer_setPwidth_Single = tic;
                        time_notchanged = 0;
                        bytes=0;
                        while (time_notchanged < 6 || bytes < 3)%obj.serial_device.BytesAvailable<6)
                            time_notchanged = round(toc(timer_setPwidth_Single) * 1000);
                            if (bytes < obj.serial_device.BytesAvailable)
                                bytes = obj.serial_device.BytesAvailable;
                                time_notchanged = 0;
                                timer_setPwidth_Single = tic;
                            end
                            if (time_notchanged > 3000)
                                msgID = 'FES:outputError';
                                msgtext = 'Couldnt write Pulsewidth to FES Channel';
                                ME = MException(msgID,msgtext);
                                throw(ME);
                            end
                        end
                        %                     while (obj.serial_device.BytesAvailable<3)
                        %                         pause(0.01);
                        %                     end
                        obj.serial_data = fread(obj.serial_device,obj.serial_device.BytesAvailable);
                    catch e
                        display(e);
                    end

                end
            end
        end
        
        %Hier muss es einen R ckgabewert geben! z.B. string
        function readVersion(obj)
            %             Read the MotionStim version
            if obj.myoffline_modus == 0
                sof=[255,255];
                databytesCount=0;
                cmdNr=8;
                performComputung=1;

                %deleting prior data
                obj.serial_data = 0;

                %Input Controll

                %Command
                if(performComputung)
                    %Variable preparation
                    %Try to write to serial port

                    try
                        checksum=mod(sum([databytesCount,cmdNr]),256 );
                        cmd=[sof(1),sof(2),databytesCount,cmdNr,checksum];
                        fwrite(obj.serial_device,cmd);
                        %Wait for writeback
                        while (obj.serial_device.BytesAvailable<3)
                            pause(0.01);
                        end
                        obj.serial_data = fread(obj.serial_device,obj.serial_device.BytesAvailable);
                    catch e
                        display(e);
                    end

                end
            end
        end
        
        %displayText_TopScreen
        function displayTextTopScreen(obj,text)
            %             Display a given text on the motionstim
            if obj.myoffline_modus == 0
                sof=[255,255];
                %databytesCount=1;
                cmdNr=9;
                performComputung=1;

                %deleting prior data
                obj.serial_data = 0;

                %Input Controll

                %Command
                if(performComputung)
                    %Variable preparation
                    ascii_text=double(text);
                    databytesCount = length(ascii_text);
                    %Try to write to serial port

                    try
                        checksum=mod(sum([databytesCount,cmdNr,ascii_text]),256 );
                        cmd=[sof(1),sof(2),databytesCount,cmdNr,ascii_text,checksum];
                        fwrite(obj.serial_device,cmd);
                        %Wait for writeback
                        while (obj.serial_device.BytesAvailable<3)
                            pause(0.01);
                        end
                        obj.serial_data = fread(obj.serial_device,obj.serial_device.BytesAvailable);
                    catch e
                        display(e);
                    end

                end
            end
            
        end
        
        %displayText_AlmostTopScreen
        function displayTextAlmostTopScreen(obj,text)
            %             Display a given text on the motionstim
            if obj.myoffline_modus == 0
                sof=[255,255];
                cmdNr=10;
                performComputung=1;

                %deleting prior data
                obj.serial_data = 0;

                %Input Controll

                %Command
                if(performComputung)
                    %Variable preparation
                    ascii_text=double(text);
                    databytesCount = length(ascii_text);
                    %Try to write to serial port

                    try
                        checksum=mod(sum([databytesCount,cmdNr,ascii_text]),256 );
                        cmd=[sof(1),sof(2),databytesCount,cmdNr,ascii_text,checksum];
                        fwrite(obj.serial_device,cmd);
                        %Wait for writeback
                        while (obj.serial_device.BytesAvailable<3)
                            pause(0.01);
                        end
                        obj.serial_data = fread(obj.serial_device,obj.serial_device.BytesAvailable);
                    catch e
                        display(e);
                    end

                end
            end
        end
               
        function clearDisplay(obj)
            %             Remove the text currently displayed
            if obj.myoffline_modus == 0
                sof=[255,255];
                databytesCount=0;
                cmdNr=11;
                performComputung=1;

                %deleting prior data
                obj.serial_data = 0;

                %Input Controll

                %Command
                if(performComputung)
                    %Variable preparation
                    %Try to write to serial port

                    try
                        checksum=mod(sum([databytesCount,cmdNr]),256 );
                        cmd=[sof(1),sof(2),databytesCount,cmdNr,checksum];
                        fwrite(obj.serial_device,cmd);
                        %Wait for writeback
                        while (obj.serial_device.BytesAvailable<3)
                            pause(0.01);
                        end
                        obj.serial_data = fread(obj.serial_device,obj.serial_device.BytesAvailable);
                    catch e
                        display(e);
                    end

                end
            end
        end
                
        function beep(obj,duration,inversFreq)
            if obj.myoffline_modus == 0
                sof=[255,255];
                databytesCount=2;
                cmdNr=12;
                performComputung=1;

                %Input Controll
                if(duration<1 || duration>5000)
                    performComputung=0;
                end
                if(inversFreq<1||inversFreq>2000)
                    performComputung=0;
                end

    %             durationC=[0, 0];
    %             if(duration>256)
    %                 durationC(1)=1;
    %                 duration=duration-256;
    %                 durationC(2)=duration;
    %             else
    %                 durationC(2)=duration;
    %             end
    %             
    %             inversFreqC=[0, 0];
    %             if(inversFreq>256)
    %                 inversFreqC(1)=1;
    %                 inversFreq=inversFreq-256;
    %                 inversFreqC(2)=inversFreq;
    %             else
    %                 inversFreqC(2)=inversFreq;
    %             end


                %deleting prior data
                obj.serial_data = 0;


                %Command
                flushinput(obj.serial_device);
                if(performComputung)
                    try 
    %                     checksum=mod(sum([databytesCount,cmdNr,durationC(1),durationC(2),inversFreqC(1),inversFreqC(2)]),256 );
    %                     cmd=[sof(1),sof(2),databytesCount,cmdNr,durationC(1),durationC(2),inversFreqC(1),inversFreqC(2),checksum];
                        checksum=mod(sum([databytesCount,cmdNr,duration,inversFreq]),256 );
                        cmd=[sof(1),sof(2),databytesCount,cmdNr,duration,inversFreq,checksum];
                        fwrite(obj.serial_device,cmd);
    %                     flushoutput(obj.serial_device);
                        %Wait for writeback
                        timer_readAD_Single = tic;
                        time_notchanged = 0;
                        bytes=0;
                        while (time_notchanged < 6 || bytes < 3)%obj.serial_device.BytesAvailable<6)
                            time_notchanged = round(toc(timer_readAD_Single) * 1000);
                            if (bytes < obj.serial_device.BytesAvailable)
                                bytes = obj.serial_device.BytesAvailable;
                                time_notchanged = 0;
                                timer_readAD_Single = tic;
                            end
                            if (time_notchanged > 3000)
                                msgID = 'FES:inputError';
                                msgtext = 'No message from FES';
                                ME = MException(msgID,msgtext);
                                throw(ME);
                                %                             error_msg = 'No message from FES';
                                %                             error(error_msg);
                            end
                        end
    %                     while (obj.serial_device.BytesAvailable<3)
    %                         pause(0.01);
    %                     end
                         obj.serial_data = fread(obj.serial_device,obj.serial_device.BytesAvailable);
                    catch e
                        display(e);
                    end
                    flushoutput(obj.serial_device);
                end
            end
        end
          
        %prepPulseTrain_Single
        function prepPulseTrainSingle(obj,channelNr,mA,pulsewidth,pulseNr,delay)
            %Prepare a train of pulses for a specific channel. 
            %INPUT: Channel number: Between 1 and 8
            %INPUT: mA: Between 0 and 125
            %INPUT: pulsewidth: Between 0 and 500
            %INPUT: Pulse number: Between 1 and 16
            %INPUT: Delay: 0 and 32768 [ms]
            if obj.myoffline_modus == 0
                sof=[255,255];
                databytesCount=7;
                cmdNr=13;
                performComputung=1;

                %deleting prior data
                obj.serial_data = 0;

                %Input Controll
                if(channelNr<1 || channelNr>obj.channel_count)
                    performComputung=0;
                end
                if(mA<0 || mA>125)
                    performComputung=0;
                end
                if((mA-floor(mA))==0.5)
                    mA=mA+127;
                end
                if(pulsewidth<0 || pulsewidth>500)
                    performComputung=0;
                end
                if(pulseNr<1||pulseNr>16)
                    performComputung=0;
                end
                if(delay<0||delay>32768)
                    performComputung=0;
                end

                %Command
                if(performComputung)
                    %Variable preparation
                    pulseWithC=[0, 0];
                    if(pulsewidth>256)
                        pulseWithC(1)=1;
                        pulsewidth=pulsewidth-256;
                        pulseWithC(2)=pulsewidth;
                    else
                        pulseWithC(2)=pulsewidth;
                    end
                    delayC=[0, 0];
                    if(delay>256)
                        delayC(1)=1;
                        delay=delay-256;
                        delayC(2)=delay;
                    else
                        delayC(2)=delay;
                    end

                    %Try to write to serial port

                    try
                        checksum=mod(sum([databytesCount,cmdNr,channelNr,mA,pulseWithC(1),pulseWithC(2),pulseNr,delayC(1),delayC(2)]),256 );
                        cmd=[sof(1),sof(2),databytesCount,cmdNr,channelNr,mA,pulseWithC(1),pulseWithC(2),pulseNr,delayC(1),delayC(2),checksum];
                        fwrite(obj.serial_device,cmd);
                        %Wait for writeback
                        timer_prepPulseTrain_Single = tic;
                        time_notchanged = 0;
                        bytes=0;
                        while (time_notchanged < 6 || bytes < 3)%obj.serial_device.BytesAvailable<6)
                            time_notchanged = round(toc(timer_prepPulseTrain_Single) * 1000);
                            if (bytes < obj.serial_device.BytesAvailable)
                                bytes = obj.serial_device.BytesAvailable;
                                time_notchanged = 0;
                                timer_prepPulseTrain_Single = tic;
                            end
                            if (time_notchanged > 3000)
                                msgID = 'FES:outputError';
                                msgtext = 'Couldnt prepare Pulsetrain';
                                ME = MException(msgID,msgtext);
                                throw(ME);
                            end
                        end
                        %                     while (obj.serial_device.BytesAvailable<3)
                        %                         pause(0.01);
                        %                     end
                        obj.serial_data = fread(obj.serial_device,obj.serial_device.BytesAvailable);
                    catch e
                        display(e);
                    end

                end
            end
        end
        
        %execPulseTrain_Global
        function execPulseTrainGlobal(obj)
            %Execute all prepared pulsetrains. 
            %It is only possible to activate ALL prepared Pulse Trains, not
            %one specific
            if obj.myoffline_modus == 0
                sof=[255,255];
                databytesCount=0;
                cmdNr=14;
                performComputung=1;

                %deleting prior data
                obj.serial_data = 0;

                %Input Controll

                %Command
                if(performComputung)
                    %Variable preparation

                    %Try to write to serial port

                    try
                        checksum=mod(sum([databytesCount,cmdNr]),256 );
                        cmd=[sof(1),sof(2),databytesCount,cmdNr,checksum];
                        fwrite(obj.serial_device,cmd);
                        %Wait for writeback
                        timer_execPulseTrain_Global = tic;
                        time_notchanged = 0;
                        bytes=0;
                        while (time_notchanged < 6 || bytes < 3)%obj.serial_device.BytesAvailable<6)
                            time_notchanged = round(toc(timer_execPulseTrain_Global) * 1000);
                            if (bytes < obj.serial_device.BytesAvailable)
                                bytes = obj.serial_device.BytesAvailable;
                                time_notchanged = 0;
                                timer_execPulseTrain_Global = tic;
                            end
                            if (time_notchanged > 3000)
                                msgID = 'FES:outputError';
                                msgtext = 'Couldnt execute Pulsetrains';
                                ME = MException(msgID,msgtext);
                                throw(ME);
                            end
                        end
                        %                     while (obj.serial_device.BytesAvailable<3)
                        %                         pause(0.01);
                        %                     end
                        obj.serial_data = fread(obj.serial_device,obj.serial_device.BytesAvailable);
                    catch e
                        display(e);
                    end

                end
            end
            
        end
        
        %adValue = readADChannel_Single
        function adValue = readADChannelSingle(obj,channelNr)
            %Read the AD value of a specific channel. Channel number:4-8. The joystick channels are either 6 and 7 or 7 and 8.
            adValue = 0;
            if obj.myoffline_modus == 0
                sof=[255,255];
                databytesCount=1;
                cmdNr=15;
                performComputung=1;

                %deleting prior data
                obj.serial_data = 0;

                %Input Controll
                if(channelNr<4||channelNr>obj.channel_count)
                    performComputung=0;
                end

                %Command
                if(performComputung)
                    %Variable preparation

                    %Try to write to serial port

                    try
                        checksum=mod(sum([databytesCount,cmdNr,channelNr]),256 );
                        cmd=[sof(1),sof(2),databytesCount,cmdNr,channelNr,checksum];
                        fwrite(obj.serial_device,cmd);
                        %Wait for writeback
                        timer_readAD_Single = tic;
                        time_notchanged = 0;
                        bytes=0;
                        while (time_notchanged < 6 || bytes < 3)%obj.serial_device.BytesAvailable<6)
                            time_notchanged = round(toc(timer_readAD_Single) * 1000);
                            if (bytes < obj.serial_device.BytesAvailable)
                                bytes = obj.serial_device.BytesAvailable;
                                time_notchanged = 0;
                                timer_readAD_Single = tic;
                            end
                            if (time_notchanged > 3000)
                                msgID = 'FES:inputError';
                                msgtext = 'No message from FES';
                                ME = MException(msgID,msgtext);
                                throw(ME);
                                %                             error_msg = 'No message from FES';
                                %                             error(error_msg);
                            end
                        end
                        obj.serial_data = fread(obj.serial_device,obj.serial_device.BytesAvailable);
                        adValue = obj.serial_data(1) * 256 + obj.serial_data(2);
                    catch e
                        display(e);
                    end

                end

            end
        end
        
%         adValue = readADChannel_Multi
        function adValue = readADChannelMulti(obj,channelNr)
            if obj.myoffline_modus == 0
                %Read the AD value of a specific channel. Channel number:4-8. The joystick channels are either 6 and 7 or 7 and 8.
                sof=[255,255];
                databytesCount=length(channelNr);
                cmdNr=15;
                performComputung=1;

                %deleting prior data
                obj.serial_data = 0;

                %Input Controll
                NChannel=length(channelNr);
                for m = 1:NChannel
                    if(channelNr(m)<4||channelNr(m)>obj.channel_count)
                        performComputung=0;
                    end
                end

                %Command
                if(performComputung)
                    %Variable preparation
                    %Try to write to serial port
                    try
                        checksum=mod(sum([databytesCount,cmdNr,channelNr]),256 );
                        cmd=[sof(1),sof(2),databytesCount,cmdNr,channelNr,checksum];
                        fwrite(obj.serial_device,cmd);
                        %Wait for writeback
                        timer_readAD_Multi = tic;
                        time_notchanged = 0;
                        bytes=0;
                        while (time_notchanged < 6 || bytes < 3)%obj.serial_device.BytesAvailable<6)
                            time_notchanged = round(toc(timer_readAD_Multi) * 1000);
                            if (bytes < obj.serial_device.BytesAvailable)
                                bytes = obj.serial_device.BytesAvailable;
                                time_notchanged = 0;
                                timer_readAD_Multi = tic;
                            end
                            if (time_notchanged > 3000)
                                msgID = 'FES:inputError';
                                msgtext = 'No message from FES';
                                ME = MException(msgID,msgtext);
                                throw(ME);
                                %                             error_msg = 'No message from FES';
                                %                             error(error_msg);
                            end
                        end
                        %                     while (obj.serial_device.BytesAvailable<(4+length(channelNr)))
                        %                         pause(0.01);
                        %                     end
                        obj.serial_data = fread(obj.serial_device,obj.serial_device.BytesAvailable);
                        adValue =zeros(1,NChannel);
                        for i=1:NChannel
                        adValue(1,i) =obj.serial_data(i*2-1) * 256 + obj.serial_data(i*2);
                        end
                    catch e
                        display(e);
                    end

                end
            end
            
        end
        
%         adValue = testSkinContact_Single
        function adValue = testSkinContactSingle(obj,channelNr)
            if obj.myoffline_modus == 0
                %Test the Motionstim for skin contact
                sof=[255,255];
                databytesCount=1;
                cmdNr=16;
                performComputung=1;

                %deleting prior data
                obj.serial_data = 0;

                %Input Controll
                if(channelNr<1||channelNr>obj.channel_count)
                    performComputung=0;
                end

                %Command
                if(performComputung)
                    %Variable preparation

                    %Try to write to serial port

                    try
                        checksum=mod(sum([databytesCount,cmdNr,channelNr]),256 );
                        cmd=[sof(1),sof(2),databytesCount,cmdNr,channelNr,checksum];
                        fwrite(obj.serial_device,cmd);
                        %Wait for writeback
                        while (obj.serial_device.BytesAvailable<6)
                            pause(0.01);
                        end
                        obj.serial_data = fread(obj.serial_device,obj.serial_device.BytesAvailable);
                        adValue = obj.serial_data(1) * 256 + obj.serial_data(2);
                    catch e
                        display(e);
                    end

                end

            end
        end
            
    end
    
end