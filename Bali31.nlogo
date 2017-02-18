patches-own [r1]
breed [subaks]
breed [dams]
breed [damdam]
breed [damsubaks damsubak]
breed [subakdams subakdam]
breed [subaksubaks subaksubak]

subaks-own [old? mip stillgrowing dpests pestneighbors damneighbors totharvestarea area
SCC ;Subak's crop plan
sd ; start date (month)
SCCc; help variable during imitation process
sdc ;help variable during imitation process
 pests
 nMS ; counter for number of subaks in masceti
  MS ; masceti
  dmd masceti ulunswi pyharvest pyharvestha WSS harvest crop ricestage Ymax pest-damage pestloss totLoss source return]
dams-own [flow0 flow elevation
WSarea ; WSarea is area (ha) of dams' watershed
damht rain
EWS ; Effective Watershed Area
areadam Runoff d1 d3 XS
WSD ; Water Stress Dam
totWSD]

damdam-own [a b distanceab]
damsubaks-own [a b distanceab]
subakdams-own [a b distanceab]
subaksubaks-own [a b distanceab]

globals [ subak-data dam-data subaksubak-data subakdam-data new-subaks subaks_array dams_array subakdams_array damsubaks_array Rel Rem Reh month ET RRT LRS Xf devtime yldmax pestsens growthrate cropuse totpestloss totpestlossarea totWS totWSarea avgharvestha]

to setup
  ;; (for this model to work with NetLogo's new plotting features,
  ;; __clear-all-and-reset-ticks should be replaced with clear-all at
  ;; the beginning of your setup procedure and reset-ticks at the end
  ;; of the procedure.)
  __clear-all-and-reset-ticks
  set-default-shape subaks "circle"
  set-default-shape dams "square"
  set-default-shape damdam "line"
  set-default-shape damsubaks "line"
  set-default-shape subakdams "line"
  set-default-shape subaksubaks "line"
  set subaks_array [ ]
  set dams_array []
  set subakdams_array []
  set damsubaks_array []
  set devtime [0 6 4 3] ; development time for crops
  set yldmax [0 5 5 10] ; maximum yld of rice crops
  set pestsens [0 0.5 0.75 1.0] ; sensitivity of crops to pests
  set growthrate [0.1 2.2 2.2 2.2 0.33] ; monthly growth rate parameter
  set cropuse [0 0.015 0.015 0.015 0.003]	; use of water per crop parameter
  set growthrate replace-item 1 growthrate pestgrowth-rate
  set growthrate replace-item 2 growthrate pestgrowth-rate
  set growthrate replace-item 3 growthrate pestgrowth-rate
  set month 0
  set totpestloss 0
  set totpestlossarea 0
  set totWS 0
  set totWSarea 0
  set avgharvestha 0
  set ET 50 / 30000  ;between 40 and 60 Evapotranspiration rate, mm/mon => m/d
  set RRT ET + 50 / 30000 ;between 0 and 100 Rain-Runoff threshold for 1:1, mm/mon => m/d
  set LRS 1 - ET / RRT  ;LowRainSlope, below threshold for RR relation
  set Xf 1.0 ;between 0.8 and 1.2 X factor for changing minimum groundwater flow

  load-data

  ask subaks [set old? false]
  set dams_array sort-by [[who] of ?1 < [who] of ?2] dams
  set subaks_array sort-by [[who] of ?1 < [who] of ?2] subaks

  ask dams [set areadam 0]
  ask subaks [
    let returndam self
 	  let sourcedam self
 	  let subak self
 	  set stillgrowing false
    set returndam [b] of one-of subakdams with [a = subak]
    set sourcedam [a] of one-of damsubaks with [b = subak]
    let areasubak area
    ifelse (returndam = sourcedam) [
      ask returndam [set areadam areadam + areasubak]
    ][
      ask sourcedam [set areadam areadam + areasubak]
    ]
    set pyharvest 0
    set pyharvestha 0
    ; initial cropping plans are randomly allocated
    set SCC random nrcropplans
    set sd random 12
    cropplan SCC sd
    set totharvestarea 0
    if Color_subaks = "cropping plans" [set color SCC * 10 + 5]; + sd]
  ]

  ask dams [set flow0 flow0 * Xf * 86400]
  ask dams [set EWS WSarea - areadam]
