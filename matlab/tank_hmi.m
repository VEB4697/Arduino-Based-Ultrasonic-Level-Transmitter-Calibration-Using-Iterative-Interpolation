function tank_hmi
% TANK_HMI MATLAB dashboard for the discrete ultrasonic tank-level project.
% Edit COMPORT, thresholds, and the calibration table for the real installation.
% Run with: tank_hmi

COMPORT = "COM3";        % Change to the Uno's actual COM port.
BAUD = 115200;
CALFILE = fullfile(fileparts(mfilename('fullpath')), 'calibration_template.csv');
LOGFILE = fullfile(fileparts(mfilename('fullpath')), 'history.csv');
LOW_LEVEL_MM = 300;      % Pump ON below this level (only if valid echo).
HIGH_LEVEL_MM = 1600;    % Pump OFF above this level. Keep below tank capacity.
PLOT_WINDOW = 300;

cal = readtable(CALFILE);
required = {'RawGap_mm','ReferenceLevel_mm','ResidualCorrection_mm'};
if ~all(ismember(required, cal.Properties.VariableNames))
    error('Calibration file must contain RawGap_mm, ReferenceLevel_mm, ResidualCorrection_mm.');
end
cal = sortrows(cal, 'RawGap_mm');
if height(cal) < 2 || numel(unique(cal.RawGap_mm)) ~= height(cal)
    error('Calibration requires at least two unique raw gap values.');
end

fig = uifigure('Name','Ultrasonic Tank Level HMI','Position',[100 100 1050 650], ...
    'CloseRequestFcn',@closeApp);
grid = uigridlayout(fig,[4 4]);
grid.RowHeight = {42,95,'1x',36,42};
grid.ColumnWidth = {180,180,180,'1x'};

uilabel(grid,'Text','COM Port');
portField = uieditfield(grid,'text','Value',COMPORT);
connectButton = uibutton(grid,'Text','Connect','ButtonPushedFcn',@connectSerial);
statusLabel = uilabel(grid,'Text','Disconnected','FontWeight','bold');

levelLabel = uilabel(grid,'Text','— mm','FontSize',28,'FontWeight','bold');
levelLabel.Layout.Row = 2; levelLabel.Layout.Column = 1;
gapLabel = uilabel(grid,'Text','Air gap: — mm');
gapLabel.Layout.Row = 2; gapLabel.Layout.Column = 2;
echoLabel = uilabel(grid,'Text','Echo: — µs');
echoLabel.Layout.Row = 2; echoLabel.Layout.Column = 3;
pumpLabel = uilabel(grid,'Text','Pump: OFF','FontSize',18,'FontWeight','bold');
pumpLabel.Layout.Row = 2; pumpLabel.Layout.Column = 4;

ax = uiaxes(grid); ax.Layout.Row = 3; ax.Layout.Column = [1 4];
title(ax,'Water Level History'); xlabel(ax,'Time'); ylabel(ax,'Level (mm)'); grid(ax,'on');
logBox = uitextarea(grid,'Editable','off','Value',{'Example calibration loaded. Replace it with measured data before using level or pump control.'});
logBox.Layout.Row = 4; logBox.Layout.Column = [1 4];
pumpEnableCheck = uicheckbox(grid,'Text','Enable pump output (low-voltage bench tests only)', ...
    'Value',false,'ValueChangedFcn',@pumpEnableChanged);
pumpEnableCheck.Layout.Row = 5; pumpEnableCheck.Layout.Column = [1 3];
exportButton = uibutton(grid,'Text','Export History CSV','ButtonPushedFcn',@exportHistory);
exportButton.Layout.Row = 5; exportButton.Layout.Column = 4;

