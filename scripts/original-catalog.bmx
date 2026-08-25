' Deterministic visual-reference entry points for the isolated original build.
' This file is copied beside gridwars.bmx only by capture-original.sh.

Function CaptureOriginalCatalog:Int(mode$, directory$)
	Local entityKind:Int = -1
	Local motionKind:Int = -1
	Local blackHoleKind:Int = -1
	Local snakeKind:Int = -1
	Local interceptorKind:Int = -1
	Local triangleKind:Int = -1
	Local playerKind:Int = -1
	Local generatorKind:Int = -1
	Local powerKind:Int = -1
	Local gridKind:Int = -1
	Local particleKind:Int = -1
	Local graphicsKind:Int = -1
	Local overview:Int = False
	Local upgradedHUD:Int = False
	Local powerUpMessage:Int = False

	Select mode
		Case "gameplay"; overview = True
		Case "hud-default"; overview = 2
		Case "hud-upgraded"; overview = 2; upgradedHUD = True
		Case "power-up-message"; overview = 2; powerUpMessage = True

		Case "enemy-pinwheel"; entityKind = 0
		Case "enemy-diamond"; entityKind = 1
		Case "enemy-green-square"; entityKind = 2
		Case "enemy-cube"; entityKind = 3
		Case "enemy-seeker"; entityKind = 4
		Case "enemy-black-hole"; entityKind = 5
		Case "enemy-triangle"; entityKind = 6
		Case "enemy-snake"; entityKind = 7
		Case "enemy-interceptor"; entityKind = 8
		Case "enemy-butterfly"; entityKind = 9

		Case "motion-pinwheel"; motionKind = 0
		Case "motion-diamond"; motionKind = 1
		Case "motion-green-square"; motionKind = 2
		Case "motion-cube"; motionKind = 3
		Case "motion-seeker"; motionKind = 4
		Case "motion-butterfly"; motionKind = 9
		Case "black-hole-motion"; blackHoleKind = 0
		Case "black-hole-shrink"; blackHoleKind = 1
		Case "black-hole-explosion"; blackHoleKind = 2
		Case "snake-motion"; snakeKind = 0
		Case "snake-tail-hit"; snakeKind = 1
		Case "snake-cascade"; snakeKind = 2
		Case "interceptor-motion"; interceptorKind = 0
		Case "interceptor-shield"; interceptorKind = 1
		Case "interceptor-block"; interceptorKind = 2
		Case "triangle-motion"; triangleKind = 0
		Case "triangle-bond"; triangleKind = 1
		Case "triangle-hit"; triangleKind = 2
		Case "triangle-black-hole"; triangleKind = 3
		Case "player-motion"; playerKind = 0
		Case "player-boundary"; playerKind = 1
		Case "player-shield"; playerKind = 2
		Case "weapon-cannon-1"; playerKind = 3
		Case "weapon-cannon-2"; playerKind = 4
		Case "weapon-cannon-3"; playerKind = 5
		Case "weapon-cannon-4"; playerKind = 6
		Case "weapon-reverse-side"; playerKind = 7

		Case "generator-pinwheel"; generatorKind = 1
		Case "generator-diamond"; generatorKind = 2
		Case "generator-green-square"; generatorKind = 3
		Case "generator-cube"; generatorKind = 4
		Case "generator-seeker"; generatorKind = 5
		Case "generator-black-hole"; generatorKind = 6
		Case "generator-triangle"; generatorKind = 7
		Case "generator-snake"; generatorKind = 8
		Case "generator-interceptor"; generatorKind = 9
		Case "generator-butterfly"; generatorKind = 10

		Case "powerup-reverse"; powerKind = 0
		Case "powerup-side"; powerKind = 1
		Case "powerup-cannon"; powerKind = 2
		Case "powerup-faster"; powerKind = 3
		Case "powerup-player"; powerKind = 4
		Case "powerup-bomb"; powerKind = 5
		Case "powerup-shield"; powerKind = 6
		Case "powerup-super"; powerKind = 7
		Case "powerup-bouncy"; powerKind = 8

		Case "grid-00"; gridKind = 0
		Case "grid-01"; gridKind = 1
		Case "grid-02"; gridKind = 2
		Case "grid-03"; gridKind = 3
		Case "grid-04"; gridKind = 4
		Case "grid-05"; gridKind = 5
		Case "grid-06"; gridKind = 6
		Case "grid-07"; gridKind = 7
		Case "grid-08"; gridKind = 8
		Case "grid-09"; gridKind = 9
		Case "grid-10"; gridKind = 10
		Case "grid-11"; gridKind = 11
		Case "grid-12"; gridKind = 12
		Case "grid-13"; gridKind = 13
		Case "grid-14"; gridKind = 14
		Case "grid-15"; gridKind = 15
		Case "grid-16"; gridKind = 16
		Case "grid-17"; gridKind = 17
		Case "grid-18"; gridKind = 18
		Case "grid-19"; gridKind = 19
		Case "grid-20"; gridKind = 20

		Case "particle-0"; particleKind = 0
		Case "particle-1"; particleKind = 1
		Case "particle-2"; particleKind = 2
		Case "particle-3"; particleKind = 3

		Case "graphics-solid"; graphicsKind = 0
		Case "graphics-low"; graphicsKind = 1
		Case "graphics-medium"; graphicsKind = 2
		Case "graphics-high"; graphicsKind = 3
		Case "graphics-user"; graphicsKind = 4
		Default; Return False
	End Select

	PrepareOriginalCaptureState()
	If powerUpMessage Then score.ResetMultiplier()

	If gridKind >= 0
		showstars = 0
		g_style = gridKind
		gridpoint.Pull(SCREENW/2, SCREENH/2, 18, 28)
		For Local gridFrame:Int = 0 To 11
			gridpoint.UpdateGrid()
		Next
		Cls
		gridpoint.DrawGrid(g_style)
	ElseIf particleKind >= 0
		showstars = 0
		particlestyle = particleKind
		For Local particleIndex:Int = 0 To 191
			part.Create(SCREENW/2, SCREENH/2, 1, 255, 180, 32, Float(particleIndex)*360.0/192.0)
		Next
		For Local particleFrame:Int = 0 To 4
			part.UpdateParticles()
		Next
		Cls
		part.DrawParticles()
	Else
		If graphicsKind >= 0
			gfxset = graphicsKind
			LoadImages()
			overview = True
		EndIf

		If overview = True Then CaptureOriginalOverview()
		If entityKind >= 0 Then CaptureOriginalEnemy(entityKind)
		If motionKind >= 0 Then CaptureOriginalEnemyMotion(motionKind)
		If blackHoleKind >= 0 Then CaptureOriginalBlackHole(blackHoleKind)
		If snakeKind >= 0 Then CaptureOriginalSnake(snakeKind)
		If interceptorKind >= 0 Then CaptureOriginalInterceptor(interceptorKind)
		If triangleKind >= 0 Then CaptureOriginalTriangle(triangleKind)
		If playerKind >= 0 Then CaptureOriginalPlayer(playerKind)
		If generatorKind >= 0 Then ge.Create(SCREENW/2, SCREENH/2, generatorKind, 60, 24, 0)
		If powerKind >= 0 Then pu.Create(SCREENW/2, SCREENH/2, powerKind, 0)

		If overview = 2 And upgradedHUD
			numshots = 4
			shotspeed = 5
			numplayers = 4
			numbombs = 4
			shot_back = 360
			shot_side = 360
			supershots = 360
			bouncyshots = 360
			player_shield = 360
			pscore = 123456
			multiplier = 1
		EndIf

		Cls
		DrawAll()
	EndIf

	SaveScreenshot(directory + "/" + mode + ".png")
	Flip 1
	Return True