; Effective Watershed Area EWS of each dam is reduced by cultiv'n area areadam because rain onto sawa enters the irrig'n system meeting immediate demand directly or passing on to the downstream irrigation point

  ask subaks [
    let sdhelp 0
    set SCC random nrcropplans
    set sd random 12
    set pests 0.01
    set old? false
    cropplan SCC sd
    ricestageplan SCC sd
    let subak1 self
    ask subaks [
      if [source] of self = [source] of subak1 [ask subak1 [set damneighbors lput myself damneighbors]]
    ]
  ]
end

to go
  let gr2 0
  let gr3 0
  set gr2 pestgrowth-rate
  set gr3 pestgrowth-rate
  ask subaks [set mip sd + month if mip > 11 [set mip mip - 12]]
  ask subaks [
    cropplan SCC mip
    if stillgrowing [if ((crop = 0) or (crop = 4)) [set stillgrowing false]]
 ]

  demandwater
  determineflow
  growrice
  growpest
  determineharvest

  if month = 11 [set totpestloss totpestloss / totpestlossarea set totWS totWS / totWSarea]
  if month = 11 [plot-figs]
  if month = 11 [imitatebestneighbors]

  ifelse month = 11
  [set month 0 set totWSarea 0 set totWS 0 ask subaks [set pyharvest 0 set pyharvestha 0 set totpestloss 0 set totpestlossarea 0 set totharvestarea 0 set pests 0.01]]
  [set month month + 1]
  tick
end

to demandwater
  ; determine the water demand for different subaks
    ask dams [
    if rainfall-scenario = "low" [rainfall damht 0]
    if rainfall-scenario = "middle" [rainfall damht 1]
    if rainfall-scenario = "high" [rainfall damht 2]
    set rain rain / 30000
    ifelse rain < RRT [
  	  set Runoff rain * LRS * EWS * 10000 	; 'm/d * ha* m2/ha => m3/d for basin
     ][
      set Runoff (rain - ET) * EWS * 10000
      if (Runoff < 0) [set Runoff 0]
   ]]
;       		Demand for each Subak based on cropping pattern, less any rainfall.
;        		dmd may be + or - because local rain can exceed demand ==> an excess.

  ask subaks [
;    		cropuse is m/d demand for the 4 crops:
    if Color_subaks = "crops" [
      if crop = 0 [ set color green]
      if crop = 1 [ set color cyan]
      if crop = 2 [ set color yellow]
      if crop = 3 [ set color white]
      if crop = 4 [ set color red]
      ]
    set dmd item crop cropuse - [rain] of return
    set dmd dmd * area * 10000
  ]
;			Sum the partial demands for areas 1, 2, & 3 of each dam
  ask dams [set d1 0  set d3 0  set XS 0 ]

;   			In each case, put dmd<0 into excess (XS)
;    			Total dmd for all Subaks inside basin taking flow before the dam

  ask subaks [
    let returndam self
    let sourcedam self
    let subak self
    set returndam [b] of one-of subakdams with [a = subak]
    set sourcedam [a] of one-of damsubaks with [b = subak]
    ifelse (returndam = sourcedam)
    [
      let dmdsubak dmd
      ifelse dmd > 0 [
        ask returndam [set d1 d1 + dmdsubak]
      ][
        ask returndam [set XS XS - dmdsubak]]]
;  			Any excess of rain>dmd for Subaks in basin but source outside
;				Excess always returned to this dam, i.e. location = the downstream dam
      [
        let dmdsubak dmd
        if dmd < 0 [ask returndam [set XS XS - dmdsubak]]
;	  		Downstream irrig'n dmd drawn from this dam; >0 only, no excess allowed
        if dmd > 0 [ask sourcedam [set d3 d3 + dmdsubak]]]]
end

to determineflow
  let bool 0
  ask dams [
    if bool = 0 [
      set bool 1 ; dirty trick to make sure upstream subaks are updated first
      foreach dams_array [
        let dam1 self
        set flow flow0 + Runoff - d1 + XS - d3
        foreach dams_array [
          let flowadd flow
          if (count damdam with [a = self and b = dam1] + count damdam with [a = dam1 and b = self]) > 0
          [
				    ask dam1 [set flow flow + flowadd]
			    ]
        ]
				ifelse flow < 0 [
					ifelse ((d1 + d3) = 0) [][
						set WSD 1 + flow / (d1 + d3)
						set d1 d1 * WSD
						set d3 d3 * WSD
						set flow 0 ; waterstress
			  ]] [set WSD 1]
				set totWSD totWSD + WSD
	]]]
  ask subaks [
    let subak1 self
    set WSS [WSD] of [a] of one-of damsubaks with [b = subak1]
    set dmd dmd * WSS]
