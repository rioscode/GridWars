' Deterministic visual-reference entry points for the isolated original build.
' This file is copied beside gridwars.bmx only by capture-original.sh.

Function CaptureOriginalCatalog:Int(mode$, directory$)
	Local entityKind:Int = -1
	Local generatorKind:Int = -1
	Local powerKind:Int = -1
	Local gridKind:Int = -1
	Local particleKind:Int = -1
	Local graphicsKind:Int = -1
	Local overview:Int = False
	Local upgradedHUD:Int = False

	Select mode
		Case "gameplay"; overview = True
		Case "hud-default"; overview = 2
		Case "hud-upgraded"; overview = 2; upgradedHUD = True

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