End Function

Function CaptureOriginalPlayer(kind:Int)
	px = SCREENW/2
	py = SCREENH/2
	oldmx = 0
	oldmy = 0
	inertia = .5

	Select kind
		Case 0
			px = 360
			For Local frame:Int = 0 Until 24
				If frame < 12
					CaptureOriginalPlayerStep(1, 0)
				Else
					CaptureOriginalPlayerStep(0, -1)
				EndIf
			Next
		Case 1
			px = 17
			CaptureOriginalPlayerStep(-1, 0)
		Case 2
			player_shield = 20*upgradetime
		Case 3, 4, 5, 6, 7
			numshots = kind-2
			If kind = 7 Then numshots = 1
			pr = -90
			CaptureOriginalNormalWeapon(numshots, kind = 7)
	End Select
End Function

Function CaptureOriginalPlayerStep(moveX#, moveY#)
	jdmx = moveX
	jdmy = moveY
	oldmx:*inertia
	oldmy:*inertia
	jdmx:+oldmx
	jdmy:+oldmy
	Local speed# = Sqr(jdmx*jdmx + jdmy*jdmy)
	If speed > 1
		jdmx = jdmx/speed
		jdmy = jdmy/speed
	EndIf
	oldmx = jdmx
	oldmy = jdmy

	px:+jdmx*MAXPLAYERSPEED
	If px < 16 Or px > PLAYFIELDW-16
		px:-jdmx*MAXPLAYERSPEED
		oldmx = -oldmx
	EndIf
	py:+jdmy*MAXPLAYERSPEED
	If py < 16 Or py > PLAYFIELDH-16
		py:-jdmy*MAXPLAYERSPEED
		oldmy = -oldmy
	EndIf
	If jdmy <> 0 Or jdmx <> 0 Then pr = ATan2(jdmy,jdmx)-90

	If Abs(jdmx) > .1 Or Abs(jdmy) > .1
		For Local index:Int = 0 To 2
			trail.Create(..
				px-jdmx*12+Sin(gcount*12+index*45)*8,..
				py-jdmy*12+Cos(gcount*12+index*45)*8,..
				COL_TRAIL_R,COL_TRAIL_G,COL_TRAIL_B,-jdmx,-jdmy)
		Next
	EndIf
	trail.UpdateTrail()
	gcount:+1
End Function

Function CaptureOriginalNormalWeapon(cannons:Int, extras:Int)
	Local aimX# = 1
	Local aimY# = 0
	Local xr#, yr#
	Local angle:Int
	Local speed# = shotspeed

	If cannons Mod 2 = 1
		xr = aimX*speed*3.2
		yr = aimY*speed*3.2
		shot.Create(px,py,xr,yr,speed*3.2)
	EndIf
	If cannons > 1
		If cannons Mod 2 = 0 Then angle = 2 Else angle = 4
		xr = aimX*speed*3.15;yr = aimY*speed*3.15
		TFormR(0,0,angle,xr,yr)
		shot.Create(px,py,xr,yr,speed*3.15)
		xr = aimX*speed*3.15;yr = aimY*speed*3.15
		TFormR(0,0,-angle,xr,yr)
		shot.Create(px,py,xr,yr,speed*3.15)
	EndIf
	If cannons > 3
		xr = aimX*speed*3.1;yr = aimY*speed*3.1
		TFormR(0,0,5,xr,yr)
		shot.Create(px,py,xr,yr,speed*3.1)
		xr = aimX*speed*3.1;yr = aimY*speed*3.1
		TFormR(0,0,-5,xr,yr)
		shot.Create(px,py,xr,yr,speed*3.1)
	EndIf
	If extras
		shot_back = 1
		shot_side = 1
		xr = aimX*speed*3;yr = aimY*speed*3
		TFormR(0,0,-180,xr,yr)
		shot.Create(px,py,xr,yr,speed*3)
		xr = aimX*speed*3;yr = aimY*speed*3
		TFormR(0,0,90,xr,yr)
		shot.Create(px,py,xr,yr,speed*3)
		xr = aimX*speed*3;yr = aimY*speed*3
		TFormR(0,0,-90,xr,yr)
		shot.Create(px,py,xr,yr,speed*3)
	EndIf

	For Local frame:Int = 0 Until 6
		For Local projectile:shot = EachIn shot_list
			projectile.Update()
		Next
	Next
End Function

Function CaptureOriginalTriangle(kind:Int)
	px = SCREENW/2
	py = 100
	Local centerX:Int = SCREENW/2
	Local centerY:Int = SCREENH/2
	Local first:le
	Local second:le
	Local triangle:le

	If kind = 0
		first = le.Create(centerX, centerY, 0, 1)
		For Local frame:Int = 0 Until 30
			For triangle = EachIn le_list
				triangle.Update()
			Next
		Next
		Return
	EndIf

	Local halfDistance:Int = 55
	If kind = 1 Then halfDistance = 90
	If kind = 3 Then halfDistance = 50
	first = le.Create(centerX-halfDistance, centerY, 0, 1)
	second = le.Create(centerX+halfDistance, centerY, 0, 1)
	first.x = centerX-halfDistance
	first.y = centerY
	first.dx = 0
	first.dy = 0
	first.r = 0
	second.x = centerX+halfDistance
	second.y = centerY
	second.dx = 0
	second.dy = 0
	second.r = 0
	first.attached = True
	first.le2 = second
	first.strength = 25
	first.resist = False
	second.attached = True
	second.le2 = first
	second.strength = 25
	second.resist = False

	Select kind
		Case 1
			For Local frame:Int = 0 Until 30
				For triangle = EachIn le_list
					triangle.Update()
				Next
			Next
		Case 2
			first.Kill(True,-50,0)
		Case 3
			second.strength = 0.25
			nme5.Create(first.x, first.y, 20, 0, 1)
			For Local blackHole:nme5 = EachIn nme5_list
				blackHole.x = first.x
				blackHole.y = first.y
				blackHole.dx = 0
				blackHole.dy = 0
				blackHole.r = 45
				blackHole.sz = 20
				blackHole.active = False
				Exit
			Next
			For triangle = EachIn le_list
				triangle.Update()
			Next
	End Select
End Function

Function CaptureOriginalInterceptor(kind:Int)
	px = SCREENW/2
	py = 100
	Local centerX:Int = SCREENW/2
	Local centerY:Int = SCREENH/2
	nme7.Create(centerX, centerY, 0, 1)
	Local interceptor:nme7
	For interceptor = EachIn nme7_list
		Exit
	Next

	Select kind
		Case 0
			For Local frame:Int = 0 Until 30
				For interceptor = EachIn nme7_list
					interceptor.Update()
				Next
			Next
		Case 1, 2
			interceptor.dx = 4
			interceptor.dy = 0
			interceptor.r = 180
			interceptor.rot = 0
			interceptor.rotdir = 0
			interceptor.Draw()
			If kind = 2
				shot.Create(centerX+30, centerY, 10, 0, 10)
				For Local projectile:shot = EachIn shot_list
					projectile.Update()
				Next
			EndIf
	End Select
End Function

Function CaptureOriginalSnake(kind:Int)
	px = SCREENW/2
	py = 100
	Local centerX:Int = SCREENW/2
	Local centerY:Int = SCREENH/2
	Local head:nme6 = nme6.Create(centerX, centerY, 24, 0, 0, 0, 0, 1)
	Local segment:nme6

	Select kind
		Case 0
			For Local frame:Int = 0 Until 30
				For segment = EachIn nme6_list
					segment.Update()
				Next
			Next
		Case 1
			LayoutOriginalSnake(head)
			segment = head
			For Local tailIndex:Int = 0 Until 8
				segment = segment.tail
			Next
			segment.Kill()
		Case 2
			LayoutOriginalSnake(head)
			head.Kill()
			For Local frame:Int = 0 Until 8
				For segment = EachIn nme6_list
					segment.Update()
				Next
			Next
	End Select
End Function

Function LayoutOriginalSnake(head:nme6)
	Local centerX:Int = SCREENW/2
	Local centerY:Int = SCREENH/2
	Local segment:nme6 = head
	Local segmentIndex:Int = 0
	While segment <> Null
		segment.x = centerX - segmentIndex*13
		segment.y = centerY + Sin(segmentIndex*20)*22
		segment = segment.tail
		segmentIndex :+ 1
	Wend
End Function

Function CaptureOriginalBlackHole(kind:Int)
	px = SCREENW/2
	py = 100
	Local centerX:Int = SCREENW/2
	Local centerY:Int = SCREENH/2
	Local blackHole:nme5

	Select kind
		Case 0
			nme5.Create(centerX-18, centerY, 36, 0, 1)
			nme5.Create(centerX+18, centerY, 28, 0, 1)
			For blackHole = EachIn nme5_list
				blackHole.active = True
			Next
			For Local frame:Int = 0 Until 30
				For blackHole = EachIn nme5_list
					blackHole.Update()
					If frame < 29 Then blackHole.pulse:+blackHole.sz/2
				Next
			Next
		Case 1
			nme5.Create(centerX, centerY, 4.5, 0, 1)
			For blackHole = EachIn nme5_list
				blackHole.active = True
				blackHole.absorbcount = 5
				blackHole.Kill()
				Exit
			Next
		Case 2
			nme5.Create(centerX, centerY, 64.5, 0, 1)
			For blackHole = EachIn nme5_list
				blackHole.active = True
				blackHole.Grow(1)
				Exit
			Next
	End Select
End Function

Function CaptureOriginalEnemyMotion(kind:Int)
	px = SCREENW/2
	py = 100
	Local centerX:Int = SCREENW/2
	Local centerY:Int = SCREENH/2
	Select kind
		Case 0
			nme1.Create(centerX-9, centerY, 0, 1)
			nme1.Create(centerX+9, centerY, 0, 1)
		Case 1
			nme2.Create(centerX-9, centerY, 0, 1)
			nme2.Create(centerX+9, centerY, 0, 1)
		Case 2
			nme.Create(centerX-9, centerY, 0, 1)
			nme.Create(centerX+9, centerY, 0, 1)
		Case 3
			nme3.Create(centerX-9, centerY, 0, 0, 1)
			nme3.Create(centerX+9, centerY, 0, 0, 1)
		Case 4
			nme4.Create(centerX-9, centerY, 0, 0, 1)
			nme4.Create(centerX+9, centerY, 0, 0, 1)
		Case 9
			nme8.Create(centerX-9, centerY, 0, 1)
			nme8.Create(centerX+9, centerY, 0, 1)
	End Select

	For Local frame:Int = 0 Until 30
		Select kind
			Case 0
				For Local pinwheel:nme1 = EachIn nme1_list
					pinwheel.Update()
				Next
			Case 1
				For Local diamond:nme2 = EachIn nme2_list
					diamond.Update()
				Next
			Case 2
				For Local square:nme = EachIn nme_list
					square.Update()
				Next
			Case 3
				For Local cube:nme3 = EachIn nme3_list
					cube.Update()
				Next
			Case 4
				For Local seeker:nme4 = EachIn nme4_list
					seeker.Update()
				Next
			Case 9
				For Local butterfly:nme8 = EachIn nme8_list
					butterfly.Update()
				Next
		End Select
	Next
End Function

Function CaptureOriginalPresentationCatalog:Int(mode$, directory$)
	Select mode
		Case "get-ready-title", "get-ready-rings"
			PrepareOriginalCaptureState()
			dying = True
			GetReady()
			Return True
		Case "death"
			PrepareOriginalCaptureState()
			KillPlayer()
			Return True
		Case "game-over"
			PrepareOriginalCaptureState()
			dying = True
			DoGameOver()
			Return True
		Case "high-score-entry"
			PrepareOriginalCaptureState()
			pscore = 123456
			gcount = 10050
			laststartingdifficulty = 1
			score.GetHighScore()
			Return True
		Case "options-game"
			PrepareOriginalMenuBackground()
			Options(True)
			Return True
		Case "confirm-exit"
			conf(False, "Sure?")
			Return True
		Case "confirm-end-game"
			PrepareOriginalMenuBackground()
			conf(True, "End Game?")
			Return True
		Case "confirm-keep-video", "confirm-keep-game"
			conf(False, "Keep Changes?")
			Return True
		Case "settings"
			Settings(False)
			Return True
		Case "video"
			VideoSettings(False)
			Return True
		Case "game"
			GameSettings(False)
			Return True
		Case "audio"
			AudioSettings(False)
			Return True
		Case "controller"
			ControllerSettings(False)
			Return True
		Case "hybrid"
			HybridControllerSettings(False)
			Return True
		Case "mouse"
			MouseControllerSettings(False)
			Return True
		Case "keyboard"
			KeyboardControllerSettings(False)
			Return True
		Case "joypad"
			JoypadControllerSettings(False)
			Return True
		Case "dual-analog"
			DualAnalogControllerSettings()
			Return True
	End Select
	Return False
End Function

Function PrepareOriginalCaptureState()
	SeedRnd(1)
	RemoveAll(True)
	StopLoopingSounds()
	ResetGame()
	CenterPlayer()
	CreateStars()
	messtime = 0
	bombtime = 0
	dying = False
	player_shield = 0
	showstars = 300
	g_style = 0
	particlestyle = 0
	gridpoint.ResetAll()
	part.CreateAll()
End Function

Function PrepareOriginalMenuBackground()
	PrepareOriginalCaptureState()
	CaptureOriginalOverview()
	Cls
	DrawAll()
	Flip 1
	CaptureScreen()
End Function

Function CaptureOriginalOverview()
	nme1.Create(180, 588, 0)
	nme2.Create(330, 208, 0)
	nme.Create(790, 198, 0)
	nme4.Create(840, 538, 0)
	le.Create(650, 588, 0)
	pu.Create(360, 508, 6, 0)
End Function

Function CaptureOriginalEnemy(kind:Int)
	px = SCREENW/2
	py = 100
	Local centerX:Int = SCREENW/2
	Local centerY:Int = SCREENH/2
	Select kind
		Case 0; nme1.Create(centerX, centerY, 0, 1)
		Case 1; nme2.Create(centerX, centerY, 0, 1)
		Case 2; nme.Create(centerX, centerY, 0, 1)
		Case 3; nme3.Create(centerX, centerY, 0, 0, 1)
		Case 4; nme4.Create(centerX, centerY, 0, 0, 1)
		Case 5
			nme5.Create(centerX, centerY, 36, 0, 1)
			For Local blackHole:nme5 = EachIn nme5_list
				blackHole.active = True
			Next
		Case 6
			Local first:le = le.Create(centerX-55, centerY, 0, 1)
			Local second:le = le.Create(centerX+55, centerY, 0, 1)
			first.attached = True
			first.le2 = second
			first.strength = 25
			second.attached = True
			second.le2 = first
			second.strength = 25
		Case 7
			Local head:nme6 = nme6.Create(centerX, centerY, 24, 0, 0, 0, 0, 1)
			Local segment:nme6 = head
			Local segmentIndex:Int = 0
			While segment <> Null
				segment.x = centerX - segmentIndex*13
				segment.y = centerY + Sin(segmentIndex*20)*22
				segment = segment.tail
				segmentIndex :+ 1
			Wend
		Case 8; nme7.Create(centerX, centerY, 0, 1)
		Case 9; nme8.Create(centerX, centerY, 0, 1)
	End Select
End Function
