classdef VOGDataExplorer < matlab.apps.AppBase
    % VOG DATA EXPLORER is a tool to visualize vog data with eye
    % and head movement recordings and mark different types of
    % events on them. Either a Time column or the samplerate has to
    % be provided
    % TEST FOR GIT
    %
    %   app = VOGDataExplorer.MarkData(data)
    %   app = VOGDataExplorer.MarkData(data, samplerate)
    %   app = VOGDataExplorer.MarkData(xdata, ydata, samplerate)
    %   app = VOGDataExplorer.MarkData(leftxdata, leftydata, rightxdata, rightydata, samplerate)
    %   app = VOGDataExplorer.MarkData( ...
    %               table(  datacolumn1, datacolumn2,(...), ...
    %                       'VariableNames', ...
    %                       {'nameColumn1', 'nameColumn2', (...));
    %
    %   All those options can be also used with a different method:
    %   app = VOGDataExplorer.Open(data)
    %   app = VOGDataExplorer.Open ...
    %
    %   data = VOGDataExplorer.MarkData(...) this will block until
    %           UI is closed
    %
    %   Inputs:
    %       - data: data table, should contain some of these columns
    %                   - Time: timestamps in seconds
    %                   - LeftX : left eye horizontal eye position
    %                   - LeftY : left eye vertical eye position
    %                   - LeftT : left eye torsional eye position
    %                   - RightX : right eye horizontal eye position
    %                   - RightY : right eye vertical eye position
    %                   - RightT : right eye torsional eye position
    %                   - LeftVelX : left eye horizontal eye velocity
    %                   - LeftVelY : left eye vertical eye velocity
    %                   - LeftVelT : left eye torsional eye velocity
    %                   - RightVelX : right eye horizontal eye velocity
    %                   - RightVelY : right eye vertical eye velocity
    %                   - RightVelT : right eye torsional eye velocity
    %
    %                   - HeadX : head horizontal (yaw) position
    %                   - HeadY : head vertica (pitch) position
    %                   - HeadT : head torsional (roll) position
    %                   - HeadVelX : head horizontal (yaw) velocity
    %                   - HeadVelY : head vertica (pitch) velocity
    %                   - HeadVelT : head torsional (roll) velocity
    %
    %                   - TargetX : target horizontal position (deg)
    %                   - TargetY : target horizontal position (deg)
    %                   - TargetT : target torsional position (deg);
    %                   -
    %                   - QuickPhase : boolean column indicating if
    %                       a sample belongs to a quick phase/
    %                       saccade
    %                   - SlowPhase : boolean column indicating if
    %                       a sample belongs to a slow phase
    %                   - HeadImpule : boolean column indicating if
    %                       a sample belongs to a head impulse
    %                   - BadData : boolean column indicating if
    %                       a sample belongs to a period of bad
    %                       data, i.e. due to blink
    %
    %       - samplerate: samplerate of the data (not necessary if
    %       there is time)
    %       - xdata: column vector with the horizontal eye data
    %       - ydata: column vector with the vertical eye data
    %
    %   Outputs:
    %       - app: VOGDataExplorer object
    %       - app.data: updated data table including boolean
    %               columns for marks
    
    
    % STATIC FUNCITONS TO START VOG DATA EXPLORER
    methods(Static)
        function data = MarkData(varargin)
            app = VOGDataExplorer(varargin{:});
            
            app.options.MarkingAllowed = 1;
            app.options.Advanced = 1;
            app.init();
            if (nargout>0)
                app.options.ShouldAskSave = 0;
            end
            
            data = VOGDataExplorer.BlockCommandLine(app); 
        end
        
        function Open(varargin)
            app = VOGDataExplorer(varargin{:});
            
            app.options.MarkingAllowed = 0;
            app.options.Advanced = 1;
            app.options.ShouldAskSave = 0;
            app.init();
        end
    end
    
    % public read only properties
    properties (SetAccess = private)
        
        data            % data table
        samplerate      = nan;
        
        mainfig         % main figure handle
        
        axesTable       = table(); % table with all information about each axis
        linesTable      = table(); % table with all information about each data line
        
        sources = table( ...
            {'LeftEye'  'RightEye'  'Head' 'Target' 'LeftEyeRaw'    'RightEyeRaw'}', ...
            {'Left'     'Right'     'Head' 'Target' 'LeftRaw'       'RightRaw'}', ...
            false(6,1), ...
            false(6,1), ...
            false(6,1), ...
            [false(4,1); true(2,1)], ...
            'VariableNames', ...
            {'Name','DataName', 'Available', 'Selected', 'LastSelected', 'AdvancedMode'});
        
        components = table( ...
            {'Horizontal' 'Vertical'  'Torsion' 'Pupil'     'Eyelid'}', ...
            {'X'          'Y'         'T'       'Pupil'         'L' }', ...
            false(5,1), ...
            false(5,1), ...
            false(5,1), ...
            'VariableNames', ...
            {'Name','DataName', 'Available', 'Selected', 'LastSelected'});
        
        derivatives = table( ...
            {'Position'   'Velocity'  'Acceleration'  'Jerk'    'SPV'}', ...
            {''           'Vel'       'Acc'           'Jerk'    'SPV'}', ...
            false(5,1), ...
            false(5,1), ...
            false(5,1), ...
            'VariableNames', ...
            {'Name','DataName', 'Available', 'Selected', 'LastSelected'});
        
        markers  = table( ...
            {'QuickPhase'	'SlowPhase'	 'HeadImpule'   'Peaks'     'BadData'   'LeftBadData'   'RightBadData'  'BadDataT'  'LeftBadDataT'  'RightBadDataT'}', ...
            {'Interval'     'Interval'	 'Interval'     'Event'     'Interval'  'Interval'      'Interval'      'Interval' 	'Interval'      'Interval'}', ...
            {'none'         'none'       'none'         'none'      'none'      'none'          'none'          'none'     	'none'          'none'}', ...
            {'o'            'o'          'o'            'v'         'o'         'o'             'o'             'o'       	'o'             'o'}', ...
            {4            	3            6           	6           2           2               2               2         	2               2}', ...
            {1              1          	 1              1           1           1               1               1           1               1}', ...
            {0              0          	 0              0           1           1               1               1           1               1}', ...
            'VariableNames', ...
            {'Name', 'Type', 'HighLightLineStyle', 'HighLightMarker', 'HighLightMarkerSize', 'HighLightLineWidth', 'AdvancedMode'});
        
        yScales         = logspace(-2,8,88)'; % logarithmic scale for y axis zoom increments
        marks           = table(); % table of marks (Name, Start, Stop)
        marksUndoStack  = table();
        
        helpText  = {...
            'Keyboard options:'
            ''
            'NOTE: for keys to work the data plot window must be active (click on it)'
            ''
            '  - Right arrow/space: scroll forward'
            '  - Left arrow: scroll backward'
            '  - Down arrow/s: zoom in y axis'
            '  - Up arrow/a: zoom out y axis'
            '  - z: zoom in x axis'
            '  - x: zoom out x axis'
            '  - d: delete mark'
            '  - escape: cancel mark'
            '  - mouse wheel:zoom in out y axis'}
        
        options = struct( ...
            'MarkingAllowed', true, ...
            'Advanced', true, ...
            'ShouldAskSave', true ...
            );
    end
    
    % private properties
    properties (Access = private)
        
        % figure handle
        UIFigure                   matlab.ui.Figure
        
        GroupbyButtonGroup         matlab.ui.container.ButtonGroup
        SourcesCheckBoxes
        ComponentsCheckBoxes
        DerivativesCheckBoxes
        HighlightCheckBoxes
        MarkersButtonGroup         matlab.ui.container.ButtonGroup
        TimescrollSliderLabel      matlab.ui.control.Label
        TimescrollSlider           matlab.ui.control.Slider
        TimespanSliderLabel        matlab.ui.control.Label
        TimespanSlider             matlab.ui.control.Slider
        HelpTextArea               matlab.ui.control.TextArea
        
        readyToUpdate           = false;
        cursorPosition          = nan;
        markingStartPosition    = nan;
        lastGroupBy             = '';
        selectedAxis            = []; % axes under the cursor
        currentSampleIdx        = [];
    end
    
    %
    % CONSTRUCTOR
    %
    methods (Access = private)
        function app = VOGDataExplorer(varargin)
            %TODO: better parameter  check
            
            if ( ischar(varargin{1}) && nargin >= 2 )
                app.data = table(varargin{2:2:end}, 'VariableNames', varargin(1:2:end));
            else
                
                switch(nargin)
                    case 0
                        [filename, pathname, ~] = uigetfile( ...
                            {'*.mat','MAT-files (*.mat)'}, ...
                            'Select a data file');
                        if ( ~isempty(filename) && ischar(filename))
                            app.data = load(fullfile(pathname,filename));
                            fields = fieldnames(app.data);
                            app.data = app.data.(fields{1});
                        else
                            clear app;
                            return;
                        end
                    case 1
                        app.data = varargin{1};
                    case 2
                        app.data = varargin{1};
                        app.data.Properties.UserData.sampleRate =  varargin{2};
                    case 3
                        app.data = table(varargin{1}, varargin{2}, 'VariableNames',{'LeftX','LeftY'});
                        app.data.Properties.UserData.sampleRate = varargin{3};
                    case 5
                        app.data = table(varargin{1}, varargin{2}, varargin{3}, varargin{4}, 'VariableNames',{'LeftX','LeftY', 'RightX', 'RightY'});
                        app.data.Properties.UserData.sampleRate = varargin{3};
                end
            end
            
            % Need to create the figure here to be able to add to the
            % CloseRequestFcn callback in the open modal window function
            app.UIFigure = uifigure;
        end
    end
    
    %
    % DESTRUCTOR
    %
    methods (Access = public)
        function delete(app)
            delete(app.UIFigure);
        end
    end
    
    % INIT APP METHODS
    methods (Access = private)
        
        function init( app )
            
            app.initData();
            
            % Create and configure components
            app.initUI();
            
            % Register the app with App Designer
            registerApp(app, app.UIFigure)
            
            app.Update();
            
            if nargout == 0
                clear app
            end
        end
        
        % Create UIFigure and components
        function initUI(app)
            
            posFigure = [100 100 350 560];
            
            if ( app.options.MarkingAllowed)
                nMarkers = height(app.markers)+1;
            else
                nMarkers = 0;
            end
            nHighlights = height(app.markers);
            
            % position elements
            margh = 10;
            margv = 10;
            paddh = 10;
            paddv = 10;
            hrow = 20;
            wcols = [180 120 120 160 250];
            xcols = cumsum(margh*ones(size(wcols)) + wcols)-wcols;
            hcols1 = [160 ([nMarkers+1 nHighlights+1])*hrow+paddh*2];
            hcols2 = ([height(app.sources) height(app.components) height(app.derivatives)]+1)*hrow+paddh*2;
            
            posFigure(4) = max(sum(hcols1), sum(hcols2)) + 200;
            posTabSetup = [1 1 posFigure(3)-2 posFigure(4)-24];
            
%             hcols3 = ([height(app.markers)+2 height(app.markers)+1])*hrow+paddh*2;
%             hcols4 = 300;
            ycols1 = posTabSetup(4) - cumsum(margv*ones(size(hcols1)) + hcols1);
            ycols2 = posTabSetup(4) - cumsum(margv*ones(size(hcols2)) + hcols2);
%             ycols3 = pos(4) - cumsum(margv*ones(size(hcols3)) + hcols3);
%             ycols4 = pos(4) - cumsum(margv*ones(size(hcols4)) + hcols4);


            % Configure UIFigure
            app.UIFigure.Position = posFigure;
            app.UIFigure.Name = 'UI Figure';
            app.UIFigure.Interruptible = false;
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @CloseRequest, true);
            
            % Create Menu
            menu = uimenu(app.UIFigure);
            menu.Text = 'File';
            
            menuItem = uimenu(menu);
            menuItem.MenuSelectedFcn = createCallbackFcn(app, @SaveData, false);
            menuItem.Text = 'Save data ...';
            
            % Create Menu2
            menu = uimenu(app.UIFigure);
            menu.Text = 'Navigate';
            menuItem = uimenu(menu);
            menuItem.MenuSelectedFcn = createCallbackFcn(app, @Forward, false);
            menuItem.Text = 'Forward (space, right arrow, page down)';
            menuItem = uimenu(menu);
            menuItem.MenuSelectedFcn = createCallbackFcn(app, @Backwards, false);
            menuItem.Text = 'Backward (left arrow, page up)';
            menuItem = uimenu(menu);
            menuItem.MenuSelectedFcn = createCallbackFcn(app, @ZoomInSpan, false);
            menuItem.Text = 'Zoom in time (z)';
            menuItem = uimenu(menu);
            menuItem.MenuSelectedFcn = createCallbackFcn(app, @ZoomOutSpan, false);
            menuItem.Text = 'Zoom out time (x)';
            menu = uimenu(app.UIFigure);
            menu.Text = 'Marking';
            menuItem = uimenu(menu);
            menuItem.MenuSelectedFcn = createCallbackFcn(app, @DeleteMark, false);
            menuItem.Text = 'Delete mark (d)';
            menuItem = uimenu(menu);
            menuItem.MenuSelectedFcn = createCallbackFcn(app, @ClearMark, false);
            menuItem.Text = 'Cancel mark start (escape)';
            menuItem = uimenu(menu);
            menuItem.MenuSelectedFcn = createCallbackFcn(app, @Undo, false);
            menuItem.Text = 'Undo mark (ctrl+z)';
            
            % Create TabGroup
            tabgroup = uitabgroup(app.UIFigure);
            tabgroup.Position = [1 1 posFigure(3) posFigure(4)];
            tabSetup = uitab(tabgroup);
            tabSetup.Title = 'Setup';
            tabHelp = uitab(tabgroup);
            tabHelp.Title = 'Help';
            
            
            % Create GroupbyButtonGroup
            app.GroupbyButtonGroup = uibuttongroup(tabSetup);
            app.GroupbyButtonGroup.SelectionChangedFcn = createCallbackFcn(app, @Update, true);
            app.GroupbyButtonGroup.Title = 'Group by (rows-columns)';
            app.GroupbyButtonGroup.Position = [xcols(1) ycols1(1) wcols(1) hcols1(1)];
            
            groupByOptions = {...
                'Sources', 'Components', ...
                'Sources-Derivatives', 'Components-Derivatives', 'Derivatives-Sources','Derivatives-Components'};
            for i=1:length(groupByOptions)
                % Create EyeButton
                radioButton = uiradiobutton(app.GroupbyButtonGroup);
                radioButton.Text = groupByOptions{i};
                radioButton.Position = [paddh (hcols1(1)-hrow*(i+1)-paddv) (wcols(1)-paddh*2) hrow];
                if ( i==length(groupByOptions) )
                    radioButton.Value = true;
                end
            end
            
            % Create SourcesButtonGroup
            SourcesButtonGroup = uibuttongroup(tabSetup);
            SourcesButtonGroup.SelectionChangedFcn = createCallbackFcn(app, @Update, true);
            SourcesButtonGroup.Title = 'Data sources';
            SourcesButtonGroup.Position = [xcols(2) ycols2(1) wcols(2) hcols2(1)];
            
            app.SourcesCheckBoxes = [];
            for i=1:height(app.sources)
                app.SourcesCheckBoxes.(app.sources.Name{i}) = uicheckbox(SourcesButtonGroup);
                app.SourcesCheckBoxes.(app.sources.Name{i}).Text = app.sources.Name{i};
                app.SourcesCheckBoxes.(app.sources.Name{i}).Position = [paddh (hcols2(1)-hrow*(i+1)-paddv) (wcols(2)-paddh*2) hrow];
                app.SourcesCheckBoxes.(app.sources.Name{i}).ValueChangedFcn = createCallbackFcn(app, @Update, true);
                if (~app.sources.Available(i))
                    app.SourcesCheckBoxes.(app.sources.Name{i}).Enable = 'off';
                end
            end
            
            % Create ComponentsButtonGroup
            componentsButtonGroup = uibuttongroup(tabSetup);
            componentsButtonGroup.SelectionChangedFcn = createCallbackFcn(app, @Update, true);
            componentsButtonGroup.Title = 'Components';
            componentsButtonGroup.Position = [xcols(2) ycols2(2) wcols(2) hcols2(2)];
            componentsButtonGroup.SelectionChangedFcn = createCallbackFcn(app, @Update, true);
            
            app.ComponentsCheckBoxes = [];
            for i=1:height(app.components)
                app.ComponentsCheckBoxes.(app.components.Name{i}) = uicheckbox(componentsButtonGroup);
                app.ComponentsCheckBoxes.(app.components.Name{i}).Text = app.components.Name{i};
                app.ComponentsCheckBoxes.(app.components.Name{i}).Position = [paddh (hcols2(2)-hrow*(i+1)-paddv) (wcols(2)-paddh*2) hrow];
                app.ComponentsCheckBoxes.(app.components.Name{i}).ValueChangedFcn = createCallbackFcn(app, @Update, true);
                if (~app.components.Available(i))
                    app.ComponentsCheckBoxes.(app.components.Name{i}).Enable = 'off';
                end
            end
            
            % Create DerivativesButtonGroup
            derivativesButtonGroup = uibuttongroup(tabSetup);
            derivativesButtonGroup.SelectionChangedFcn = createCallbackFcn(app, @Update, true);
            derivativesButtonGroup.Title = 'Derivatives';
            derivativesButtonGroup.Position = [xcols(2) ycols2(3) wcols(2) hcols2(3)];
            
            for i=1:height(app.derivatives)
                app.DerivativesCheckBoxes.(app.derivatives.Name{i}) = uicheckbox(derivativesButtonGroup);
                app.DerivativesCheckBoxes.(app.derivatives.Name{i}).Text = app.derivatives.Name{i};
                app.DerivativesCheckBoxes.(app.derivatives.Name{i}).Position = [paddh (hcols2(3)-hrow*(i+1)-paddv) (wcols(2)-paddh*2) hrow];
                app.DerivativesCheckBoxes.(app.derivatives.Name{i}).ValueChangedFcn = createCallbackFcn(app, @Update, true);
                if (~app.derivatives.Available(i))
                    app.DerivativesCheckBoxes.(app.derivatives.Name{i}).Enable = 'off';
                end
            end
            
            if ( app.options.MarkingAllowed )
                % Create MarkersButtonGroup
                app.MarkersButtonGroup = uibuttongroup(tabSetup);
                app.MarkersButtonGroup.SelectionChangedFcn = createCallbackFcn(app, @Update, true);
                app.MarkersButtonGroup.Title = 'Marking';
                app.MarkersButtonGroup.Position = [xcols(1) ycols1(2) wcols(1) hcols1(2)];
                
                radioButton = uiradiobutton(app.MarkersButtonGroup);
                radioButton.Text = 'None';
                radioButton.Position = [paddh (hcols1(2)-hrow*(1+1)-paddv) (wcols(1)-paddh*2) hrow];
                radioButton.Value = true;
                
                for i=1:height(app.markers)
                    radioButton = uiradiobutton(app.MarkersButtonGroup);
                    radioButton.Text = app.markers.Name{i};
                    radioButton.Position = [paddh (hcols1(2)-hrow*(i+2)-paddv) (wcols(1)-paddh*2) hrow];
                end
            end
            
            % Create HighLightsButtonGroup
            highLightsButtonGroup = uibuttongroup(tabSetup);
            highLightsButtonGroup.SelectionChangedFcn = createCallbackFcn(app, @Update, true);
            highLightsButtonGroup.Title = 'HighLights';
            highLightsButtonGroup.Position = [xcols(1) ycols1(3) wcols(1) hcols1(3)];
            
            for i=1:height(app.markers)
                app.HighlightCheckBoxes.(app.markers.Name{i}) = uicheckbox(highLightsButtonGroup);
                app.HighlightCheckBoxes.(app.markers.Name{i}).Text = app.markers.Name{i};
                app.HighlightCheckBoxes.(app.markers.Name{i}).Position = [paddh (hcols1(3)-hrow*(i+1)-paddv) (wcols(1)-paddh*2) hrow];
                app.HighlightCheckBoxes.(app.markers.Name{i}).Value = false;
                app.HighlightCheckBoxes.(app.markers.Name{i}).ValueChangedFcn = createCallbackFcn(app, @Update, true);
                if ( ~any(strcmp(app.data.Properties.VariableNames, app.markers.Name{i}) ) )
                    app.HighlightCheckBoxes.(app.markers.Name{i}).Enable = false;
                end
            end
            
            % Create TimescrollSliderLabel
            app.TimescrollSliderLabel = uilabel(tabSetup);
            app.TimescrollSliderLabel.HorizontalAlignment = 'right';
            app.TimescrollSliderLabel.Position = [10 80 90 30];
            app.TimescrollSliderLabel.Text = 'Time scroll (s)';
            
            % Create TimescrollSlider
            app.TimescrollSlider = uislider(tabSetup);
            app.TimescrollSlider.ValueChangedFcn = createCallbackFcn(app, @Update, true);
            app.TimescrollSlider.ValueChangingFcn = createCallbackFcn(app, @Update, true);
            app.TimescrollSlider.Position = [120 100 posTabSetup(3)-140 3];
            app.TimescrollSlider.Limits = [0 max(app.data.Time)];
            possibleTickSeparation = [1 2 5 10 20 50 100 200 500 1000 2000 5000];
            [~,i]=min(abs(possibleTickSeparation-max(app.data.Time)/10));
            ticks = 0:possibleTickSeparation(i):max(app.data.Time);
            app.TimescrollSlider.MajorTicks = ticks;
            app.TimescrollSlider.MajorTickLabels = cellstr(num2str(ticks'));
            
            % Create TimespanSliderLabel
            app.TimespanSliderLabel = uilabel(tabSetup);
            app.TimespanSliderLabel.HorizontalAlignment = 'right';
            app.TimespanSliderLabel.Position = [10 20 90 30];
            app.TimespanSliderLabel.Text = 'Time span (s)';
            
            % Create TimespanSlider
            app.TimespanSlider = uislider(tabSetup);
            app.TimespanSlider.ValueChangedFcn = createCallbackFcn(app, @Update, true);
            app.TimespanSlider.ValueChangingFcn = createCallbackFcn(app, @Update, true);
            app.TimespanSlider.Position = [120 40 posTabSetup(3)-140 3];
            app.TimespanSlider.Limits = log10([0.1 max(app.data.Time)]);
            app.TimespanSlider.Value = min(log10(max(app.data.Time)), log10(10));
            
            ticks = logspace(-1,round(log10(max(app.data.Time))),round(log10(max(app.data.Time)))+2);
            app.TimespanSlider.MajorTicks = log10(ticks);
            app.TimespanSlider.MajorTickLabels = cellstr(num2str(ticks'));
            
            
            % Create HelpTextArea
            app.HelpTextArea = uitextarea(tabHelp);
            app.HelpTextArea.Position = tabHelp.Position -[-10 -10 20 40] ;
            app.HelpTextArea.Value = app.helpText;
            app.HelpTextArea.Editable = false;
            
            
            app.readyToUpdate = true;
            app.Update();
        end
        
        function initData(app)
            
            if ( isempty(app.data) || ~istable(app.data) )
                error('++VOG DATA EXPLORER :: data must be a nonempty table');
            end
                        
            % check for timestamps and/or samplerate
            if ( ~any(strcmp(app.data.Properties.VariableNames,'Time')))
                if ( ~isfield( app.data.Properties.UserData, 'sampleRate') )
                    error('Data needs to have either a column named Time with timestamps in seconds or a field sampleRate in UserData');
                end
                app.data.Time = ((1:height(app.data))/app.data.Properties.UserData.sampleRate)';
            end
            
            if ( isfield( app.data.Properties.UserData, 'sampleRate') )
                app.samplerate = app.data.Properties.UserData.sampleRate;
            else
                app.samplerate = 1/nanmedian(diff(app.data.Time));
                app.data.Properties.UserData.sampleRate = app.samplerate;
            end
            
            % make sure time starts at zero TODO: think about this again
            app.data.Time = app.data.Time - app.data.Time(1);
            
            % check which signals are available
            for iSource = 1:height(app.sources)
                for iComp = 1:height(app.components)
                    positionAvailable = 0;
                    for iDeriv = 1:height(app.derivatives)
                        dataColumnName = [app.sources.DataName{iSource} app.derivatives.DataName{iDeriv} app.components.DataName{iComp}];
                        available = any(strcmp(app.data.Properties.VariableNames,dataColumnName)) && sum(~isnan(app.data.(dataColumnName)))>0;
                        
                        % check if position is available to later calculate
                        % the derivatives from it
                        if ( iDeriv == 1 && available)
                            positionAvailable = 1;
                        end
                        
                        % create derivatives if they are not available by
                        % differentiating
                        if ( iDeriv > 1 && ~available && positionAvailable)
                            positionColumnName = [app.sources.DataName{iSource} app.derivatives.DataName{iDeriv-1} app.components.DataName{iComp}];
                            app.data.(dataColumnName) = VOGDataExplorer.engbert_vecvel(app.data.(positionColumnName), app.samplerate, 2);
                            available = 1;
                        end
                        
                        % find which column in the data corresponds with
                        % this source/component/derivative to faster acces
                        % later on
                        columnNumber = find(strcmp(app.data.Properties.VariableNames,dataColumnName));
                        if ( isempty(columnNumber) )
                            columnNumber = nan;
                        end
                        
                        app.linesTable = vertcat(app.linesTable, ...
                            table(  string(dataColumnName), ...
                            columnNumber, ...
                            available, ...
                            categorical(string(app.sources.Name{iSource})), ...
                            categorical(string(app.components.Name{iComp})), ...
                            categorical(string(app.derivatives.Name{iDeriv})),...
                            iSource, ...
                            iComp, ...
                            iDeriv, ...
                            'VariableNames', {'DataColumnName', 'DataColumnNumber', 'Available', 'Source', 'Component', 'Derivative', 'SourceNumber', 'ComponentNumber', 'DerivativeNumber'}));
                        
                        % mark the sources components or derivatives as
                        % available. If at least one is available (OR)
                        app.sources.Available(iSource) = app.sources.Available(iSource) || available;
                        app.components.Available(iComp) = app.components.Available(iComp) || available;
                        app.derivatives.Available(iDeriv) = app.derivatives.Available(iDeriv) || available;
                    end
                end
            end
            
            % markerColumns in data
            for i=1:height(app.markers)
                if ( ~any(strcmp(app.data.Properties.VariableNames,app.markers.Name{i})))
                    app.data.(app.markers.Name{i}) = zeros(size(app.data.Time));
                end
            end
            
            % Init marks
            app.marks = table();
            for i=1:height(app.markers)
                if ( any(strcmp(app.data.Properties.VariableNames, app.markers.Name{i} ) ) )
                    starts = find(diff([0;app.data.(app.markers.Name{i})])>0);
                    stops = find(diff([app.data.(app.markers.Name{i});0])<0);
                    
                    app.marks = vertcat(app.marks, ...
                        table( ...
                        repmat(categorical(string(app.markers.Name{i})), numel(starts),1), ...
                        starts, ...
                        stops, ...
                        height(app.marks) + (1:numel(starts))', ...
                        'variablenames', {'Name' 'Start' 'Stop', 'ID'}));
                end
            end
            
            if ( isempty( app.marks) )
                app.marks.Properties.UserData.Counter = 0;
            else
                app.marks.Properties.UserData.Counter = max(app.marks.ID);
            end
        end
        
    end
    
    % UI UPDATE
    methods (Access = private)
        function Update(app, ~)
            
            % avoid update during initialization
            if ( ~app.readyToUpdate)
                return;
            end
            
            try
                somethingChanged = app.CheckValidUpdate();
                
                if ( somethingChanged || isempty( app.axesTable) )
                    if ( any(ishandle(app.mainfig)) )
                        delete(get(app.mainfig,'children'));
                    end
                end
                
                % Initialize the figure if necessary
                if ( ~any(ishandle(app.mainfig)) )
                    app.SetUpFigure();
                end
                
                % Initialize the axes if necessary
                if ( isempty(app.mainfig.Children))
                    app.SetUpAxes();
                    app.SetUpLines();
                    app.SetUpYScales();
                end
                
                % update data
                app.UpdateDataLines();
                
                app.UpdateYLim();
                
                app.UpdateCursor();
                
                % update legend
                app.UpdateLegend();
                
                % update ticklabels
%                 app.UpdateTickLabels(); This is a bit slow so I won't do
%                 it.
                
                % bring figure to focus
                figure(app.mainfig)
            catch ex
                ex.getReport()
            end
        end
        
        function somethingChanged = CheckValidUpdate(app)
            
            % make sure signals that are not available are not selected
            % check that at least one signal is selected for each category
            
            app.sources.LastSelected = app.sources.Selected;
            app.components.LastSelected = app.components.Selected;
            app.derivatives.LastSelected = app.derivatives.Selected;
            
            for i=1:height(app.sources)
                if (~app.sources.Available(i))
                    app.SourcesCheckBoxes.(app.sources.Name{i}).Value  = false;
                end
                
                app.sources.Selected(i) = app.SourcesCheckBoxes.(app.sources.Name{i}).Value;
            end
            
            for i=1:height(app.components)
                if (~app.components.Available(i))
                    app.ComponentsCheckBoxes.(app.components.Name{i}).Value  = false;
                end
                
                app.components.Selected(i) = app.ComponentsCheckBoxes.(app.components.Name{i}).Value;
            end
            
            for i=1:height(app.derivatives)
                if (~app.derivatives.Available(i))
                    app.DerivativesCheckBoxes.(app.derivatives.Name{i}).Value  = false;
                end
                
                app.derivatives.Selected(i) = app.DerivativesCheckBoxes.(app.derivatives.Name{i}).Value;
            end
            
            % select the first two signals that are available for each
            % group in the case where none was selected
            if ( ~any(app.sources.Selected) )
                for i=1:height(app.sources)
                    if (app.sources.Available(i))
                        app.SourcesCheckBoxes.(app.sources.Name{i}).Value  = true;
                        app.sources.Selected(i) = true;
                        if ( sum(app.sources.Selected) == 2 )
                            break;
                        end
                    end
                end
            end
            
            if ( ~any(app.components.Selected) )
                for i=1:height(app.components)
                    if (app.components.Available(i))
                        app.ComponentsCheckBoxes.(app.components.Name{i}).Value  = true;
                        app.components.Selected(i) = true;
                        if ( sum(app.components.Selected) == 1 )
                            break;
                        end
                    end
                end
            end
            
            if ( ~any(app.derivatives.Selected) )
                for i=1:height(app.derivatives)
                    if (app.derivatives.Available(i))
                        app.DerivativesCheckBoxes.(app.derivatives.Name{i}).Value  = true;
                        app.derivatives.Selected(i) = true;
                        if ( sum(app.derivatives.Selected) == 2 )
                            break;
                        end
                    end
                end
            end
            
            % make sure the highlight corresponding to the current marking
            % is checked on
            
            if ( app.options.MarkingAllowed && ~strcmp('None',app.MarkersButtonGroup.SelectedObject.Text))
                currentMarker = app.markers(strcmp(app.markers.Name, app.MarkersButtonGroup.SelectedObject.Text),:);
                app.HighlightCheckBoxes.(char(currentMarker.Name)).Value = true;
            end
            
            % Check if we need to reset the axis in a figure. This
            % will happen if the group by has changed or if the number
            % of rows or columns has changed
            somethingChanged = false;
            somethingChanged = somethingChanged | ~isequal(app.sources.Selected, app.sources.LastSelected);
            somethingChanged = somethingChanged | ~isequal(app.components.Selected, app.components.LastSelected);
            somethingChanged = somethingChanged | ~isequal(app.derivatives.Selected, app.derivatives.LastSelected);
            somethingChanged = somethingChanged | ~strcmp(app.GroupbyButtonGroup.SelectedObject.Text, app.lastGroupBy);
            app.lastGroupBy = app.GroupbyButtonGroup.SelectedObject.Text;
        end
        
        function SetUpFigure(app)
            app.mainfig                         = figure('color','w');
            app.mainfig.UserData.app            = app;
            app.mainfig.BusyAction              = 'cancel';
            app.mainfig.Interruptible           = false;
            app.mainfig.KeyPressFcn             = @(fig,ev)app.KeyPress(ev);
            app.mainfig.WindowButtonMotionFcn   = @(fig,ev)app.MouseMove(ev);
            app.mainfig.WindowButtonDownFcn     = @(fig,ev)app.ButtonDown(ev);
            app.mainfig.WindowScrollWheelFcn    = @(fig,ev)app.WindowscrollWheelFcn(ev);
            
            screensize = get( groot, 'Screensize' );
            posUI = app.UIFigure.OuterPosition;
            app.UIFigure.Position = [10, screensize(4)-posUI(4)-40, posUI(3), posUI(4)];
            app.mainfig.Position = [posUI(3)+20, 106, screensize(3)-posUI(3)-40, screensize(4)-200];
        end
        
        function SetUpAxes(app)
            
            textcolor = [0.3 0.3 0.3];
            axescolor = [0.3 0.3 0.3];%[1 1 1];
            
            % figure out how many columns and rows the figure should have
            groups = split(lower(app.GroupbyButtonGroup.SelectedObject.Text),'-');
            rowNames = app.(groups{1}).Name(app.(groups{1}).Selected);
            columnNames = {''};
            if ( numel(groups) >1)
                columnNames = app.(groups{2}).Name(app.(groups{2}).Selected);
            end
            
            % build table with all the axes and the necessary
            % information
            [h, pos, rowcol] = VOGDataExplorer.tight_subplot(numel(rowNames), numel(columnNames), 0.01, 0.05, 0.05);%, gap, marg_h, marg_w)
            
            set(h, ...
                'nextplot',         'add', ...
                'box',              'on', ...
                'XGrid',            'on', ...
                'YGrid',            'on', ...
                'xcolor',           axescolor, ...
                'ycolor',           axescolor, ...
                'GridColor',        'k');
            linkaxes(h,'x');
            
            % add cursor handles to each graph
            handleCursor = nan(numel(h),2);
            for i=1:numel(h)
                handleCursor(i,1) = line(h(i),nan,nan,'linestyle','none','Marker','o','color',[0 0.6000 0.3000], 'markersize',10, 'linewidth',2);
                handleCursor(i,2) = line(h(i),nan,nan,'linestyle','none','Marker','o','color',[0.8098 0.0392 0],  'markersize',10, 'linewidth',2);
                handleCursor(i,3) = line(h(i),1,1,'linestyle', '-', 'color',[0.5 0.5 0.5]);
                handleCursor(i,4) = line(h(i),1,1,'linestyle', '--','color',[0.5 0.5 0.5]);
            end
            
            app.axesTable = table(...
                h, pos, rowcol(:,1), rowcol(:,2), handleCursor(:,1), handleCursor(:,2), handleCursor(:,3), handleCursor(:,4), nan(size(h)), ones(size(h)), ...
                'VariableNames', {'Handle', 'Position', 'AxesRow','AxesColumn', 'HandleCursorMarkerBegin', 'HandleCursorMarkerEnd', 'HandleCursorBegin', 'HandleCursorEnd', 'BaseScale', 'ScaleFactor'});
            
            leftMostAxes    = app.axesTable(app.axesTable.AxesColumn == 1,:);
            rightMostAxes   = app.axesTable(app.axesTable.AxesColumn == max(app.axesTable.AxesColumn),:);
            bottomAxes      = app.axesTable(app.axesTable.AxesRow == max(app.axesTable.AxesRow),:);
            topAxes         = app.axesTable(app.axesTable.AxesRow == 1,:);
            
            % add labels to the bottom axes
            set(bottomAxes.Handle,      'XTickLabelMode', 'auto');
            set(leftMostAxes.Handle,    'YTickLabelMode','auto');
            set(rightMostAxes.Handle,   'YTickLabelMode','auto');
            % if there are more than one column move the y axis
            % label to the right for th right column
            if ( max(app.axesTable.AxesColumn) > 1 )
                set(rightMostAxes.Handle, 'YAxisLocation', 'right');
            end
            % add ylabels to the left most graphs
            for i=1:numel(leftMostAxes.Handle)
                ylabel(leftMostAxes.Handle(i), rowNames{i},'color',textcolor);
            end
            % add xlabels to the bottom graphs
            for i=1:numel(topAxes.Handle)
                title(topAxes.Handle(i), columnNames{i},'color',textcolor);
                xlabel(bottomAxes.Handle(i),'Time (s)','color',textcolor);
            end
        end
        
        function SetUpLines(app)
            
            % figure out which signals should be shown this must be
            % done for every update
            app.linesTable.Show = ...
                app.linesTable.Available ...
                & (app.sources.Selected(app.linesTable.SourceNumber) ...
                & app.components.Selected(app.linesTable.ComponentNumber) ...
                & app.derivatives.Selected(app.linesTable.DerivativeNumber));
            
            % this tells us in which row/column a given signal is
            % by taken into account the ones that are not selected
            sourceCounter = cumsum(app.sources.Selected);
            componentCounter = cumsum(app.components.Selected);
            derivativeCounter = cumsum(app.derivatives.Selected);
            
            % build signal table
            newLineHandles = table();
            for i=1:height(app.linesTable)
                iSource = app.linesTable.SourceNumber(i);
                iComp = app.linesTable.ComponentNumber(i);
                iDeriv = app.linesTable.DerivativeNumber(i);
                
                if ( app.linesTable.Show(i) )
                    switch(app.GroupbyButtonGroup.SelectedObject.Text)
                        case 'Sources'
                            row = sourceCounter(iSource);
                            column = 1;
                            legendText = [char(app.linesTable.Component(i)) ' ' char(app.linesTable.Derivative(i))];
                        case 'Components'
                            row = componentCounter(iComp);
                            column = 1;
                            legendText = [char(app.linesTable.Source(i)) ' ' char(app.linesTable.Derivative(i))];
                        case 'Sources-Derivatives'
                            row = sourceCounter(iSource);
                            column = derivativeCounter(iDeriv);
                            legendText = char(app.linesTable.Component(i));
                        case 'Components-Derivatives'
                            row = componentCounter(iComp);
                            column = derivativeCounter(iDeriv);
                            legendText = char(app.linesTable.Source(i));
                        case 'Derivatives-Sources'
                            row = derivativeCounter(iDeriv);
                            column = sourceCounter(iSource);
                            legendText = char(app.linesTable.Component(i));
                        case 'Derivatives-Components'
                            row = derivativeCounter(iDeriv);
                            column = componentCounter(iComp);
                            legendText = char(app.linesTable.Source(i));
                    end
                    
                    ax =  app.axesTable.Handle(app.axesTable.AxesRow == row & app.axesTable.AxesColumn == column);
                    newRow = table(nan, double(ax), row, column, string(legendText),  ...
                        'VariableNames', {'LineHandle', 'AxesHandle', 'AxesRow', 'AxesColumn', 'LegendText'});
                else
                    newRow = table(nan, nan, nan, nan, "",  ...
                        'VariableNames', {'LineHandle', 'AxesHandle', 'AxesRow', 'AxesColumn', 'LegendText'});
                end
                newLineHandles = vertcat(newLineHandles, newRow);
            end
            
            % add handles for highlights and markers
            newLineHandles = horzcat(newLineHandles, ...
                array2table(nan(height(app.linesTable), height(app.markers)), ...
                'VariableNames', strcat('Handle_HighLight_', app.markers.Name)), ...
                array2table(nan(height(app.linesTable), 2), ...
                'VariableNames', {'Handle_Marker_Begining','Handle_Marker_End' }));
            
            % upate the table with the new handles
            app.linesTable(:,newLineHandles.Properties.VariableNames) = newLineHandles;
            
            % check if lines need to be deleted or added
            for iLine=1:height(app.linesTable)
                
                if ( ~app.linesTable.Show(iLine) )
                    continue;
                end
                
                
                currentAxis     = handle(app.linesTable.AxesHandle(iLine));
                nline           = sum(app.linesTable{1:iLine,'AxesHandle'} == currentAxis & app.linesTable{1:iLine,'Show'});
                colors          = get(currentAxis,'ColorOrder');
                currentColor    = colors(mod(nline(1)-1,size(colors,1))+1,:);
                
                colorsH = colors([5, 3, 4, 2, 7],:);
                % init line handles with empty lines, later
                % xdata and ydata will be updated accordingly
                
                for i=1:height(app.markers)
                    % the color of the highlight is a mix of the color
                    % of the line a common color for the same highlight
                    % across axes and lines
                    currentColorH = colorsH(mod(i-1,size(colorsH,1))+1,:);
                    currentColorH = 1-(1-currentColorH).^(45/50).*(1-currentColor).^(5/50);
                    app.linesTable{iLine, ['Handle_HighLight_' app.markers.Name{i}]} = line(currentAxis, nan,nan, ...
                        'linestyle', app.markers.HighLightLineStyle{i}, ...
                        'Marker', app.markers.HighLightMarker{i}, ...
                        'markersize', app.markers.HighLightMarkerSize{i}, ...
                        'linewidth', app.markers.HighLightLineWidth{i}, ...
                        'color', currentColorH);
                end
                
                app.linesTable{iLine, 'Handle_Marker_Begining'} = line(currentAxis, nan,nan,'color',[0 0.6000 0.3000],'linewidth',1);
                app.linesTable{iLine, 'Handle_Marker_End'}      = line(currentAxis, nan,nan,'color',[0.8098 0.0392 0],'linewidth',1);
                app.linesTable.LineHandle(iLine) = line(currentAxis, [1 1],[1 1],'color',currentColor);
            end
        end
        
        function SetUpYScales(app)
            
            function scale = CalculateBaseScale(lineSelection)
                data1 = app.data{:,app.linesTable.DataColumnNumber(lineSelection & app.linesTable.Show)};
                xl = prctile(data1(:),[0.01 99.99]);
                scale = app.yScales(find(app.yScales > abs(diff(xl)),1,'first'));
            end
            
            % initialize scales
            if ( any(isnan(app.axesTable.BaseScale)))
                h = reshape(app.axesTable.Handle,max(app.axesTable.AxesColumn), max(app.axesTable.AxesRow))';
                switch(app.GroupbyButtonGroup.SelectedObject.Text)
                    case {'Sources' 'Components'}
                        for i=1:numel(h)
                            lineSelection = app.linesTable.AxesHandle==h(i);
                            axesSelection = app.axesTable.Handle==h(i);
                            app.axesTable.BaseScale(axesSelection) = CalculateBaseScale(lineSelection);
                        end
                    case {'Components-Derivatives' 'Sources-Derivatives'}
                        for i=1:size(h,2)
                            lineSelection = app.linesTable.AxesColumn==i;
                            axesSelection = app.axesTable.AxesColumn==i;
                            app.axesTable.BaseScale(axesSelection) = CalculateBaseScale(lineSelection);
                        end
                    case {'Derivatives-Sources' 'Derivatives-Components'}
                        for i=1:size(h,1)
                            lineSelection = app.linesTable.AxesRow==i;
                            axesSelection = app.axesTable.AxesRow==i;
                            app.axesTable.BaseScale(axesSelection) = CalculateBaseScale(lineSelection);
                        end
                end
            end
        end
        
        function UpdateYLim(app)
            % update ylim
            for i=1:height(app.axesTable)
                if ( ~isnan(app.axesTable.BaseScale(i)))
                    currentScale = app.yScales(find(app.yScales==app.axesTable.BaseScale(i),1,'first') + app.axesTable.ScaleFactor(i));
                    data1 = app.data{app.currentSampleIdx,app.linesTable.DataColumnNumber(app.linesTable.AxesHandle==app.axesTable.Handle(i) & app.linesTable.Show)};
                    currentOffset = nanmean(data1(:));
                    if ( isnan(currentOffset) )
                        currentOffset = mean(get(app.axesTable.Handle(i),'ylim'));
                    end
                    
                    set(app.axesTable.Handle(i), 'YLimMode','manual', 'ylim', currentOffset + [-0.5 0.5]*currentScale);
                end
            end
        end
        
        function UpdateDataLines(app)
            % Figure out the portion of time that needs to be ploted
            % TODO: how to deal with discontinuities in Time?
            spanSeconds = 10.^app.TimespanSlider.Value;
            spanSamples = spanSeconds*app.samplerate;
            scrollSeconds = app.TimescrollSlider.Value;
            [~,scrollSample] = min(abs(app.data.Time - scrollSeconds));
            
            Xlim = app.TimescrollSlider.Value + [0 spanSeconds];
            
            idx = round(scrollSample + ( 1:spanSamples));
            idx(idx<1 | idx>height(app.data)) = [];
            app.currentSampleIdx = idx;
            
            % decimate the number of samples on display for better
            % performance
            pos = get(groot,'screensize');
            decim = max(1, round(size(idx,2)/pos(3)/4));
            idx = idx(1:decim:end);
            
            for iLine=1:height(app.linesTable)
                if ( ~app.linesTable.Show(iLine))
                    continue;
                end
                lineRow = table2struct(app.linesTable(iLine,:));
                
                ydata = app.data{idx, lineRow.DataColumnNumber};
                time = app.data.Time(idx);
                
                % update data
                set(handle(lineRow.LineHandle), 'xdata', time, 'ydata', ydata, 'zdata', ones(size(ydata)));
                
                % update highlights
                for i=1:height(app.markers)
                    highlight = nan(size(idx'));
                    if (app.HighlightCheckBoxes.(app.markers.Name{i}).Value )
                        highlight = ydata;
                        highlight(~app.data{idx,app.markers.Name{i}}) = nan;
                    end
                    set(handle(lineRow.(['Handle_HighLight_' app.markers.Name{i}])), 'xdata', time, 'ydata', highlight, 'zdata', ones(size(highlight)));
                end
                
                yl = get(lineRow.AxesHandle, 'ylim');
                markerSize = abs(diff(yl))*0.03;
                
                % update markers
                if (app.options.MarkingAllowed && ~strcmp('None', app.MarkersButtonGroup.SelectedObject.Text) && ~isempty( app.marks))
                    markerStarts = app.marks.Start(app.marks.Name == app.MarkersButtonGroup.SelectedObject.Text);
                    markerStops = app.marks.Stop(app.marks.Name == app.MarkersButtonGroup.SelectedObject.Text);
                    
                    xstarts = app.data.Time(markerStarts);
                    ystarts = app.data{markerStarts, lineRow.DataColumnNumber};
                    x1 = nan(numel(xstarts)*3,1);
                    y1 = nan(numel(ystarts)*3,1);
                    x1([1:3:end 2:3:end 3:3:end]) = [xstarts xstarts xstarts];
                    y1([1:3:end 2:3:end]) = [ystarts-markerSize ystarts+markerSize];
                    
                    xstops = app.data.Time(markerStops);
                    ystops = app.data{markerStops, lineRow.DataColumnNumber};
                    x2 = nan(numel(ystops)*3,1);
                    y2 = nan(numel(ystops)*3,1);
                    x2([1:3:end 2:3:end 3:3:end]) = [xstops xstops xstops];
                    y2([1:3:end 2:3:end]) = [ystops-markerSize ystops+markerSize];
                    
                    % TODO: deal with nans in the y
                    set(handle(lineRow.Handle_Marker_Begining), 'xdata', x1, 'ydata', y1,'zdata', ones(size(x1)));
                    set(handle(lineRow.Handle_Marker_End),      'xdata', x2, 'ydata', y2, 'zdata', ones(size(x2)));
                else
                    set(handle(lineRow.Handle_Marker_Begining), 'xdata', nan, 'ydata', nan, 'zdata', nan);
                    set(handle(lineRow.Handle_Marker_End), 'xdata', nan, 'ydata', nan, 'zdata', nan);
                end
            end
            
            set(app.axesTable.Handle, 'xlim', Xlim);
        end
        
        function UpdateLegend(app)
            
            axisForLegend = app.axesTable.Handle(end);
            
            highLights = {};
            for i=1:height(app.markers)
                if ( app.HighlightCheckBoxes.(app.markers.Name{i}).Value )
                    highLights{end+1} = strcat('Handle_HighLight_', app.markers.Name{i});
                end
            end
            
            visibleLines = app.linesTable(app.linesTable.Show & app.linesTable.AxesHandle==axisForLegend,:);
            linesForLegend = visibleLines(:,{'LineHandle', 'LegendText'});
            for j=1:height(visibleLines)
                for i=1:height(app.markers)
                    if ( app.HighlightCheckBoxes.(app.markers.Name{i}).Value )
                        linesForLegend = vertcat(linesForLegend, ...
                            table( visibleLines{j, ['Handle_HighLight_' app.markers.Name{i}]}, string([visibleLines.LegendText{j} ' ' app.markers.Name{i}]), ...
                            'VariableNames', {'LineHandle', 'LegendText'}));
                    end
                end
                if ( j==height(visibleLines) && app.options.MarkingAllowed && ~strcmp(app.MarkersButtonGroup.SelectedObject.Text,'None'))
                    markerName = app.MarkersButtonGroup.SelectedObject.Text;
                    linesForLegend = vertcat(linesForLegend, ...
                        table( visibleLines.Handle_Marker_Begining(j), string([markerName ' begin']), ...
                        'VariableNames', {'LineHandle', 'LegendText'}));
                    linesForLegend = vertcat(linesForLegend, ...
                        table( visibleLines.Handle_Marker_End(j), string([markerName ' end']), ...
                        'VariableNames', {'LineHandle', 'LegendText'}));
                end
            end
            
            if (~isequal(get(get(app.axesTable.Handle(end),'legend'),'string'),cellstr(linesForLegend.LegendText') ))
                legend(axisForLegend,linesForLegend.LineHandle,cellstr(linesForLegend.LegendText), 'box', 'off');
            end
        end
        
        function UpdateTickLabels(app)
            
            textcolor = [0.3 0.3 0.3];
            
            h = app.axesTable.Handle;
            % prepend a color for each tick label
            for j=1:numel(h)
                if ( ~isempty(get(h(j),'XTickLabel')))
                    ticks = get(h(j),'XTick');
                    ticklabels_new = cell(size(ticks));
                    for i = 1:length(ticks)
                        ticklabels_new{i} = sprintf('\\color[rgb]{%f,%f,%f}%s', textcolor, num2str(ticks(i)));
                    end
                    set(h(j), 'XTickLabel', ticklabels_new);
                end
                if ( ~isempty(get(h(j),'YTickLabel')))
                    ticks = get(h(j),'YTick');
                    ticklabels_new = cell(size(ticks));
                    for i = 1:length(ticks)
                        ticklabels_new{i} = sprintf('\\color[rgb]{%f,%f,%f}%s', textcolor, num2str(ticks(i)));
                    end
                    set(h(j), 'YTickLabel', ticklabels_new);
                end
                
            end
        end
        
        function UpdateCursor(app)
            
            if ( ~app.readyToUpdate || isempty(app.axesTable))
                return;
            end
            
            % Get the current point of the mouse over the Axes,
            % defined as the actual(X,Y) value
            as = app.axesTable.Handle;
            for ax=as'
                currPtValue= get(ax,'CurrentPoint');
                % Use the Axes "xlim" and "ylim" properties in order to determine the X- and Y-
                % ranges within the Axes (i.e. maximum and minimum values in each dimension)
                xlim = get(ax,'xlim');
                ylim = get(ax,'ylim');
                % Define the boundaries as the max and min X- and Y- values
                % displayed within the Axes
                outOfBoundsX = (xlim(1) <= currPtValue(1,1) && xlim(2) >= currPtValue(1,1));
                outOfBoundsY = (ylim(1) <= currPtValue(1,2) && ylim(2) >= currPtValue(1,2));
                if outOfBoundsX && outOfBoundsY
                    position = currPtValue(1,1);
                    selectedAx = ax;
                    break;
                end
            end
            
            if ( exist( 'selectedAx', 'var' ) )
                app.selectedAxis = selectedAx;
            else
                app.selectedAxis = [];
            end
            
            if ( exist( 'position', 'var' ) )
                if ( isnan(position) )
                    app.cursorPosition = nan;
                end
                
                [~,i] = min(abs(app.data.Time-position));
                app.cursorPosition = i;
            end
            
            if ( ~app.options.MarkingAllowed )
                return;
            end
            
            for iAx = 1:height(app.axesTable)
                currentAxis = app.axesTable.Handle(iAx);
                
                set(app.axesTable.HandleCursorBegin(iAx),       'xdata', nan(2,1),  'ydata', nan(2,1));
                set(app.axesTable.HandleCursorEnd(iAx),         'xdata', nan(2,1),  'ydata', nan(2,1));
                set(app.axesTable.HandleCursorMarkerBegin(iAx), 'xdata', nan,       'ydata', nan);
                set(app.axesTable.HandleCursorMarkerEnd(iAx),   'xdata', nan,       'ydata', nan);
                
                if ( ~isnan(app.cursorPosition) && ~strcmp(app.MarkersButtonGroup.SelectedObject.Text,'None') )
                    yl = get(currentAxis, 'ylim');
                    datafields = app.linesTable{app.linesTable.AxesHandle==currentAxis & app.linesTable.Show,'DataColumnNumber'};
                    ydata = app.data{app.cursorPosition,datafields};
                    
                    t = app.data.Time(app.cursorPosition);
                    
                    if ( isnan(app.markingStartPosition) ) % marking begining
                        set(app.axesTable.HandleCursorBegin(iAx), 'xdata', t*[1 1], 'ydata', yl)
                        % cannot mark in between starts and stops
                        if ( app.IsValidMark() )
                            set(app.axesTable.HandleCursorMarkerBegin(iAx), 'xdata', repmat(t, size(ydata)), 'ydata', ydata);
                        end
                    else
                        ydata2 = app.data{app.markingStartPosition,datafields};
                        t2 = app.data.Time(app.markingStartPosition);
                        set(app.axesTable.HandleCursorBegin(iAx), 'xdata', t2*[1 1], 'ydata', yl)
                        set(app.axesTable.HandleCursorMarkerBegin(iAx), 'xdata', repmat(t2, size(ydata2)), 'ydata', ydata2);
                        
                        set(app.axesTable.HandleCursorEnd(iAx), 'xdata', t*[1 1], 'ydata', yl)
                        if ( app.IsValidMark() )
                            set(app.axesTable.HandleCursorMarkerEnd(iAx), 'xdata', repmat(t, size(ydata)), 'ydata', ydata);
                        end
                    end
                end
            end
        end
    end
    
    % CONTROLLER METHODS
    methods (Access = private)
        
        function Forward(app, windowFraction)
            if ( ~exist('windowFraction','var') )
                windowFraction = 1/10;
            end
            span = 10.^app.TimespanSlider.Value;
            app.Scroll(app.TimescrollSlider.Value + span*windowFraction);
        end
        
        function Backwards(app, windowFraction)
            if ( ~exist('windowFraction','var') )
                windowFraction = 1/10;
            end
            span = 10.^app.TimespanSlider.Value;
            app.Scroll(app.TimescrollSlider.Value - span*windowFraction);
        end 
        
        function Scroll(app, newtime)
            newtime = min(max(app.data.Time), newtime);
            newtime = max(0, newtime);
            app.TimescrollSlider.Value = newtime;
            app.Update();
        end
        
        function Zoom(app, factor)
            oldTimeSpanSeconds = (10.^(app.TimespanSlider.Value));
            timeSpanSeconds = oldTimeSpanSeconds*factor;
            newTimeSpan = log10(timeSpanSeconds);
            if ( newTimeSpan < app.TimespanSlider.Limits(1) || newTimeSpan > app.TimespanSlider.Limits(2) )
                return;
            end
            
            app.TimespanSlider.Value = newTimeSpan;
            if ( ~isnan(app.cursorPosition))
                % keep the cursor stable on screen
                time = app.data.Time(app.cursorPosition);
                newTime = time - timeSpanSeconds*((time-app.TimescrollSlider.Value)/oldTimeSpanSeconds);
                newTime = min(app.data.Time(end), newTime);
                newTime = max(0, newTime);
                app.TimescrollSlider.Value = newTime;
            end
            
            app.Update();
        end
        
        function ZoomInSpan(app)
            app.Zoom(1/1.2);
        end
        
        function ZoomOutSpan(app)
            app.Zoom(1.2);
        end
        
        function ZoomY(app, zoom)
            % zoom in or out
            if ( (zoom ~= 0 ))
                if ( ~isempty(app.selectedAxis) )
                    switch(app.GroupbyButtonGroup.SelectedObject.Text)
                        case {'Sources' 'Components'}
                            axesSelection = app.axesTable.Handle==app.selectedAxis;
                        case {'Components-Derivatives' 'Sources-Derivatives'}
                            axesSelection = app.axesTable.AxesColumn == app.axesTable.AxesColumn(app.axesTable.Handle==app.selectedAxis);
                        case {'Derivatives-Sources' 'Derivatives-Components'}
                            axesSelection = app.axesTable.AxesRow == app.axesTable.AxesRow(app.axesTable.Handle==app.selectedAxis);
                    end
                else
                    % if not selecting an axis just zoomin all
                    axesSelection = app.axesTable.Handle ~= 0;
                end
                app.axesTable.ScaleFactor(axesSelection) = app.axesTable.ScaleFactor(axesSelection)+zoom;
            end
            
            app.Update();
        end
        
        function ZoomInY(app)
            app.ZoomY(1);
        end
        
        function ZoomOutY(app)
            app.ZoomY(-1);
        end
        
        function valid = IsValidMark(app)
            
            markerYesNo = zeros(size(app.data.Time));
            if(~strcmp(app.MarkersButtonGroup.SelectedObject.Text,'None'))
                markerYesNo = app.data.(app.MarkersButtonGroup.SelectedObject.Text);
            end
            
            if ( ~isnan(app.cursorPosition) )
                if ( isnan(app.markingStartPosition) )
                    valid = ~markerYesNo(app.cursorPosition);
                else
                    valid = (app.cursorPosition > app.markingStartPosition) && (~any(markerYesNo(app.markingStartPosition:app.cursorPosition)));
                end
            else
                valid = false;
            end
        end
        
        function Mark(app)
            if ( isempty( app.selectedAxis) || ~app.IsValidMark() || strcmp(app.MarkersButtonGroup.SelectedObject.Text,'None'))
                return
            end
            
            newMark = [];
            currentMarker = app.markers(strcmp(app.markers.Name, app.MarkersButtonGroup.SelectedObject.Text),:);
            markerName = currentMarker.Name;
            
            if ( isnan(app.markingStartPosition) && ~isnan(app.cursorPosition) )
                if ( strcmp(currentMarker.Type,'Interval') )
                    app.markingStartPosition = app.cursorPosition;
                elseif ( strcmp(currentMarker.Type,'Event') )
                    newMark = cell2table({categorical(string(markerName)),app.cursorPosition,app.cursorPosition},'variablenames',{'Name' 'Start' 'Stop'});
                end
            else
                % markers
                newMark = cell2table({categorical(string(markerName)),app.markingStartPosition,app.cursorPosition},'variablenames',{'Name' 'Start' 'Stop'});
                app.markingStartPosition = nan;
            end
            
            if ~isempty(newMark)
                app.marks.Properties.UserData.Counter = app.marks.Properties.UserData.Counter + 1;
                newMark.ID = app.marks.Properties.UserData.Counter;
                
                % add mark
                app.marks = vertcat(app.marks,newMark);
                
                app.UpdateDataMark(markerName);
                
                % add new marks to the undo stack
                newMark.Action = categorical("Add");
                app.marksUndoStack = vertcat(app.marksUndoStack, newMark);
            end
            
            app.Update();
        end
        
        function ClearMark(app)
            app.markingStartPosition = nan;
            app.Update();
            app.MouseMove();
        end
        
        function DeleteMark(app)
            
            if(strcmp(app.MarkersButtonGroup.SelectedObject.Text,'None'))
                return
            end
            
            if (~isnan(app.cursorPosition) )
                markName = app.MarkersButtonGroup.SelectedObject.Text;
                
                idx = app.marks.Name == markName & app.marks.Start<app.cursorPosition & app.marks.Stop>app.cursorPosition;
                if ( isempty(idx))
                    return
                end
                deletedMarks = app.marks(idx,:);
                app.marks(idx,:) = [];
                
                app.UpdateDataMark(markName);
                
                % add deleted marks to the undo stack
                if ( ~isempty(deletedMarks) )
                    for i=1:height(deletedMarks)
                        mark = deletedMarks(i,:);
                        mark.Action = categorical("Delete");
                        app.marksUndoStack = vertcat(app.marksUndoStack, mark);
                    end
                end
            end
            
            app.Update();
        end
        
        function UpdateDataMark(app, markName)
            markName = char(markName);
            app.data.(markName) = zeros(size(app.data.(markName)));
            if (~isempty( app.marks))
                markerStarts = app.marks.Start(app.marks.Name == markName);
                markerStops = app.marks.Stop(app.marks.Name == markName);
                app.data{markerStarts,markName} = 1;
                app.data{markerStops+1,markName} = -1;
                app.data.(markName)  = logical(cumsum(app.data.(markName) ));
            end
        end
        
        function Undo(app)
            if ( ~isempty(app.marksUndoStack) )
                mark = app.marksUndoStack(end,:);
                switch(mark.Action(1))
                    case 'Add'
                        app.marks(app.marks.ID == mark.ID,:) = [];
                    case 'Delete'
                        app.marks = vertcat(app.marks, mark(:,{'Name', 'Start', 'Stop', 'ID'}));
                end
                app.marksUndoStack(end,:) = [];
                app.UpdateDataMark(mark.Name);
            end
            
            app.Update();
        end
        
        function saved = SaveData(app)
            saved = false;
            MarkedData = app.data;
            [filename, pathname, ~] = uiputfile( ...
                {'*.mat','MAT-files (*.mat)'}, ...
                'Save as', 'MarkedData.mat');
            if ( ~isempty(filename) && ischar(filename) )
                save(fullfile(pathname,filename), 'MarkedData');
                saved = true;
            end
        end
    end
    
    % UI EVENTS
    methods (Access = private)
        
        function MouseMove(app, ~)
            app.UpdateCursor();
        end
        
        function ButtonDown(app, ~)
            switch(app.mainfig.SelectionType)
                case 'normal'
                    app.Mark();
                case 'alt'
                    app.Forward();
            end
        end
        
        function WindowscrollWheelFcn(app, event)
            if ( event.VerticalScrollCount > 0 )
                app.ZoomInY();
            else
                app.ZoomOutY();
            end
        end
        
        function KeyPress(app, event)
            
            switch(event.Key)
                case {'space' 'rightarrow'}
                    app.Forward();
                case 'leftarrow'
                    app.Backwards();
                case 'z'
                    if ( any(strcmp(event.Modifier, 'control')) )
                        app.Undo();
                    else
                        app.ZoomInSpan();
                    end
                case 'x'
                    app.ZoomOutSpan();
                case 'd'
                    app.DeleteMark();
                case {'uparrow' 'a'}
                    app.ZoomInY();
                case {'downarrow' 's'}
                    app.ZoomOutY();
                case 'escape'
                    app.ClearMark()
                case 'pagedown'
                    app.Forward(1);
                case 'pageup'
                    app.Backwards(1);
            end
        end
        
        function CloseRequest(app, ~)
            
            while(1)
                if (app.options.ShouldAskSave)
                    selection = questdlg('Are you sure you want to close?',...
                        'Closing', 'Yes', 'Save data first', 'Cancel','Yes');
                else
                    selection = questdlg('Are you sure you want to close?',...
                        'Closing','Yes', 'Cancel','Yes');
                end
                if ( isempty(selection) )
                    return;
                end
                
                switch selection
                    case 'Yes'
                        break;
                    case 'Save data first'
                        if (app.SaveData() )
                            break;
                        end
                        continue;
                    case 'Cancel'
                        return
                end
            end
            
            % close the main data figure
            if ( ishandle(app.mainfig) )
                close(app.mainfig);
            end
            
            % close the ui figure and delete the app
            delete(app.UIFigure);
        end
    end
    
    % UTIL
    methods(Static)
        
        function data = BlockCommandLine(app)
            
            % this function was quite a conundrum
            % Objective was to have a function that would block until the
            % UI is closed. But te problem is that then the object is
            % deleted and it is not possible to access to the data.
            %
            % Here I use a local function that can share a variable. So
            % when the event CloseRequest is called we save the data and
            % then let the course go with the normal CloseRequest handler.
            
            function CloseRequestReplacement(app, ev)
                data = app.data;
                previousCloseRequestFcn(app, ev);
            end
            
            previousCloseRequestFcn = app.UIFigure.CloseRequestFcn;
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @CloseRequestReplacement, true);
            uiwait(app.UIFigure);
        end
        
        function phaseTable = GetPhaseTable(data, phaseYesNo)
            
            eyes = {'Left' 'Right'};
            rows = {'X' 'Y' 'T'};
            eyesPresent = {};
            
            %% get QP properties
            SAMPLERATE = data.Properties.UserData.sampleRate;
            startStop = [find(diff([0;phaseYesNo])>0) find(diff([phaseYesNo;0])<0)];
            
            % properties common for all eyes and components
            phaseTable = [];
            phaseTable.StartIndex = startStop(:,1);
            phaseTable.EndIndex = startStop(:,2);
            
            phaseTable.DurationMs = (startStop(:,2) - startStop(:,1)) * 1000 / SAMPLERATE;
            
            props = [];
            for k=1:length(eyes)
                if ( ~any(strcmp(data.Properties.VariableNames,[eyes{k} rows{1}])) ...
                        && ~any(strcmp(data.Properties.VariableNames,[eyes{k} rows{2}])))
                    continue;
                end
                eyesPresent{end+1} = eyes{k};
                
                for j=1:length(rows)
                    if ( ~any(strcmp(data.Properties.VariableNames,[eyes{k} rows{j}])))
                        continue;
                    end
                    pos = data.([eyes{k} rows{j}]);
                    vel = data.([eyes{k} 'Vel' rows{j}]);
                    
                    
                    % properties specific for each component
                    row_props.GoodBegining = nan(size(startStop(:,1)));
                    row_props.GoodEnd = nan(size(startStop(:,1)));
                    row_props.GoodTrhought = nan(size(startStop(:,1)));
                    
                    row_props.Amplitude = nan(size(startStop(:,1)));
                    row_props.StartPosition = pos(startStop(:,1));
                    row_props.EndPosition = pos(startStop(:,2));
                    row_props.MeanPosition = nan(size(startStop(:,1)));
                    row_props.Displacement = pos(startStop(:,2)) - pos(startStop(:,1));
                    
                    row_props.PeakSpeed = nan(size(startStop(:,1)));
                    row_props.PeakVelocity = nan(size(startStop(:,1)));
                    row_props.PeakVelocityIdx = nan(size(startStop(:,1)));
                    row_props.MeanVelocity = nan(size(startStop(:,1)));
                    
                    for i=1:size(startStop,1)
                        qpidx = startStop(i,1):startStop(i,2);
                        row_props.GoodBegining(i)   = qpidx(1)>1 && ~isnan(vel(qpidx(1)-1));
                        row_props.GoodEnd(i)        = qpidx(end)<length(vel) && ~isnan(vel(qpidx(1)+1));
                        row_props.GoodTrhought(i)   = sum(isnan(vel(qpidx))) == 0;
                        
                        row_props.Amplitude(i)      = max(pos(qpidx)) - min(pos(qpidx));
                        row_props.MeanPosition(i)   = nanmean(pos(qpidx));
                        
                        [m,mi] = max(abs(vel(qpidx)));
                        row_props.PeakSpeed(i)      = m;
                        row_props.PeakVelocity(i)   = m*sign(vel(qpidx(mi)));
                        row_props.PeakVelocityIdx(i)= qpidx(1) -1 + mi;
                        row_props.MeanVelocity(i)   = nanmean(vel(qpidx));
                    end
                    
                    props.(eyes{k}).(rows{j}) = row_props;
                end
                
                % properties combinining X and Y
                pos = [data.([eyes{k} 'X']) data.([eyes{k} 'Y'])];
                speed = sqrt( data.([eyes{k} 'VelX']).^2 +  data.([eyes{k} 'VelY']).^2 );
                qp2_props.Amplitude = sqrt( props.(eyes{k}).X.Amplitude.^2 + props.(eyes{k}).Y.Amplitude.^2);
                qp2_props.Displacement = sqrt( (pos(startStop(:,2),1) - pos(startStop(:,1),1) ).^2 + ( pos(startStop(:,2),2) - pos(startStop(:,1),2) ).^2 );
                qp2_props.PeakSpeed = nan(size(startStop(:,1)));
                qp2_props.MeanSpeed = nan(size(startStop(:,1)));
                for i=1:size(startStop,1)
                    qpidx = startStop(i,1):startStop(i,2);
                    qp2_props.PeakSpeed(i) = max(speed(qpidx));
                    qp2_props.MeanSpeed(i) = nanmean(speed(qpidx));
                end
                props.(eyes{k}).XY = qp2_props;
            end
            
            fieldsToAverageAcrossEyes = {...
                'Amplitude'...
                'Displacement'...
                'PeakSpeed'...
                'MeanSpeed'...
                'StartPosition'...
                'EndPosition'...
                'MeanVelocity'...
                'MeanPosition'...
                };
            for i=1:length(fieldsToAverageAcrossEyes)
                field  = fieldsToAverageAcrossEyes{i};
                for j=1:3
                    if ( ~any(strcmp(data.Properties.VariableNames,[eyes{k} rows{j}])))
                        continue;
                    end
                    if ( any(contains(eyesPresent,'Left')) && any(contains(eyesPresent,'Right')) )
                        phaseTable.([rows{j} '_' field ]) = nanmean([ props.Left.(rows{j}).(field) props.Right.(rows{j}).(field)],2);
                    elseif(any(contains(eyesPresent,'Left')))
                        phaseTable.([rows{j} '_' field ]) = props.Left.(rows{j}).(field);
                    elseif(any(contains(eyesPresent,'Right')))
                        phaseTable.([rows{j} '_' field ]) = props.Right.(rows{j}).(field);
                    end
                end
                
                if ( isfield(props,'Left') && isfield(props,'Right') && isfield(props.Left.XY,field) && isfield(props.Right.XY,field))
                    phaseTable.(field) = nanmean([ props.Left.XY.(field) props.Right.XY.(field)],2);
                elseif ( isfield(props,'Left') && isfield(props.Left.XY,field))
                    phaseTable.(field) = props.Left.XY.(field);
                elseif ( isfield(props,'Right') && isfield(props.Right.XY,field))
                    phaseTable.(field) = props.Right.XY.(field);
                end
            end
            
            
            
            % merge props
            for k=1:length(eyes)
                if ( ~any(strcmp(data.Properties.VariableNames,[eyes{k} rows{1}])) ...
                        && ~any(strcmp(data.Properties.VariableNames,[eyes{k} rows{2}])))
                    continue;
                end
                fields = fieldnames(props.(eyes{k}).XY);
                for i=1:length(fields)
                    phaseTable.([ eyes{k} '_' fields{i}]) = props.(eyes{k}).XY.(fields{i});
                end
                
                for j=1:3
                    if ( ~any(strcmp(data.Properties.VariableNames,[eyes{k} rows{j}])))
                        continue;
                    end
                    fields = fieldnames(props.(eyes{k}).(rows{j}));
                    for i=1:length(fields)
                        phaseTable.([ eyes{k} '_' rows{j} '_' fields{i}]) = props.(eyes{k}).(rows{j}).(fields{i});
                    end
                end
            end
            
            phaseTable = struct2table(phaseTable);
        end
        
        function slowPhaseTable = GetSlowPhaseTable(data)
            slowPhaseTable = VOGDataExplorer.GetPhaseTable(data, data.SlowPhase);
        end
        
        function quickPhaseTable = GetQuickPhaseTable(data)
            quickPhaseTable = VOGDataExplorer.GetPhaseTable(data, data.QuickPhase);
        end
        
        function [ha, pos, rowcol] = tight_subplot(Nh, Nw, gap, marg_h, marg_w)
            
            % tight_subplot creates "subplot" axes with adjustable gaps and margins
            %
            % [ha, pos] = tight_subplot(Nh, Nw, gap, marg_h, marg_w)
            %
            %   in:  Nh      number of axes in hight (vertical direction)
            %        Nw      number of axes in width (horizontaldirection)
            %        gap     gaps between the axes in normalized units (0...1)
            %                   or [gap_h gap_w] for different gaps in height and width
            %        marg_h  margins in height in normalized units (0...1)
            %                   or [lower upper] for different lower and upper margins
            %        marg_w  margins in width in normalized units (0...1)
            %                   or [left right] for different left and right margins
            %
            %  out:  ha     array of handles of the axes objects
            %                   starting from upper left corner, going row-wise as in
            %                   subplot
            %        pos    positions of the axes objects
            %
            %  Example: ha = tight_subplot(3,2,[.01 .03],[.1 .01],[.01 .01])
            %           for ii = 1:6; axes(ha(ii)); plot(randn(10,ii)); end
            %           set(ha(1:4),'XTickLabel',''); set(ha,'YTickLabel','')
            
            % Pekka Kumpulainen 21.5.2012   @tut.fi
            % Tampere University of Technology / Automation Science and Engineering
            
            
            if nargin<3; gap = .02; end
            if nargin<4 || isempty(marg_h); marg_h = .05; end
            if nargin<5; marg_w = .05; end
            
            if numel(gap)==1;
                gap = [gap gap];
            end
            if numel(marg_w)==1;
                marg_w = [marg_w marg_w];
            end
            if numel(marg_h)==1;
                marg_h = [marg_h marg_h];
            end
            
            axh = (1-sum(marg_h)-(Nh-1)*gap(1))/Nh;
            axw = (1-sum(marg_w)-(Nw-1)*gap(2))/Nw;
            
            py = 1-marg_h(2)-axh;
            
            rowcol = [];
            % ha = zeros(Nh*Nw,1);
            ii = 0;
            for ih = 1:Nh
                px = marg_w(1);
                
                for ix = 1:Nw
                    ii = ii+1;
                    ha(ii) = axes('Units','normalized', ...
                        'Position',[px py axw axh], ...
                        'XTickLabel','', ...
                        'YTickLabel','');
                    px = px+axw+gap(2);
                    rowcol(ii,[1 2]) = [ih, ix];
                end
                py = py-axh-gap(1);
            end
            if nargout > 1
                pos = get(ha,'Position');
            end
            ha = ha(:);
        end
        
        function v = engbert_vecvel(xx,SAMPLING,TYPE)
            %------------------------------------------------------------
            %
            %  VELOCITY MEASURES
            %  - EyeLink documentation, p. 345-361
            %  - Engbert, R. & Kliegl, R. (2003) Binocular coordination in
            %    microsaccades. In:  J. Hyönä, R. Radach & H. Deubel (eds.)
            %    The Mind's Eyes: Cognitive and Applied Aspects of Eye Movements.
            %    (Elsevier, Oxford, pp. 103-117)
            %
            %  (Version 1.2, 01 JUL 05)
            %-------------------------------------------------------------
            %
            %  INPUT:
            %
            %  xy(1:N,1:2)     raw data, x- and y-components of the time series
            %  SAMPLING        sampling rate
            %
            %  OUTPUT:
            %
            %  v(1:N,1:2)     velocity, x- and y-components
            %
            %-------------------------------------------------------------
            N = length(xx(:,1));            % length of the time series
            M = length(xx(1,:));
            v = zeros(N,M);
            
            if ( SAMPLING < 1000 )
                switch TYPE
                    case 1
                        v(2:N-1,:) = SAMPLING/2*[xx(3:end,:) - xx(1:end-2,:)];
                    case 2
                        v(3:N-2,:)	= SAMPLING/6 * [xx(5:end,:) + xx(4:end-1,:) - xx(2:end-3,:) - xx(1:end-4,:)];
                        v(2,:)		= SAMPLING/2 * [xx(3,:) - xx(1,:)];
                        v(N-1,:)	= SAMPLING/2 * [xx(end,:) - xx(end-2,:)];
                end
            else
                
                v(9:end-8,:)	= SAMPLING/24 * [xx(17:end,:) + xx(13:end-4,:) - xx(5:end-12,:) - xx(1:end-16,:)];
                
            end
        end
        
    end
    
end