end

to growrice
    ask subaks [
      let subak1 self
      let WSDhelp self
      if crop = 0 [set ricestage 0 set WSS 1] ;Fallow period
      if crop = 4 [set ricestage 0 set WSS 1] ; Growing paliwiga
      if ((crop = 1) or (crop = 2) or (crop = 3)) [
        set WSS [WSD] of source
        set ricestage ricestage + (WSS / (item crop devtime))
 ]]
end

to growpest
  let dxx 100
  let dt 30 ;days
  let dc 0
  let cs 0
  let cN 0
  let minimumpests 0.01
  ask subaks [
    let subak1 self
		set cs 4 * pests
		ask subaks [
		    let subak2 self
        ifelse member? subak1 pestneighbors [set cN pests - [pests] of subak1][set cN 0]
        set cs cs + cN]
    set dc (pestdispersal-rate / dxx) * ( cs - (4 * pests)) * dt ; this is the net change in pest dispersed to or from the subak
		set dpests ((item crop growthrate) * (pests + 0.5 * dc)) + (0.5 * dc)
		if dpests < minimumpests [set dpests minimumpests]]

    ask subaks [set pests dpests if Color_subaks = "pests" [set color 62 + pests ]]
end

to determineharvest
    let hy 0
    let croph 0
    let cropf 0
    ask subaks [
      set harvest 0
      if ((crop = 1) or (crop = 2) or (crop = 3)) [set stillgrowing true]
        set croph crop
        cropplan SCC (mip + 1)
        set cropf crop
        set crop croph
        if (cropf = 0) or (cropf = 4)
        [
          set Ymax ricestage * (item crop yldmax)
					set pest-damage 1 - pests * (item crop pestsens)
					if pest-damage < 0 [set pest-damage 0]
          set harvest Ymax * pest-damage
					set pestloss pestloss + Ymax * (1 - pest-damage) * area
					set totLoss totLoss + pestloss
					set hy hy + harvest * area
					set pyharvest pyharvest + harvest * area
					set pyharvestha pyharvestha + harvest
					set totpestloss totpestloss + area * (1 - pest-damage) * Ymax
          set totpestlossarea totpestlossarea + area
          set totWS totWS + (1 - ricestage) * area
          set totWSarea totWSarea + area
          set totharvestarea totharvestarea + area
				]]
end

to imitatebestneighbors
  let minharvest 0
  let maxharvest 0
    ask subaks [
      let bestneighbor self
      set minharvest pyharvestha
      set maxharvest minharvest
      set SCCc SCC
      set sdc sd
      foreach pestneighbors [
        ask ? [
          if pyharvestha > maxharvest
          [
            set maxharvest pyharvestha
            set bestneighbor self
      ]]
      if maxharvest > minharvest [set SCCc [SCC] of bestneighbor set sdc [sd] of bestneighbor]]
    ]

  ask subaks [
    set SCC SCCc
    set sd sdc
    if Color_subaks = "cropping plans" [
      set color SCC * 10 + 5]]
end

to setup-plot
  set-current-plot "Harvest"
  set-plot-y-range 0 30
  set-current-plot "Pestloss"
  set-plot-y-range 0 1
  set-current-plot "Waterstress"
  set-plot-y-range 0 1
end

to plot-figs
  let totarea 0
  let totharvest 0
  set-current-plot "Harvest"
  ask subaks [
    set totarea totarea + totharvestarea
    set totharvest totharvest + pyharvest
  ]
  set-current-plot-pen "harvest"
  set avgharvestha totharvest / totarea
  plot avgharvestha

  set-current-plot "Pestloss"
  plot totpestloss

  set-current-plot "Waterstress"
  plot totWS
end