s = []; timerObj = []; times = datetime.empty; levels = []; rows = {};
lastPumpRequest = -1; requestedPump = false; closing = false;

    function connectSerial(~,~)
        if ~isempty(s) && isvalid(s)
            disconnectSerial(); return
        end
        try
            s = serialport(strtrim(portField.Value), BAUD, 'Timeout', 0.25);
            configureTerminator(s,'LF'); flush(s);
            configureCallback(s,'terminator',@serialLine);
            timerObj = timer('ExecutionMode','fixedSpacing','Period',0.5, ...
                'TimerFcn',@heartbeat,'ErrorFcn',@(~,~)safeOff());
            start(timerObj);
            connectButton.Text = 'Disconnect'; statusLabel.Text = 'Connected';
            appendLog("Opened " + string(portField.Value));
        catch ex
            safeOff(); statusLabel.Text = 'Connection failed'; appendLog(string(ex.message));
            if ~isempty(s), try delete(s); catch, end, s = []; end
        end
    end

    function disconnectSerial()
        safeOff();
        if ~isempty(timerObj) && isvalid(timerObj), stop(timerObj); delete(timerObj); end
        timerObj = [];
        if ~isempty(s), try configureCallback(s,'off'); delete(s); catch, end, end
        s = []; connectButton.Text = 'Connect'; statusLabel.Text = 'Disconnected';
    end

    function serialLine(src,~)
        try
            line = strtrim(readline(src)); fields = split(string(line),',');
            if numel(fields) ~= 7 || fields(1) ~= "D", return; end
            tms = str2double(fields(2)); echoUs = str2double(fields(3));
            rawGap = str2double(fields(4)); valid = str2double(fields(5)) == 1;
            relay = str2double(fields(6)) == 1;
            now = datetime('now'); level = NaN;
            if valid && isfinite(rawGap) && rawGap >= cal.RawGap_mm(1) && rawGap <= cal.RawGap_mm(end)
                level0 = interp1(cal.RawGap_mm, cal.ReferenceLevel_mm, rawGap, 'linear');
                residual = interp1(cal.RawGap_mm, cal.ResidualCorrection_mm, rawGap, 'linear');
                level = level0 + residual;
            end
            times(end+1) = now; levels(end+1) = level;
            if numel(levels) > PLOT_WINDOW, times = times(end-PLOT_WINDOW+1:end); levels = levels(end-PLOT_WINDOW+1:end); end
            plot(ax,times,levels,'b-'); drawnow limitrate;
            if isfinite(level)
                levelLabel.Text = sprintf('%.0f mm',level);
                gapLabel.Text = sprintf('Air gap: %.1f mm',rawGap);
                echoLabel.Text = sprintf('Echo: %.0f µs',echoUs);
                statusLabel.Text = 'Valid measurement';
                if level < LOW_LEVEL_MM, requestedPump = true; end
                if level > HIGH_LEVEL_MM, requestedPump = false; end
            else
                levelLabel.Text = 'INVALID'; statusLabel.Text = 'No echo / outside calibration';
                gapLabel.Text = sprintf('Air gap: %.1f mm',rawGap);
                echoLabel.Text = sprintf('Echo: %.0f µs',echoUs);
                requestedPump = false;
            end
            if ~pumpEnableCheck.Value, requestedPump = false; end
            pumpLabel.Text = sprintf('Pump: %s', ternary(relay,'ON','OFF'));
            if requestedPump ~= (lastPumpRequest == 1)
                sendPump(requestedPump); lastPumpRequest = double(requestedPump);
            end
            rows(end+1,:) = {now,tms,echoUs,rawGap,level,valid,relay};
        catch ex
            appendLog("Parse error: " + string(ex.message)); safeOff();
        end
    end

    function heartbeat(~,~)
        if isempty(s) || ~isvalid(s), return; end
        % Refresh watchdog only while a recent valid level is within table range.
        if pumpEnableCheck.Value && ~isempty(levels) && isfinite(levels(end)) && seconds(datetime('now')-times(end)) < 1.5
            sendPump(requestedPump);
        else
            requestedPump = false; sendPump(false);
        end
    end

    function sendPump(on)
        if isempty(s) || ~isvalid(s), return; end
        try writeline(s, sprintf('P,%d',double(on))); catch, safeOff(); end
    end

    function pumpEnableChanged(~,~)
        if ~pumpEnableCheck.Value
            safeOff();
        end
    end

    function safeOff()
        requestedPump = false;
        if ~isempty(s), try writeline(s,'P,0'); catch, end, end
        lastPumpRequest = 0;
    end

    function exportHistory(~,~)
        if isempty(rows), appendLog('No samples to export yet.'); return; end
        T = cell2table(rows,'VariableNames',{'Timestamp','ArduinoMillis','Echo_us','RawGap_mm','CalibratedLevel_mm','EchoValid','RelayOn'});
        writetable(T,LOGFILE); appendLog("Saved " + string(LOGFILE));
    end

    function appendLog(msg)
        v = logBox.Value; if ischar(v), v = {v}; end
        logBox.Value = [v; {char(string(datetime('now','Format','HH:mm:ss')) + "  " + string(msg))}];
    end

    function closeApp(~,~)
        closing = true; %#ok<NASGU>
        disconnectSerial(); delete(fig);
    end
end

function out = ternary(condition,a,b)
if condition, out = a; else, out = b; end
end
