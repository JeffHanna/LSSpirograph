/*
	LSSpirograph.ms
	Version: 1.33
	Created On: July 27, 2003 
	Created By: Jeff Hanna
	Modified On: December 31, 2017 
	Modified By: Jeff Hanna
	Tested using Max 5.1
	
	Copyright 2003 Lodestone Games, LLC. All Rights Reserved.

	
	Create Spirograph(tm)-like spline paths on screen. Useful for creating complex paths for particle system work.
	
	v1.33 - Updated the Macroscript and the mzp.run install file to handle Max's User Access Control compatible folders $userscripts, $usermacros, and $usericons.
	v1.32 - Reimplemented the animation slider's ability to affect Max's time slider in real time.	
	v1.31 - Made the execution of the BakeAnimations() function selectable in the UI.
	v1.3 - Placed emitters now have their animations baked to keyframes. This gets around the Gamebryo path animation bug(s).
	v1.21 - Explicity set the path constraint loop property to true.
	v1.2 - Rewrote the path constraint code so it works with Gamebryo
	v1.1 - Made the path constrained point objects follow the path, instead of always pointing in the same direction.
	v1.0 - Fully functional
	v0.98 - All done but for the path contraints
	v0.97 - Emitter placement UI implemented. Emitter placement function prototyped.
	v0.96 - Drop down templates fully functional.
	v0.95 - Template drop down list in UI. Not wired up yet.
	v0.92 - Informational dialogs and cursor wait states implemented
	v0.9 - First drawing-loop complete version.
*/


