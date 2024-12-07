function maskOverlayGUI()
    % Define colors
    bgColor = [0.90, 0.94, 0.98];
    panelColor = [0.82, 0.88, 0.94];
    accentColor = [0.22, 0.45, 0.72];
    textColor = [0.10, 0.18, 0.36];
    btnColor = [0.70, 0.80, 0.90];
    highlightColor = [0.07, 0.20, 0.32];

    % Create main figure
    hFig = figure('Name', 'Juliver''s Mask Manager', 'NumberTitle', 'off', ...
        'MenuBar', 'none', 'ToolBar', 'none', ...
        'Position', [100, 100, 1000, 700], 'Resize', 'on', ...
        'Color', bgColor);

    % Struct to hold handles
    handles = struct();

    % Decorative top highlight bar
    hTopBar = uipanel('Parent', hFig, ...
                      'BackgroundColor', highlightColor, ...
                      'Units', 'normalized', ...
                      'Position', [0, 0.92, 1, 0.08], ...
                      'BorderType', 'none');

    % Title with stylized text
    hTitle = uicontrol('Style', 'text', 'Parent', hTopBar, ...
                       'String', 'Juliver''s Mask Manager', ...
                       'FontSize', 22, 'FontWeight', 'bold', ...
                       'ForegroundColor', [1 1 1], ...
                       'BackgroundColor', highlightColor, ...
                       'Units', 'normalized', ...
                       'Position', [0.01, 0.2, 0.98, 0.6], ...
                       'HorizontalAlignment', 'center');

    % Create panels
    hButtonPanel   = createStylizedPanel(hFig, 'Controls',       [0.02, 0.75, 0.34, 0.15], panelColor, textColor);
    hGeneratePanel = createStylizedPanel(hFig, 'Generate Overlay',[0.37, 0.75, 0.14, 0.15], panelColor, textColor);
    hInfoPanel     = createStylizedPanel(hFig, 'Info & Actions', [0.52, 0.75, 0.37, 0.15], panelColor, textColor);

    % Axes to display image + mask
    handles.hAxes = axes('Parent', hFig, ...
                         'Units', 'normalized', ...
                         'Position', [0.1, 0.1, 0.8, 0.6], ...
                         'XColor', accentColor, 'YColor', accentColor, ...
                         'LineWidth', 1.5);
    axis off;

    % Controls in hButtonPanel
    createStylizedButton(hButtonPanel, 'Load Image', [10, 50, 100, 30], accentColor, @loadImageCallback);
    createStylizedButton(hButtonPanel, 'Load Mask',  [120, 50, 100, 30], accentColor, @loadMaskCallback);
    createStylizedButton(hButtonPanel, 'Generate Mask', [230, 50, 100, 30], accentColor, @openGenerateMaskDialog);
    % Text for mask opacity
    uicontrol('Style', 'text', 'Parent', hButtonPanel, ...
        'String', 'Mask Opacity:', ...
        'FontSize', 9, ...
        'Position', [10, 30, 100, 15], ...
        'BackgroundColor', panelColor, ...
        'ForegroundColor', textColor, ...
        'HorizontalAlignment', 'left');

    % Slider for opacity
    opacitySlider = uicontrol('Style', 'slider', 'Parent', hButtonPanel, ...
        'TooltipString', 'Adjust mask transparency', ...
        'Min', 0, 'Max', 1, 'Value', 0.5, ...
        'Position', [10, 10, 210, 20], ...
        'BackgroundColor', [1 1 1]*0.95, ...
        'Callback', @opacitySliderCallback);

    % Generate button
    createStylizedButton(hGeneratePanel, 'Generate', [20, 30, 100, 40], highlightColor, @generateMaskCallback, true);

    % Info & actions panel buttons
    createStylizedButton(hInfoPanel, 'Info',       [10,  50, 60, 30], accentColor, @(~,~) infoCallback());
    createStylizedButton(hInfoPanel, 'Quit',       [80,  50, 60, 30], [0.9 0.4 0.4], @(~,~) close(hFig));
    createStylizedButton(hInfoPanel, 'Reset View', [10,  10, 80, 30], accentColor, @resetViewCallback);
    createStylizedButton(hInfoPanel, 'Reset Mask', [100, 10, 80, 30], accentColor, @resetMaskCallback);
    createStylizedButton(hInfoPanel, 'Invert Mask',[190, 10, 80, 30], accentColor, @invertMaskCallback);

    % Button to edit mask
    createStylizedButton(hInfoPanel, 'Edit Mask', [280, 10, 80, 30], accentColor, @openMaskEditor);

    % Init data
    handles.img = [];
    handles.mask = [];
    handles.hMask = [];
    handles.maskPos = [1, 1];
    handles.isDragging = false;
    handles.lastPoint = [];
    handles.invertMaskColor = false;
    handles.originalXLim = [];
    handles.originalYLim = [];
    handles.maxUndoSteps = 10; 
    handles.maskPosStack = {};

    % Scroll wheel for zoom
    set(hFig, 'WindowScrollWheelFcn', @scrollZoom);

    % Key press for toggling color, undo, arrow keys
    set(hFig, 'KeyPressFcn', @keyPressCallback);

    guidata(hFig, handles);

    % Add translucent effects
    addPanelShineEffect(hFig);

    %% Callbacks
    function loadImageCallback(~, ~)
        handles = guidata(hFig);
        [file, path] = uigetfile({'*.png;*.jpg;*.jpeg;*.bmp','Image Files'}, 'Select an Image');
        if isequal(file, 0)
            return;
        end
        handles.img = imread(fullfile(path, file));
        imshow(handles.img, 'Parent', handles.hAxes);
        title(handles.hAxes, 'Image Loaded');

        axis(handles.hAxes, 'image');
        handles.originalXLim = get(handles.hAxes, 'XLim');
        handles.originalYLim = get(handles.hAxes, 'YLim');

        handles.hMask = [];
        guidata(hFig, handles);
    end

    function loadMaskCallback(~, ~)
        handles = guidata(hFig);
        if isempty(handles.img)
            warndlg('Load an image before loading a mask!', 'Warning');
            return;
        end

        [file, path] = uigetfile({'*.png;*.jpg;*.bmp', 'Mask Files'}, 'Select a Binary Mask');
        if isequal(file, 0)
            return;
        end
        tempMask = imread(fullfile(path, file));
        if size(tempMask, 3) > 1
            tempMask = tempMask(:,:,1);
        end
        handles.mask = logical(tempMask);

        imshow(handles.img, 'Parent', handles.hAxes);
        hold(handles.hAxes, 'on');
        handles.hMask = image('CData', repmat(handles.mask, [1 1 3]), 'Parent', handles.hAxes);
        set(handles.hMask, 'AlphaData', get(opacitySlider, 'Value') * double(handles.mask));
        hold(handles.hAxes, 'off');

        handles.maskPos = [1, 1];
        handles.maskPosStack = {};
        pushMaskPosition(handles);

        set(hFig, 'WindowButtonDownFcn', @startDrag);
        set(hFig, 'WindowButtonMotionFcn', @dragMask);
        set(hFig, 'WindowButtonUpFcn', @stopDrag);

        guidata(hFig, handles);
    end

    function generateMaskCallback(~, ~)
        handles = guidata(hFig);
        if isempty(handles.mask) || isempty(handles.img)
            warndlg('Load both image and mask first!', 'Warning');
            return;
        end

        [maskH, maskW] = size(handles.mask);
        overlayedMask = zeros(size(handles.img, 1), size(handles.img, 2));
        yStart = handles.maskPos(2);
        xStart = handles.maskPos(1);
        yEnd = yStart + maskH - 1;
        xEnd = xStart + maskW - 1;

        yStart = max(1, yStart);
        xStart = max(1, xStart);
        yEnd = min(size(overlayedMask,1), yEnd);
        xEnd = min(size(overlayedMask,2), xEnd);

        if yStart <= yEnd && xStart <= xEnd
            overlayedMask(yStart:yEnd, xStart:xEnd) = ...
                handles.mask((yStart - handles.maskPos(2) + 1):(yEnd - handles.maskPos(2) + 1), ...
                             (xStart - handles.maskPos(1) + 1):(xEnd - handles.maskPos(1) + 1));
        end

        figure('Name', 'Final Overlayed Mask', 'NumberTitle', 'off');
        imshow(overlayedMask, []);
        title('Overlayed Mask');
    end

    function infoCallback(~, ~)
        % Create  message for better usability
        msg = sprintf([ ...
            'HOW TO USE JULIVER''S MASK MANAGER\n\n', ...
            '--------------------------------------\n', ...
            'LOADING DATA:\n', ...
            '1. Load an image with "Load Image".\n', ...
            '2. Load a binary mask with "Load Mask".\n', ...
            '3. Optionally, generate a new mask with "Generate Mask".\n', ...
            '   - Generate a mask based on brightness, edges, or color.\n', ...
            '   - Adjust the threshold using the slider.\n\n', ...
            '--------------------------------------\n', ...
            'EDITING THE MASK:\n', ...
            '1. Click "Edit Mask" to enter the Mask Editor.\n', ...
            '2. In the editor:\n', ...
            '   - Use the brush to paint or erase regions of the mask.\n', ...
            '   - Adjust the brush size using the slider.\n', ...
            '   - Toggle between paint/erase modes with the SPACE key.\n', ...
            '   - Toggle mask transparency with the T key.\n', ...
            '   - Zoom in/out using the scroll wheel.\n\n', ...
            '--------------------------------------\n', ...
            'MOVING AND ADJUSTING THE MASK:\n', ...
            '1. Drag the mask with the mouse to move it.\n', ...
            '2. Use arrow keys for precise movements:\n', ...
            '   - SHIFT + Arrow Key = Move by 10 pixels.\n', ...
            '   - Arrow Key = Move by 1 pixel.\n', ...
            '3. Reset the mask to its original position with "Reset Mask".\n\n', ...
            '--------------------------------------\n', ...
            'ADDITIONAL FEATURES:\n', ...
            '1. Adjust mask transparency using the slider.\n', ...
            '2. Invert the mask within its size bounds with "Invert Mask".\n', ...
            '3. Reset the zoom view with "Reset View".\n', ...
            '4. Reset the mask position with "Reset Mask".\n\n', ...
            '--------------------------------------\n', ...
            'GENERATING THE FINAL OVERLAY:\n', ...
            '1. Once satisfied, click "Generate" to overlay the mask on the image.\n', ...
            '2. The overlay will be displayed in a new window.\n\n', ...
            '--------------------------------------\n', ...
            'HOTKEYS SUMMARY:\n', ...
            '- SPACE: Toggle paint/erase mode (in Mask Editor).\n', ...
            '- T: Toggle mask transparency (in Mask Editor).\n', ...
            '- SHIFT + Arrow Keys: Move mask by 10 pixels.\n', ...
            '- Arrow Keys: Move mask by 1 pixel.\n\n', ...
            '--------------------------------------\n', ...
            'For questions, contact Julian Weaver (julian.weaver@utexas.edu).']);
    
        % Display info in message box
        msgbox(msg, 'Juliver''s Mask Manager Info', 'help');
    end

    function opacitySliderCallback(src, ~)
        handles = guidata(hFig);
        if ~isempty(handles.hMask) && ~isempty(handles.mask)
            val = get(src, 'Value');
            set(handles.hMask, 'AlphaData', val * double(handles.mask));
        end
    end

    function resetViewCallback(~, ~)
        handles = guidata(hFig);
        if ~isempty(handles.originalXLim) && ~isempty(handles.originalYLim)
            set(handles.hAxes, 'XLim', handles.originalXLim, 'YLim', handles.originalYLim);
            drawnow;
        end
        guidata(hFig, handles);
    end

    function resetMaskCallback(~, ~)
        handles = guidata(hFig);
        if ~isempty(handles.mask)
            handles.maskPos = [1, 1];
            updateMaskPosition(handles);
            handles.maskPosStack = {};
            pushMaskPosition(handles);
        end
        guidata(hFig, handles);
    end

    function invertMaskCallback(~, ~)
        handles = guidata(hFig);
        
        if isempty(handles.mask)
            warndlg('No mask loaded to invert!', 'Warning');
            return;
        end
    
        % Invert mask
        handles.mask = ~handles.mask;
    
        % Check if hMask exists + is valid
        if isempty(handles.hMask) || ~isvalid(handles.hMask)
            warndlg('The mask object is missing. Please reload the mask.', 'Warning');
            return;
        end
    
        % Preserve mask's current position and color
        xData = get(handles.hMask, 'XData');
        yData = get(handles.hMask, 'YData');
        currentCData = get(handles.hMask, 'CData');
        invertedCData = 1 - currentCData; % Invert the mask color
    
        % Update existing mask object
        set(handles.hMask, 'CData', invertedCData); 
        set(handles.hMask, 'AlphaData', get(opacitySlider, 'Value') * double(handles.mask)); 
        set(handles.hMask, 'XData', xData, 'YData', yData); 
    
        guidata(hFig, handles);
    end

    function resizeCallback(~, ~)
        % Lock minimum window size
        minWidth = 1000;
        minHeight = 700;
        currentPos = get(hFig, 'Position');
        newWidth = max(currentPos(3), minWidth);
        newHeight = max(currentPos(4), minHeight);
        set(hFig, 'Position', [currentPos(1), currentPos(2), newWidth, newHeight]);

        % Adjust panels + elements dynamically
        set(hTopBar, 'Position', [0, 0.92, 1, 0.08]); % Keep top bar aligned
        set(hTitle, 'Position', [0.01, 0.2, 0.98, 0.6]);
    end

    %% Dragging Functions
    function startDrag(~, ~)
        handles = guidata(hFig);
        if isempty(handles.hMask)
            return;
        end
        handles.isDragging = true;
        cp = get(handles.hAxes, 'CurrentPoint');
        handles.dragStartPoint = [cp(1, 1), cp(1, 2)];
        handles.originalMaskPos = handles.maskPos;
        guidata(hFig, handles);
    end

    function dragMask(~, ~)
        handles = guidata(hFig);
        if ~handles.isDragging
            return;
        end
    
        % Get current mouse position
        cp = get(handles.hAxes, 'CurrentPoint');
        currentPoint = [cp(1, 1), cp(1, 2)];
        delta = currentPoint - handles.dragStartPoint;
    
        % Update mask position incrementally
        dx = round(delta(1));
        dy = round(delta(2));
        newMaskPos = handles.originalMaskPos + [dx, dy];
    
        % Only update if position actually changes
        if ~isequal(newMaskPos, handles.maskPos)
            handles.maskPos = newMaskPos;
            updateMaskPosition(handles);
            drawnow limitrate; % Force GUI to refresh efficiently
        end
    
        % Save updated handles
        guidata(hFig, handles);
    end

    function stopDrag(~, ~)
        handles = guidata(hFig);
        if handles.isDragging
            handles.isDragging = false;
    
            % Push final mask position to the stack
            pushMaskPosition(handles);
    
            % Save final mask position explicitly
            guidata(hFig, handles);
        end
    end

    function updateMaskPosition(handles)
        if isempty(handles.hMask)
            return;
        end
    
        % Calculate new mask bounds
        [maskH, maskW] = size(handles.mask);
        xData = handles.maskPos(1):handles.maskPos(1) + maskW - 1;
        yData = handles.maskPos(2):handles.maskPos(2) + maskH - 1;
    
        % Update mask's graphical position
        set(handles.hMask, 'XData', xData, 'YData', yData);
    
        % Force MATLAB to refresh GUI in real-time
        drawnow limitrate;
    end

    %% Scroll-Based Zoom
    function scrollZoom(~, event)
        handles = guidata(hFig);
        ax = handles.hAxes;
        cp = get(ax, 'CurrentPoint');
        x = cp(1,1);
        y = cp(1,2);

        xlimVal = get(ax, 'XLim');
        ylimVal = get(ax, 'YLim');

        zoomFactor = 1.2;

        if event.VerticalScrollCount > 0
            % Zoom out
            newXRange = (xlimVal - x)*zoomFactor + x;
            newYRange = (ylimVal - y)*zoomFactor + y;
        else
            % Zoom in
            newXRange = (xlimVal - x)/zoomFactor + x;
            newYRange = (ylimVal - y)/zoomFactor + y;
        end

        set(ax, 'XLim', newXRange, 'YLim', newYRange);
        drawnow;
    end

    %% Key Press (Undo, Color Toggle, Arrow Keys)
    function keyPressCallback(~, event)
        handles = guidata(hFig);
        step = 1; 
        if ismember('shift', event.Modifier)
            step = 10; 
        end

        moved = false;
        switch event.Key
            case 'leftarrow'
                handles.maskPos(1) = handles.maskPos(1) - step;
                moved = true;
            case 'rightarrow'
                handles.maskPos(1) = handles.maskPos(1) + step;
                moved = true;
            case 'uparrow'
                handles.maskPos(2) = handles.maskPos(2) - step;
                moved = true;
            case 'downarrow'
                handles.maskPos(2) = handles.maskPos(2) + step;
                moved = true;
        end

        if strcmp(event.Key, 'c')
            handles.invertMaskColor = ~handles.invertMaskColor; 
            updateMaskColor(handles);
        end

        % Undo (Ctrl+Z or Cmd+Z)
        if (ismember('control', event.Modifier) || ismember('command', event.Modifier)) && strcmp(event.Key, 'z')
            undoMaskMove(handles);
        end

        if moved && ~isempty(handles.mask)
            updateMaskPosition(handles);
            pushMaskPosition(handles);
        end

        guidata(hFig, handles);
    end

    function updateMaskColor(handles)
        if isempty(handles.hMask) || isempty(handles.mask)
            return;
        end
        if handles.invertMaskColor
            invertedData = 1 - double(handles.mask);
            cdata = repmat(invertedData, [1, 1, 3]);
        else
            cdata = repmat(double(handles.mask), [1, 1, 3]);
        end
        set(handles.hMask, 'CData', cdata);
        drawnow;
    end

    %% Undo Functions
    function pushMaskPosition(handles)
        if length(handles.maskPosStack) >= handles.maxUndoSteps
            handles.maskPosStack(1) = [];
        end
        handles.maskPosStack{end+1} = handles.maskPos;
        guidata(hFig, handles);
    end

    function undoMaskMove(handles)
        if length(handles.maskPosStack) > 1
            handles.maskPosStack(end) = [];
            handles.maskPos = handles.maskPosStack{end};
            updateMaskPosition(handles);
        end
    end

    %% Open Mask Editor

    function openMaskEditor(~, ~)
        handles = guidata(hFig);
        if isempty(handles.mask)
            warndlg('No mask loaded. Please load or generate a mask first.', 'Warning');
            return;
        end
    
        % Create mask editor figure
        maskEditFig = figure('Name', 'Edit Mask', 'NumberTitle', 'off', ...
            'MenuBar', 'none', 'ToolBar', 'none', ...
            'Position', [200, 200, 800, 600], ...
            'Color', [0.9, 0.94, 0.98]);
    
        % Create axes for mask editing
        editorHandles = struct();
        editorHandles.mask = handles.mask; % Copy current mask
        editorHandles.img = handles.img; % Store image
        editorHandles.maskPos = handles.maskPos; % Store mask position
        editorHandles.brushSize = 10;
        editorHandles.paintMode = true; % true for paint, false for erase
        editorHandles.isDrawing = false;
        editorHandles.transparentMode = false; % Start w/ binary-only mode
    
        % Display axes + mask
        editorHandles.ax = axes('Parent', maskEditFig, ...
            'Units', 'normalized', ...
            'Position', [0.05, 0.15, 0.7, 0.8]);
        editorHandles.hImg = imshow(editorHandles.img, 'Parent', editorHandles.ax); % Display image
        hold(editorHandles.ax, 'on');
        editorHandles.hMaskImage = imshow(editorHandles.mask, 'Parent', editorHandles.ax); % Display binary mask
        colormap(editorHandles.ax, [0 0 0; 1 1 1]); % Binary color map
        set(editorHandles.hMaskImage, 'AlphaData', 1); % Start with no transparency
        set(editorHandles.hMaskImage, 'XData', editorHandles.maskPos(1):editorHandles.maskPos(1) + size(editorHandles.mask, 2) - 1, ...
                                       'YData', editorHandles.maskPos(2):editorHandles.maskPos(2) + size(editorHandles.mask, 1) - 1);
        editorHandles.brushOutline = plot(NaN, NaN, 'r', 'LineWidth', 1); % Brush outline
        hold(editorHandles.ax, 'off');
        axis(editorHandles.ax, 'image');
    
        % Brush size slider and label
        uicontrol('Parent', maskEditFig, 'Style', 'text', ...
            'String', 'Brush Size:', 'FontSize', 10, ...
            'Units', 'normalized', ...
            'Position', [0.78, 0.85, 0.2, 0.05], ...
            'BackgroundColor', [0.9, 0.94, 0.98], ...
            'HorizontalAlignment', 'left');
        
        editorHandles.brushSlider = uicontrol('Parent', maskEditFig, 'Style', 'slider', ...
            'Min', 1, 'Max', 200, 'Value', editorHandles.brushSize, ... % Increase max size
            'Units', 'normalized', ...
            'Position', [0.78, 0.8, 0.2, 0.05], ...
            'Callback', @updateBrushSize);
            
        % Brush size display
        editorHandles.brushSizeText = uicontrol('Parent', maskEditFig, 'Style', 'text', ...
            'String', sprintf('Size: %d', editorHandles.brushSize), ...
            'FontSize', 10, 'Units', 'normalized', ...
            'Position', [0.78, 0.75, 0.2, 0.05], ...
            'BackgroundColor', [0.9, 0.94, 0.98], ...
            'HorizontalAlignment', 'left');
    
        % Mode indicator
        editorHandles.modeIndicator = uicontrol('Parent', maskEditFig, 'Style', 'text', ...
            'String', 'Mode: Paint', 'FontSize', 12, 'FontWeight', 'bold', ...
            'Units', 'normalized', ...
            'Position', [0.78, 0.7, 0.2, 0.05], ...
            'BackgroundColor', [0.22, 0.45, 0.72], 'ForegroundColor', [1 1 1], ...
            'HorizontalAlignment', 'center');
    
        % Instruction for switching modes
        uicontrol('Parent', maskEditFig, 'Style', 'text', ...
            'String', 'Press SPACE to switch modes', 'FontSize', 10, ...
            'Units', 'normalized', ...
            'Position', [0.78, 0.65, 0.2, 0.04], ...
            'BackgroundColor', [0.9, 0.94, 0.98], ...
            'ForegroundColor', [0, 0, 0], ...
            'HorizontalAlignment', 'center');
    
        % Instruction for toggling transparency
        uicontrol('Parent', maskEditFig, 'Style', 'text', ...
            'String', 'Press T to toggle transparency', 'FontSize', 10, ...
            'Units', 'normalized', ...
            'Position', [0.78, 0.6, 0.2, 0.04], ...
            'BackgroundColor', [0.9, 0.94, 0.98], ...
            'ForegroundColor', [0, 0, 0], ...
            'HorizontalAlignment', 'center');
    
        % Done and Cancel buttons
        uicontrol('Parent', maskEditFig, 'Style', 'pushbutton', ...
            'String', 'Done', 'FontSize', 12, ...
            'Units', 'normalized', ...
            'Position', [0.78, 0.2, 0.2, 0.07], ...
            'BackgroundColor', [0.2, 0.6, 0.2], 'ForegroundColor', [1 1 1], ...
            'Callback', @applyChanges);
    
        uicontrol('Parent', maskEditFig, 'Style', 'pushbutton', ...
            'String', 'Cancel', 'FontSize', 12, ...
            'Units', 'normalized', ...
            'Position', [0.78, 0.1, 0.2, 0.07], ...
            'BackgroundColor', [0.9, 0.4, 0.4], 'ForegroundColor', [1 1 1], ...
            'Callback', @(~,~) close(maskEditFig));
    
        % Set up callbacks for drawing
        set(maskEditFig, 'WindowButtonDownFcn', @startDrawing);
        set(maskEditFig, 'WindowButtonMotionFcn', @updateBrushOutline);
        set(maskEditFig, 'WindowButtonUpFcn', @stopDrawing);
    
        % Enable scroll-based zoom for the editor
        set(maskEditFig, 'WindowScrollWheelFcn', @editorScrollZoom);
    
        % Key press callback for toggling modes and transparency
        set(maskEditFig, 'KeyPressFcn', @keyPressHandler);
    
        guidata(maskEditFig, editorHandles);
    
        % Nested Functions
        function updateBrushSize(src, ~)
            editorHandles = guidata(maskEditFig);
            editorHandles.brushSize = round(get(src, 'Value'));
            set(editorHandles.brushSizeText, 'String', sprintf('Size: %d', editorHandles.brushSize));
            guidata(maskEditFig, editorHandles);
        end

        function keyPressHandler(~, event)
            editorHandles = guidata(maskEditFig);
            if strcmp(event.Key, 'space') % Toggle paint/erase mode
                editorHandles.paintMode = ~editorHandles.paintMode;
                if editorHandles.paintMode
                    set(editorHandles.modeIndicator, 'String', 'Mode: Paint', ...
                        'BackgroundColor', [0.22, 0.45, 0.72]);
                else
                    set(editorHandles.modeIndicator, 'String', 'Mode: Erase', ...
                        'BackgroundColor', [0.9, 0.2, 0.2]);
                end
            elseif strcmp(event.Key, 't') % Toggle transparency
                editorHandles.transparentMode = ~editorHandles.transparentMode;
                if editorHandles.transparentMode
                    set(editorHandles.hImg, 'Visible', 'on');
                    set(editorHandles.hMaskImage, 'AlphaData', 0.4);
                else
                    set(editorHandles.hImg, 'Visible', 'off');
                    set(editorHandles.hMaskImage, 'AlphaData', 1);
                end
            end
            guidata(maskEditFig, editorHandles);
        end
    
        function toggleMode(~, event)
            editorHandles = guidata(maskEditFig);
            if strcmp(event.Key, 'space') % Toggle on spacebar press
                editorHandles.paintMode = ~editorHandles.paintMode;
                if editorHandles.paintMode
                    set(editorHandles.modeIndicator, 'String', 'Mode: Paint', ...
                        'BackgroundColor', [0.22, 0.45, 0.72]);
                else
                    set(editorHandles.modeIndicator, 'String', 'Mode: Erase', ...
                        'BackgroundColor', [0.9, 0.2, 0.2]);
                end
            end
            guidata(maskEditFig, editorHandles);
        end
    
        function toggleTransparency(~, ~)
            editorHandles = guidata(maskEditFig);
            editorHandles.transparentMode = ~editorHandles.transparentMode;
    
            if editorHandles.transparentMode
                set(editorHandles.hImg, 'Visible', 'on');
                set(editorHandles.hMaskImage, 'AlphaData', 0.4);
            else
                set(editorHandles.hImg, 'Visible', 'off');
                set(editorHandles.hMaskImage, 'AlphaData', 1);
            end
    
            guidata(maskEditFig, editorHandles);
        end
    
        function startDrawing(~, ~)
            editorHandles = guidata(maskEditFig);
            editorHandles.isDrawing = true;
            guidata(maskEditFig, editorHandles);
            drawOnMask(); % Draw immediately at the start
        end
    
        function stopDrawing(~, ~)
            editorHandles = guidata(maskEditFig);
            editorHandles.isDrawing = false;
            guidata(maskEditFig, editorHandles);
        end
    
        function updateBrushOutline(~, ~)
            editorHandles = guidata(maskEditFig);
        
            % Get current mouse position
            pt = get(editorHandles.ax, 'CurrentPoint');
            x = round(pt(1, 1)); % Mouse X-coordinate
            y = round(pt(1, 2)); % Mouse Y-coordinate
        
            % Draw circular brush outline
            theta = linspace(0, 2 * pi, 100);
            radius = editorHandles.brushSize / 2;
            brushX = x + radius * cos(theta);
            brushY = y + radius * sin(theta);
        
            % Update brush outline on the screen
            set(editorHandles.brushOutline, 'XData', brushX, 'YData', brushY);
        
            % If actively drawing, apply mask changes
            if editorHandles.isDrawing
                drawOnMask();
            end
        end
    
        function drawOnMask(~, ~)
            editorHandles = guidata(maskEditFig);
        
            % Get current mouse position
            pt = get(editorHandles.ax, 'CurrentPoint');
            x = round(pt(1, 1)); % Mouse X-coordinate
            y = round(pt(1, 2)); % Mouse Y-coordinate
        
            % Adjust mouse coordinates relative to mask position
            xRel = x - editorHandles.maskPos(1) + 1; % Relative X within mask
            yRel = y - editorHandles.maskPos(2) + 1; % Relative Y within mask
        
            % Check bounds
            [maskH, maskW] = size(editorHandles.mask);
            if xRel < 1 || xRel > maskW || yRel < 1 || yRel > maskH
                return; % Skip if the mouse is outside the mask
            end
        
            % Compute circular brush mask
            radius = floor(editorHandles.brushSize / 2);
            [xx, yy] = meshgrid(-radius:radius, -radius:radius);
            circleMask = (xx.^2 + yy.^2) <= radius^2;
        
            % Calculate valid region within mask
            xStart = max(1, xRel - radius);
            xEnd = min(maskW, xRel + radius);
            yStart = max(1, yRel - radius);
            yEnd = min(maskH, yRel + radius);
        
            % Calculate valid region within circular brush mask
            maskXStart = max(1, 1 + radius - xRel);
            maskXEnd = size(circleMask, 2) - max(0, (xRel + radius) - maskW);
            maskYStart = max(1, 1 + radius - yRel);
            maskYEnd = size(circleMask, 1) - max(0, (yRel + radius) - maskH);
        
            % Apply changes to mask
            if editorHandles.paintMode
                editorHandles.mask(yStart:yEnd, xStart:xEnd) = ...
                    editorHandles.mask(yStart:yEnd, xStart:xEnd) | ...
                    circleMask(maskYStart:maskYEnd, maskXStart:maskXEnd);
            else
                editorHandles.mask(yStart:yEnd, xStart:xEnd) = ...
                    editorHandles.mask(yStart:yEnd, xStart:xEnd) & ...
                    ~circleMask(maskYStart:maskYEnd, maskXStart:maskXEnd);
            end
        
            % Update mask display
            set(editorHandles.hMaskImage, 'CData', editorHandles.mask); % Update mask image
            drawnow limitrate;
        
            guidata(maskEditFig, editorHandles);
        end
    
        function editorScrollZoom(~, event)
            editorHandles = guidata(maskEditFig);
            ax = editorHandles.ax;
            cp = get(ax, 'CurrentPoint');
            xC = cp(1,1);
            yC = cp(1,2);
    
            xlimVal = get(ax, 'XLim');
            ylimVal = get(ax, 'YLim');
            zoomFactor = 1.2;
    
            if event.VerticalScrollCount > 0
                % Zoom out
                newXRange = (xlimVal - xC)*zoomFactor + xC;
                newYRange = (ylimVal - yC)*zoomFactor + yC;
            else
                % Zoom in
                newXRange = (xlimVal - xC)/zoomFactor + xC;
                newYRange = (ylimVal - yC)/zoomFactor + yC;
            end
    
            set(ax, 'XLim', newXRange, 'YLim', newYRange);
            drawnow limitrate;
        end
    
        function applyChanges(~, ~)
            editorHandles = guidata(maskEditFig);
    
            % Apply changes to main GUI
            mainHandles = guidata(hFig);
            mainHandles.mask = editorHandles.mask;
            mainHandles.maskPos = editorHandles.maskPos; % Save updated mask position
    
            % Update main GUI display
            if ~isempty(mainHandles.img)
                imshow(mainHandles.img, 'Parent', mainHandles.hAxes);
                hold(mainHandles.hAxes, 'on');
                if ~isempty(mainHandles.hMask) && isvalid(mainHandles.hMask)
                    delete(mainHandles.hMask);
                end
                mainHandles.hMask = image('CData', repmat(mainHandles.mask, [1 1 3]), 'Parent', mainHandles.hAxes, ...
                                          'XData', mainHandles.maskPos(1):mainHandles.maskPos(1) + size(mainHandles.mask, 2) - 1, ...
                                          'YData', mainHandles.maskPos(2):mainHandles.maskPos(2) + size(mainHandles.mask, 1) - 1);
                set(mainHandles.hMask, 'AlphaData', get(opacitySlider, 'Value') * double(mainHandles.mask));
                hold(mainHandles.hAxes, 'off');
            end
    
            guidata(hFig, mainHandles);
            close(maskEditFig);
        end
    end

    %% Generate Masks

    function openGenerateMaskDialog(~, ~)
        handles = guidata(hFig);
    
        if isempty(handles.img)
            warndlg('Load an image before generating a mask!', 'Warning');
            return;
        end
    
        % Create new figure for mask generator dialog
        maskFig = figure('Name', 'Generate Binary Mask', 'NumberTitle', 'off', ...
                         'MenuBar', 'none', 'ToolBar', 'none', ...
                         'Position', [150, 150, 600, 400], ...
                         'Resize', 'off', 'Color', [0.9, 0.94, 0.98]);
    
        % Create panel for the preview
        uipanel('Parent', maskFig, 'Title', 'Preview', ...
                'FontSize', 10, 'Position', [0.5, 0.1, 0.45, 0.8], ...
                'BackgroundColor', [0.82, 0.88, 0.94]);
    
        hPreviewPanel = uipanel('Parent', maskFig, 'Title', 'Preview', ...
                        'FontSize', 10, 'Position', [0.5, 0.1, 0.45, 0.8], ...
                        'BackgroundColor', [0.82, 0.88, 0.94]);

        previewAxes = axes('Parent', hPreviewPanel, ...
                           'Units', 'normalized', ...
                           'Position', [0.1, 0.1, 0.8, 0.8], ...
                           'Box', 'on', ...
                           'XColor', [0.3, 0.3, 0.3], ...
                           'YColor', [0.3, 0.3, 0.3], ...
                           'Color', [1, 1, 1]);
    
        % Dropdown for selecting method
        uicontrol('Style', 'text', 'Parent', maskFig, ...
                  'String', 'Select Method:', 'FontSize', 10, ...
                  'Position', [20, 300, 100, 30], ...
                  'BackgroundColor', [0.9, 0.94, 0.98], ...
                  'HorizontalAlignment', 'left');
    
        methodMenu = uicontrol('Style', 'popupmenu', 'Parent', maskFig, ...
                               'String', {'Brightness Threshold', ...
                                          'Edge Detection', ...
                                          'Color Threshold'}, ...
                               'Position', [130, 305, 150, 25], ...
                               'Callback', @updatePreview);
    
        % Brightness threshold slider
        uicontrol('Style', 'text', 'Parent', maskFig, ...
                  'String', 'Threshold:', 'FontSize', 10, ...
                  'Position', [20, 250, 150, 30], ...
                  'BackgroundColor', [0.9, 0.94, 0.98], ...
                  'HorizontalAlignment', 'left');
        
        % Slider for threshold (fixed 0 to 1.0, fine-grained)
        brightnessSlider = uicontrol('Style', 'slider', 'Parent', maskFig, ...
                                     'Min', 0, 'Max', 1, 'Value', 0.5, ...
                                     'Position', [130, 260, 150, 20], ...
                                     'SliderStep', [0.01, 0.05], ... % Fine-grained step
                                     'Callback', @sliderValueChanged);
        
        % Numeric Display for slider value
        thresholdInput = uicontrol('Style', 'edit', 'Parent', maskFig, ...
                                   'String', '0.5', 'FontSize', 10, ...
                                   'Position', [130, 230, 150, 25], ... % Below the slider
                                   'BackgroundColor', [1 1 1], ...
                                   'Callback', @inputValueChanged);
        
        % Update brightness value dynamically
        set(brightnessSlider, 'Callback', @(src, ~) updateBrightnessValue(src));
            
        % Apply button
        uicontrol('Style', 'pushbutton', 'Parent', maskFig, ...
                  'String', 'Apply Mask', 'FontSize', 12, ...
                  'BackgroundColor', [0.22, 0.45, 0.72], 'ForegroundColor', [1, 1, 1], ...
                  'Position', [20, 50, 120, 40], ...
                  'Callback', @applyMask);
    
        % Preview variables
        currentMask = [];

        function sliderValueChanged(src, ~)
            % Get normalized slider value (0 to 1)
            normalizedValue = get(src, 'Value');
            
            % Update text box with the slider's value
            set(thresholdInput, 'String', sprintf('%.3f', normalizedValue));
            
            % Trigger preview update
            updatePreview();
        end

        function inputValueChanged(src, ~)
            % Get input value as a number
            inputValue = str2double(get(src, 'String'));
            
            % Validate input
            if isnan(inputValue) || inputValue < 0 || inputValue > 1
                warndlg('Please enter a value between 0 and 1.', 'Invalid Input');
                % Reset the text box to the current slider value
                set(src, 'String', sprintf('%.3f', get(brightnessSlider, 'Value')));
                return;
            end
            
            % Update slider with input value
            set(brightnessSlider, 'Value', inputValue);
            
            % Trigger preview update
            updatePreview();
        end
                
        function updateBrightnessValue(src, ~)
            % Get normalized slider value (0 to 1)
            normalizedValue = get(src, 'Value');
            
            % Update text box
            set(thresholdInput, 'String', sprintf('%.3f', normalizedValue));
            
            % Refresh preview
            updatePreview();
        end

        % Callback for changing methods
        function updateMode(~, ~)
            % Preserve current slider value
            currentNormalizedValue = get(brightnessSlider, 'Value');
            
            % Update method-specific properties (if any)
            methodIndex = get(methodMenu, 'Value');
            switch methodIndex
                case 1
                    set(brightnessSlider, 'TooltipString', 'Adjust brightness threshold (0-255)');
                case 2
                    set(brightnessSlider, 'TooltipString', 'Adjust edge detection sensitivity (0-1)');
                case 3
                    set(brightnessSlider, 'TooltipString', 'Adjust hue range (0-1)');
            end
            
            % Synchronize text box and refresh preview
            updateBrightnessValue(brightnessSlider);
        end
        
        % Attach callback to method menu
        set(methodMenu, 'Callback', @updateMode);

        function updatePreview(~, ~)
            % Get current method
            methodIndex = get(methodMenu, 'Value');
            
            % Get normalized slider value (0-1)
            normalizedValue = get(brightnessSlider, 'Value');
            grayImg = rgb2gray(handles.img); % Convert to grayscale for processing
            
            % Generate mask based on current method
            switch methodIndex
                case 1 % Brightness threshold
                    % Map normalized slider value to brightness range (0-255)
                    threshold = round(normalizedValue * 255);
                    currentMask = grayImg > threshold;
                
                case 2 % Edge detection
                    % Map normalized slider value to sensitivity range (0-1)
                    sensitivity = normalizedValue;
                    sobelX = [-1 0 1; -2 0 2; -1 0 1];
                    sobelY = [-1 -2 -1; 0 0 0; 1 2 1];
                    horizontalEdges = conv2(double(grayImg), sobelX, 'same');
                    verticalEdges = conv2(double(grayImg), sobelY, 'same');
                    edgeMagnitude = sqrt(horizontalEdges.^2 + verticalEdges.^2);
                    currentMask = edgeMagnitude > sensitivity * max(edgeMagnitude(:));
                
                case 3 % Color threshold
                    % Map normalized slider value to hue range (0-1)
                    hsvImg = rgb2hsv(handles.img);
                    hueChannel = hsvImg(:, :, 1);
                    hueCenter = normalizedValue; % Use slider as the center of hue range
                    hueRange = 0.1; % Define a fixed range around center
                    currentMask = hueChannel > (hueCenter - hueRange) & hueChannel < (hueCenter + hueRange);
                
                otherwise
                    currentMask = false(size(grayImg));
            end
            
            % Update preview display
            axes(previewAxes); % Explicitly set correct axes
            imshow(handles.img, 'Parent', previewAxes); % Show original image
            hold(previewAxes, 'on');
            overlay = imshow(cat(3, currentMask, zeros(size(currentMask)), zeros(size(currentMask))), 'Parent', previewAxes);
            set(overlay, 'AlphaData', 0.5); % Add transparency
            hold(previewAxes, 'off');
            drawnow;
        end
                    
        % Callback to apply mask
        function applyMask(~, ~)
            if isempty(currentMask)
                warndlg('No mask generated. Adjust the parameters and try again.', 'Warning');
                return;
            end
    
            % Store mask in main GUI handles
            handles.mask = currentMask;
    
            % Display the mask on main GUI
            imshow(handles.img, 'Parent', handles.hAxes);
            hold(handles.hAxes, 'on');
            handles.hMask = image('CData', repmat(currentMask, [1, 1, 3]), 'Parent', handles.hAxes);
            set(handles.hMask, 'AlphaData', 0.5 * double(currentMask));
            hold(handles.hAxes, 'off');
    
            handles.maskPos = [1, 1];
            handles.maskPosStack = {};
            pushMaskPosition(handles);
    
            % Enable dragging + other interactions
            set(hFig, 'WindowButtonDownFcn', @startDrag);
            set(hFig, 'WindowButtonMotionFcn', @dragMask);
            set(hFig, 'WindowButtonUpFcn', @stopDrag);
    
            % Close mask generator dialog
            close(maskFig);
    
            % Update main GUI handles
            guidata(hFig, handles);
        end
    
        % Init preview
        updatePreview();
    end

    %% Helper Functions for Styling

    function hPanel = createStylizedPanel(parent, titleStr, pos, bgC, fgC)
        hPanel = uipanel('Parent', parent, ...
            'Title', ['  ', titleStr], ...
            'FontSize', 10, ...
            'FontWeight', 'bold', ...
            'TitlePosition', 'centertop', ...
            'BackgroundColor', bgC, ...
            'ForegroundColor', fgC, ...
            'Units', 'normalized', ...
            'Position', pos, ...
            'HighlightColor', [1 1 1]*0.9, ...
            'BorderType', 'line', ...
            'BorderWidth', 1);
    end

    function createStylizedButton(parent, label, pos, color, callback, isPrimary)
        if nargin < 6
            isPrimary = false;
        end
        uicontrol('Style', 'pushbutton', ...
            'Parent', parent, ...
            'String', label, ...
            'FontSize', 10 + isPrimary*2, ...
            'FontWeight', 'bold', ...
            'BackgroundColor', color, ...
            'ForegroundColor', [1 1 1], ...
            'Units', 'pixels', ...
            'Position', pos, ...
            'Callback', callback, ...
            'FontName', 'Arial');
    end

    function addPanelShineEffect(parent)
        annotation(parent, 'rectangle', [0.05, 0.93, 0.9, 0.03], ...
            'FaceColor', accentColor, ...
            'FaceAlpha', 0.15, ...
            'LineStyle', 'none');
    end

end