;========================= data ========================================
to load-data
  ifelse ( file-exists? "subakdata.txt" )
  [
    ;; We are saving the data into a list, so it only needs to be loaded once.
    set subak-data []
    file-open "subakdata.txt"
    while [ not file-at-end? ]
    [
      ;; file-read gives you variables.
      ;; We store them in a double list (ex [[1 2 3 4 5 6] [1 2 3 4 5 6] ...
      set subak-data sentence subak-data (list (list file-read file-read file-read file-read file-read file-read))
    ]
    file-close
  ]
  [ user-message "There is no subakdata.txt file in current directory!" ]

  ifelse ( file-exists? "damdata.txt" )
  [
    set dam-data []
    file-open "damdata.txt"
    while [ not file-at-end? ]
    [set dam-data sentence dam-data (list (list file-read file-read file-read file-read file-read file-read file-read))]
    file-close
  ]
  [ user-message "There is no damdata.txt file in current directory!" ]

  ifelse ( file-exists? "subaksubakdata.txt" )
  [
    set subaksubak-data []
    file-open "subaksubakdata.txt"
    while [ not file-at-end? ]
    [set subaksubak-data sentence subaksubak-data (list (list file-read file-read))]
    file-close
  ]
  [ user-message "There is no subaksubakdata.txt file in current directory!" ]

  ifelse ( file-exists? "subakdamdata.txt" )
  [
    set subakdam-data []
    file-open "subakdamdata.txt"
    while [ not file-at-end? ]
    [ set subakdam-data sentence subakdam-data (list (list file-read file-read file-read))]
    file-close
  ]
  [ user-message "There is no subakdamdata.txt file in current directory!" ]

  foreach subak-data [
  create-subaks 1 [set color white setxy (item 1 ?) (item 2 ?) set area item 3 ? set masceti item 4 ? set ulunswi item 5 ?
  set pestneighbors [] set damneighbors []
  set subaks_array lput self subaks_array
    if Color_subaks = "Temple groups" [
        if masceti = 1 [set color white]
        if masceti = 2 [set color yellow]
        if masceti = 3 [set color red]
        if masceti = 4 [set color blue]
        if masceti = 5 [set color cyan]
        if masceti = 6 [set color pink]
        if masceti = 7 [set color orange]
        if masceti = 8 [set color lime]
        if masceti = 9 [set color sky]
        if masceti = 10 [set color violet]
        if masceti = 11 [set color magenta]
        if masceti = 12 [set color green]
        if masceti = 13 [set color turquoise]
        if masceti = 14 [set color brown]
     ]]]

  foreach dam-data [
  create-dams 1 [ set color yellow setxy (item 1 ?) (item 2 ?) set flow0 item 3 ? set elevation item 4 ? set WSarea item 5 ? set damht item 6 ?
  set dams_array lput self dams_array]]

  linkdams
  foreach subaksubak-data [make-subaksubak (item first ? subaks_array) (item last ? subaks_array)]
  foreach subakdam-data [make-subakdams (item first ? subaks_array) (item (item 1 ?) dams_array) (item last ? dams_array)]

end

to cropplan [nr m]
  if m > 11 [set m m - 12]
  ; for each month a crop is defined
	let cropplan0 [3 3 3 0 3 3 3 0 3 3 3 0]
	let cropplan1 [3 3 3 0 0 0 3 3 3 0 0 0]
	let cropplan2 [3 3 3 0 3 3 3 0 0 0 0 0]
	let cropplan3 [3 3 3 0 0 3 3 3 0 0 0 0]
	let cropplan4 [3 3 3 0 0 0 0 3 3 3 0 0]
	let cropplan5 [3 3 3 0 0 0 0 0 3 3 3 0]
	let cropplan6 [1 1 1 1 1 1 0 2 2 2 2 0]
	let cropplan7 [1 1 1 1 1 1 0 3 3 3 0 0]
	let cropplan8 [1 1 1 1 1 1 0 0 3 3 3 0]
	let cropplan9 [1 1 1 1 1 1 0 0 0 0 0 0]
	let cropplan10 [2 2 2 2 0 0 2 2 2 2 0 0]
	let cropplan11 [2 2 2 2 0 2 2 2 2 0 0 0]
	let cropplan12 [2 2 2 2 0 0 0 2 2 2 2 0]
	let cropplan13 [2 2 2 2 0 0 3 3 3 0 0 0]
	let cropplan14 [2 2 2 2 0 3 3 3 0 0 0 0]
	let cropplan15 [2 2 2 2 0 0 0 3 3 3 0 0]
	let cropplan16 [2 2 2 2 0 0 0 0 3 3 3 0]
	let cropplan17 [3 3 3 0 0 2 2 2 2 0 0 0]
	let cropplan18 [3 3 3 0 0 0 2 2 2 2 0 0]
	let cropplan19 [3 3 3 0 2 2 2 2 0 0 0 0]
	let cropplan20 [3 3 3 0 0 0 0 2 2 2 2 0]

  if nr = 0 [set crop item m cropplan0]
  if nr = 1 [set crop item m cropplan1]
  if nr = 2 [set crop item m cropplan2]
  if nr = 3 [set crop item m cropplan3]
  if nr = 4 [set crop item m cropplan4]
  if nr = 5 [set crop item m cropplan5]
  if nr = 6 [set crop item m cropplan6]
  if nr = 7 [set crop item m cropplan7]
  if nr = 8 [set crop item m cropplan8]
  if nr = 9 [set crop item m cropplan9]
  if nr = 10 [set crop item m cropplan10]
  if nr = 11 [set crop item m cropplan11]
  if nr = 12 [set crop item m cropplan12]
  if nr = 13 [set crop item m cropplan13]
  if nr = 14 [set crop item m cropplan14]
  if nr = 15 [set crop item m cropplan15]
  if nr = 16 [set crop item m cropplan16]
  if nr = 17 [set crop item m cropplan17]
  if nr = 18 [set crop item m cropplan18]
  if nr = 19 [set crop item m cropplan19]
  if nr = 20 [set crop item m cropplan20]
end

to ricestageplan [nr m]
	let ricestageplan0 [0 0.33 0.67 0 0 0.33 0.67 0 0 0.33 0.67 0]
	let ricestageplan1 [0 0.33 0.67 0 0 0 0 0.33 0.67 0 0 0]
	let ricestageplan2 [0 0.33 0.67 0 0 0.33 0.67 0 0 0 0 0]
	let ricestageplan3 [0 0.33 0.67 0 0 0 0.33 0.67 0 0 0 0]
	let ricestageplan4 [0 0.33 0.67 0 0 0 0 0 0.33 0.67 0 0]
	let ricestageplan5 [0 0.33 0.67 0 0 0 0 0 0 0.33 0.67 0]
	let ricestageplan6 [0 0.16 0.33 0.5 0.67 0.84 0 0 0.25 0.5 0.75 0]
	let ricestageplan7 [0 0.16 0.33 0.5 0.67 0.84 0 0 0.33 0.67 0 0]
	let ricestageplan8 [0 0.16 0.33 0.5 0.67 0.84 0 0 0 0.33 0.67 0]
	let ricestageplan9 [0 0.16 0.33 0.5 0.67 0.84 0 0 0 0 0 0]
	let ricestageplan10 [0 0.25 0.5 0.75 0 0 0 0.25 0.5 0.75 0 0]
	let ricestageplan11 [0 0.25 0.5 0.75 0 0 0.25 0.5 0.75 0 0 0]
	let ricestageplan12 [0 0.25 0.5 0.75 0 0 0 0 0.25 0.5 0.75 0]
	let ricestageplan13 [0 0.25 0.5 0.75 0 0 0 0.33 0.67 0 0 0]
	let ricestageplan14 [0 0.25 0.5 0.75 0 0 0.33 0.67 0 0 0 0]
	let ricestageplan15 [0 0.25 0.5 0.75 0 0 0 0 0.33 0.67 0 0]
	let ricestageplan16 [0 0.25 0.5 0.75 0 0 0 0 0 0.33 0.67 0]
	let ricestageplan17 [0 0.33 0.67 0 0 0 0.25 0.5 0.75 0 0 0]
	let ricestageplan18 [0 0.33 0.67 0 0 0 0 0.25 0.5 0.75 0 0]
	let ricestageplan19 [0 0.33 0.67 0 0 0.25 0.5 0.75 0 0 0 0]
	let ricestageplan20 [0 0.33 0.67 0 0 0 0 0 0.25 0.5 0.75 0]

  if nr = 0 [set ricestage item m ricestageplan0]
  if nr = 1 [set ricestage item m ricestageplan1]
  if nr = 2 [set ricestage item m ricestageplan2]
  if nr = 3 [set ricestage item m ricestageplan3]
  if nr = 4 [set ricestage item m ricestageplan4]
  if nr = 5 [set ricestage item m ricestageplan5]
  if nr = 6 [set ricestage item m ricestageplan6]
  if nr = 7 [set ricestage item m ricestageplan7]
  if nr = 8 [set ricestage item m ricestageplan8]
  if nr = 9 [set ricestage item m ricestageplan9]
  if nr = 10 [set ricestage item m ricestageplan10]
  if nr = 11 [set ricestage item m ricestageplan11]
  if nr = 12 [set ricestage item m ricestageplan12]
  if nr = 13 [set ricestage item m ricestageplan13]
  if nr = 14 [set ricestage item m ricestageplan14]
  if nr = 15 [set ricestage item m ricestageplan15]
  if nr = 16 [set ricestage item m ricestageplan16]
  if nr = 17 [set ricestage item m ricestageplan17]
  if nr = 18 [set ricestage item m ricestageplan18]
  if nr = 19 [set ricestage item m ricestageplan19]
  if nr = 20 [set ricestage item m ricestageplan20]
end

to linkdams
  make-damdam (item 0 dams_array) (item 5 dams_array)
  make-damdam (item 5 dams_array) (item 6 dams_array)
  make-damdam (item 6 dams_array) (item 8 dams_array)
  make-damdam (item 1 dams_array) (item 7 dams_array)
  make-damdam (item 7 dams_array) (item 8 dams_array)
  make-damdam (item 2 dams_array) (item 9 dams_array)
  make-damdam (item 3 dams_array) (item 9 dams_array)
  make-damdam (item 4 dams_array) (item 9 dams_array)
  make-damdam (item 9 dams_array) (item 10 dams_array)
  make-damdam (item 10 dams_array) (item 11 dams_array)
end

to rainfall [hight level]
; rainfall scenarios for different latitudes
  if (hight = 0) [
    set Rel [114 118 100   8  21   0   0  2   1   0  28 114]
    set Rem [252 269 167  67  96  96 110 48  64 101 150 271]
    set Reh [390 420 234 126 171 192 220 94 127 202 272 428]
  levelrainfall level]

  if hight = 1 [
    set Rel [200 167 131  63  42  62   0   0   0  26  92 156]
    set Rem [364 278 230 135 131 153 160  84 109 194 220 298]
    set Reh [528 389 329 207 220 244 320 168 218 362 348 440]
  levelrainfall level]

  if hight = 2 [
    set Rel [215 227 205 100 121  51   6   4  67  45 138 243]
    set Rem [282 274 319 181 206 141  95 138 249 265 267 327]
    set Reh [349 321 433 262 291 231 184 272 431 485 396 411]
  levelrainfall level]

  if hight = 3 [
    set Rel [148 210 120  53  53  54   8  13   0  45 112 192]
    set Rem [348 291 221 138 124 160 183 106 136 179 241 312]
    set Reh [548 372 322 223 195 266 358 199 272 313 370 432]
  levelrainfall level]

  if hight = 4 [
    set Rel [289 234 249 125  78  13   0   6  10  57 141 281]
    set Rem [418 384 372 246 208 128 114  68  77 162 268 405]
    set Reh [547 534 495 367 338 243 228 130 144 267 395 529]
  levelrainfall level]

end

to levelrainfall [level]
  if level = 0 [set rain item month Rel]
  if level = 1 [set rain item month Rem]
  if level = 2 [set rain item month Reh]
end

to make-damdam [dam1 dam2]
  create-damdam 1
  [
    set color blue
    set a dam1
    set b dam2
    reposition-edges
  ]
end

to make-subaksubak [s1 s2]
  create-subaksubaks 1
  [
    set color green
    set a s1
    set b s2
    reposition-edges
  ]
  ask s1 [set pestneighbors lput s2 pestneighbors]
end

to make-subakdams [s1 s2 s3]
  create-subakdams 1
  [
    set color blue
    set a s1
    set b s2
    reposition-edges
    if not viewdamsubaks [set size 0]
  ]
    create-damsubaks 1
  [
    set color blue
    set a s3
    set b s1
    reposition-edges
    if not viewdamsubaks [set size 0]
  ]
  ask s1 [set source s3 set return s2]
end

to reposition-edges  ;; edges procedure
  setxy ([xcor] of a) ([ycor] of a)
  set size distance b
  set distanceab distance b
  ;; watch out for special case where a and b are
  ;; at the same place
  if size != 0
  [
    ;; position edges at midpoint between a and b
    set heading towards b
    jump size / 2
  ]
end