(
	--LOCAL VARIABLES
	-------------------
	local iFixedCircleRadius = 46 as integer									-- The radius of the fixed circle
	local iMovingCircleRadius = -10 as integer									-- The radius of the moving circle
	local iPenRadius = -40 as integer											-- The distance from the center of the moving circle to the pen
	local iStepSize = 2 as integer													-- The resolution of the output
																							-- (1 = every degree around the fixed circle, 2 = every other degree, etc...)
	
	local strEndFrame = animationRange.end as string						-- A variable to hold the start of the current animation range.
	local iAnimLength = (trimRight strEndFrame "f") as integer
	
	local bBakeAnims = false														-- boolean to control the exectuion of the BakeAnims() function
	local RotObj = eulerAngles 0 0 0
	local iEmitterCount = 4 as integer
	
																										
	
	--GLOBAL VARIABLES
	--------------------
	global rltLSSpirograph
	global rltDrawingDesign
	global rltEmitters
	
	
		
	--FUNCTIONS
	-------------
	fn BakeAnimations Emitter StartFrame EndFrame TimeStep =
	(
		Dupe = point()
		
		-- Turn the visible object of the emitter to an axis
		Dupe.cross = off
		Dupe.axistripod = on
		
		-- Set this property so the Gamebryo exporter doesn't discard the node.
		setUserPropBuffer Dupe "sgoKeep"
		
		rotate Dupe RotObj
		
		with animate on
		(
			for i = StartFrame to EndFrame by TimeStep do at time i Dupe.transform = Emitter.transform
		)
		Dupe.name = Emitter.name
		
		delete Emitter
	) -- end of BakeAnimations function
	
	
	fn PlaceEmitters iNumber RotObj PathObj = 
	(
		for i = 1 to iNumber do
		(
			Point pos:[0,0,0] isSelected:on
			
			EmitterObj = $
			
			-- Turn the visible object of the emitter to an axis
			EmitterObj.cross = off
			EmitterObj.axistripod = on
			
			-- Set this property so the Gamebryo exporter doesn't discard the node.
			setUserPropBuffer EmitterObj "sgoKeep"
		
			if i < 10 then
			(
				EmitterObj.name = "_emi_0" + (i as string)
			)
			else
			(
				EmitterObj.name = "_emi_" + (i as string)
			)
			
			-- Rotate the emitter to point the direction the user specified.
			rotate EmitterObj RotObj
				
			-- A bunch of voodoo to path constrain the emitter to the spline shape.
			EmitterObj.pos.controller = Path_Constraint()
			EmitterObj.pos.controller.path = PathObj
			EmitterObj.pos.controller.percent = (100 * (i as float / iNumber))
			EmitterObj.pos.controller.follow = true
			EmitterObj.pos.controller.loop = true
			
			if bBakeAnims == true then BakeAnimations EmitterObj 0 iAnimLength iStepSize
		)
		
		PathObj = undefined
	) -- end of PlaceEmitters function
	
	
	
	fn DrawSpiroGraph =
	(
		local iCircleRadiiSum = (iFixedCircleRadius + iMovingCircleRadius)			/*The sum of the two circle radii.
																											Adding it here, and not during each loop iteration, optimizes the drawing.*/
		local fRatio = (iCircleRadiiSum as float) / (iMovingCircleRadius as float)	/*A precomputed ratio needed by the algorythm.\n
																											Calculating it once here, and not during the loop, optimizes the drawing.*/
																											
		x = (iCircleRadiiSum * cos(0)) - (iPenRadius * cos(fRatio * 0))	-- The starting x position of the spline
		y = (iCircleRadiiSum * sin(0)) - (iPenRadius * sin(fRatio * 0))	-- The starting y position of the spline
		startX = x as integer														-- Store the starting x position for later comparison
		startY = y as integer														-- Store the starting y position for later comparison

		-- Set the wait cursor and display in informational dialog since this can take a while.
		setWaitCursor()
		createDialog rltDrawingDesign "LSSpirograph" width:160 height:32
		
		-- Create a new spline shape with it's origin at 0,0,0. Add a spline to it and add a knot at the starting x,y,z position
		SpiroGraph = splineShape pos:[0,0,0]
		addNewSpline SpiroGraph
		addKnot SpiroGraph 1 #corner #line [x,y,0]
		
		-- Starting at a time(t) of zero, increment through the loop by iStepSize
		t = 0
		bExit = false
		while ((t += iStepSize) > 0 == true) and bExit == false do
		(
			x = (iCircleRadiiSum * cos(t)) - (iPenRadius * cos(fRatio * t))
			y = (iCircleRadiiSum * sin(t)) - (iPenRadius * sin(fRatio * t))
			
			-- If a full revolution around iFixed circle has happend and x and y == startX and startY then the shape is complete. Exit the loop.
			if (mod t 360 == 0) and (x as integer == startX) and (y as integer == startY) then
			(
				bExit = true
				exit
			)
			else
			(	
				-- If not at the end condition, add a spline knot at the plotted point.
				addKnot SpiroGraph 1 #corner #line [x,y,0]
			) -- end of if loop
		) -- end of do loop	
		
		-- When the drawing is complete close and update the spline shape and redraw the scene.
		close SpiroGraph 1
		updateShape SpiroGraph
		
		-- Select the path, name it, and assign it to a variable  (needed for the emitter placement)
		select SpiroGraph
		global PathObj = $
		$.name = "SpiroGraph"	
		forceCompleteRedraw()
		
		-- Destory the informational dialog and return the mouse cursor to the point state.
		destroyDialog rltDrawingDesign
		setArrowCursor()
	) -- end of DrawSpiroGraph function	
	

	fn ChangeDrawingValues FixedCircle MovingCircle PenRadius =
	(
		rltLSSpirograph.sldFixedCircleRadius.value = FixedCircle
		rltLSSpirograph.lblFixedCircleRadius.text = FixedCircle as string
		iFixedCircleRadius = FixedCircle
		
		rltLSSpirograph.sldMovingCircleRadius.value = MovingCircle
		rltLSSpirograph.lblMovingCircleRadius.text = MovingCircle as string
		iMovingCircleRadius = MovingCircle
		
		rltLSSpirograph.sldPenRadius.value = PenRadius
		rltLSSpirograph.lblPenRadius.text = PenRadius as string
		iPenRadius = PenRadius * -1
	) -- end of ChangeDrawingValues function
	

		
	--USER INTERFACE CONTROLS
	-----------------------------
	rollout rltLSSpirograph "LSSpirograph" width:162 height:400
	(
		bitmap bmp1 "Bitmap" pos:[6,8] width:150 height:75 enabled:true fileName:"$usericons\LSSpirograph.bmp"
		groupBox grpTemplates "" pos:[6,80] width:150 height:56
		dropDownList ddTemplates "Templates" pos:[10,88] width:144 height:40 items:#("Steve's Peanut", "Ed's Circle", "Matt's Eye", "Carnation", "Cardioid", "Astroid", "Four-leaved Rose", "Verticle Line", "Ellipse", "Rounded Square", "Gold Fish", "Star Fish", "Spiral In, Spiral Out", "Orbit") selection:4
		
		groupBox grpControls "" pos:[6,136] width:150 height:208
		slider sldFixedCircleRadius "Fixed Circle Radius" pos:[10,152] width:144 height:44 range:[-100,100,iFixedCircleRadius] type:#integer ticks:0
		label lblFixedCircleRadius "!" pos:[120,152] width:32 height:16
		slider sldMovingCircleRadius "Moving Circle Radius" pos:[10,200] width:144 height:44 range:[-100,100,iMovingCircleRadius] type:#integer ticks:0
		label lblMovingCircleRadius "!" pos:[120,200] width:32 height:16
		slider sldPenRadius "Pen Radius" pos:[10,248] width:144 height:44 range:[-100,100,(iPenRadius * -1)] type:#integer ticks:0
		label lblPenRadius "!" pos:[120,248] width:32 height:16
		slider sldStepSize "Drawing Resolution" pos:[10,296] width:144 height:44 range:[1,100,(100 / iStepSize)] type:#integer ticks:0
		label lblStepSize "!" pos:[120,296] width:32 height:16
		button btnDraw "Draw" pos:[6,352] width:150 height:40
			
		on rltLSSpirograph open  do
		(
			lblFixedCircleRadius.text = sldFixedCircleRadius.value as string
			lblMovingCircleRadius.text = sldMovingCircleRadius.value as string
			lblPenRadius.text = sldPenRadius.value as string
			lblStepSize.text = sldStepSize.value as string + "%"
		)
		on ddTemplates selected i do
		(
			case i of
			(
				1: ChangeDrawingValues 100 50 50
				2: ChangeDrawingValues 100 100 0
				3: ChangeDrawingValues 50 75 33
				4: ChangeDrawingValues 46 -10 40
				5: ChangeDrawingValues 60 60 60
				6: ChangeDrawingValues 60 -15 -15
				7: ChangeDrawingValues 60 -15 45
				8: ChangeDrawingValues 60 -30 -30
				9: ChangeDrawingValues 60 -30 -90
			  10: ChangeDrawingValues 60 -45 -101
			  11: ChangeDrawingValues 75 -25 85
			  12: ChangeDrawingValues 75 -30 60
			  13: ChangeDrawingValues 5 60 60
			  14: ChangeDrawingValues 60 59 80
		  	)				
		)
		on sldFixedCircleRadius changed val do
		(
			lblFixedCircleRadius.text = val as string
			iFixedCircleRadius = val
		)
		on sldMovingCircleRadius changed val do
		(
			lblMovingCircleRadius.text = val as string
			iMovingCircleRadius = val
		)
		on sldPenRadius changed val do
		(
			lblPenRadius.text = val as string
			iPenRadius = val * -1
		)
		on sldStepSize changed val do
		(
			lblStepSize.text = val as string + "%"
			iStepSize = 100 / val
		)
		on btnDraw pressed  do
		(
			DrawSpiroGraph()
			if querybox "Would you like to place particle emitters on this design?" title:"LSSpirograph" modal:true beep:false == true then
			(
				createDialog rltEmitters "LSSpirograph" width:165 height:287
			)
		)
	) -- end of rollout rltLSSpirograph
	
	
	rollout rltDrawingDesign "LSSpirograph" width:160 height:32
	(
		label lblDrawing "Drawing the design..." pos:[8,8] width:104 height:16
	) -- end of rollout rltDrawingDesign
	
	
	rollout rltEmitters "LSSpirograph" width:165 height:287
	(
		groupBox grpEmitters "" pos:[8,96] width:150 height:136
		radioButtons rdoOrientation "Axis Orientation" pos:[18,162] width:53 height:62 labels:#("+X Up", "+Y Up", "+Z Up") default:3
		slider sldEmitterCount "Number of Emitters" pos:[18,112] width:136 height:44 range:[1,10,1] type:#integer ticks:0
		button btnPlaceEmitters "Ok" pos:[8,240] width:150 height:40
		label lblEmitterCount "!" pos:[120,112] width:20 height:13
		groupBox grpAnimation "" pos:[8,0] width:150 height:96
		slider sldAnimLength "Length of Animation" pos:[12,10] width:136 height:44 range:[1,200,30] type:#integer ticks:0
		label lblAnimLength "!" pos:[120,10] width:20 height:13
		checkbox chkBakeAnims "Bake animation to keyframes" pos:[16,56] width:128 height:32
		
		on rltEmitters open  do
		(
			sldAnimLength.value = iAnimLength
			lblAnimLength.text = sldAnimLength.value as string
			
			sldEmitterCount.value = iEmitterCount
			lblEmitterCount.text = sldEmitterCount.value as string
			
			chkBakeAnims.state = bBakeAnims
		)
		on rdoOrientation changed stat do
		(
			case stat of
			(
			   1: RotObj = eulerAngles 0 -90 0
			   2: RotObj = eulerAngles 90 0 0
			   3: RotObj = eulerAngles 0 0 0
			)
		)
		on sldEmitterCount changed val do
		(
			lblEmitterCount.text = val as string
			iEmitterCount = val
		)
		on btnPlaceEmitters pressed  do
		(
			PlaceEmitters iEmitterCount RotObj PathObj
			destroyDialog rltEmitters
		)
		on sldAnimLength changed val do
		(
			iAnimLength = val
			lblAnimLength.text = val as string
			
			animationRange = interval 0 iAnimLength
			sliderTime = 0
		)
		on chkBakeAnims changed state do bBakeAnims = state
	) -- end of rollout rltEmitters
	
	
	--MAIN LOOP
	------------
	units.DisplayType = #metric
	units.MetricType = #meters
	units.SystemType = #centimeters
	
	sliderTime = 0
	createDialog rltLSSpirograph "LSSpirograph" width:162 height:400
)