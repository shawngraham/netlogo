breed [ clocks ]
breed [ settlements settlement ]
breed [ travellers traveller]
breed [ halos halo]


globals 
   [
     clock ;; the current model time
     scale  ;; number of pixels / 20 km
     max-importance ;; the value of the most important settlement
     traveller-colors
   ]
  
patches-own
   [ 
     ptemp ;; temp variable for map image processing
     ctemp   
   ]

turtles-own
[ temp tx ty tp ]

halos-own
   [ 
     importance
   ]

travellers-own 
   [
     my-home ;; settlement where this traveller originated
     on-my-way ;; true when traveller is in transit to a destination
     destination ;; the current destination settlement
     vision ;; the maximum distance this traveller will go in one leg
     current-importance-of-home
     original-color
     last-place-i-visited
   ]

settlements-own
   [
     importance 
     visitors ;; list of travellers that have visited this settlement
     settlement-of-origin ;; list of origins of travellers who have visited here
     reflected-glory ;; a settlement's importance is in part a reflection of the places to which it is connected
   ]
  
;;;;;; set up routines
to setup
   ;; (for this model to work with NetLogo's new plotting features,
  ;; __clear-all-and-reset-ticks should be replaced with clear-all at
  ;; the beginning of your setup procedure and reset-ticks at the end
  ;; of the procedure.)
  __clear-all-and-reset-ticks
   random-seed 101174   ;; this enables 'reproducibility', allows you to explore the effect of changing the sliders.
                        ;; NB If you turn this off, the ids of your settlements will change with each model run.
                        ;; in which case, you'll have to compare your outputs against your master map each time
                        ;; so that you know what id refers to what settlements.
                        ;; This is because of a new implementation of Netlogo 3.1 (in earlier versions, this does not happen).
                        ;; A code snippet will have to be developed which either imports the names of your settlements and
                        ;; appends them to the appropriate place, or else assigns consistent id numbers with every run.
   set-default-shape halos       "ring"
   setup-map ;; import the map file
   setup-settlements ;; violet points on the map become settlements
   setup-clock
   setup-travellers
   set traveller-colors [ ]   
end

to setup-map
   ;; converts map using red splotches as settlements to using single violet points
   file-close-all
   ;; read selected map file
   let map-found? true
   carefully
   [ import-pcolors maps
   ]
   [ set map-found? false 
     ;user-message "The selected map--\"" + maps + "\"--was not found."
   ]
   if not map-found? [ stop ]

   ;;;because the maps are at different scales, have to adjust scale to take this into account.
   ;; map has 20KM scale indicator in red, 2 lines tall
   ;; so count of red patches / 2 is number of patches per 20 KM.
   set scale .5 * (count patches with [ shade-of? pcolor red ])
end   

to setup-settlements
   set-default-shape settlements "circle-lined"
   ask patches with [ pcolor = violet ]
   [ sprout 1
     [ set breed settlements
       set importance 1 ; we always start from an egalitarian position
       set visitors [] ;; local-list [ ]
       set settlement-of-origin [ ]
       set size 5
       set heading 0
       set reflected-glory [0 ]        
     ]
   ]

   ask settlements
     [
                  
      set color who - one-of [5 15 25 35 45 55 65 75 85 95 105 115 125 135] ;; to give each settlement a unique colour
      if color = white [set color color + 1]
      ask settlements in-radius 1 with [who < [who] of myself]  ; this can be deleted, but is helpful in 'cleaning up'
            [die]                                             ; very dense maps.
      ]
end

to setup-travellers
  set-default-shape travellers "square-lined"
  ask settlements
  [ 
    hatch number-of-travellers-per-site
    [ set breed travellers  ;;; each settlement 'hatches' the travellers for that settlement, and then sets their variables
      set size 1.1 ;; can make this bigger, if you want, 
      set on-my-way false
      set original-color color
      set vision (scale * average-journey-length) + random scale ;; making the distance variable around the daily average of 20 km
      set my-home myself 
      set current-importance-of-home [importance] of myself
      set last-place-i-visited [importance] of myself
    ]
  set color [color] of one-of travellers-here
   ]
end


to setup-clock
   set-default-shape clocks "clocks"
   create-clocks 1
   [ setxy (max-pxcor * .9) (max-pycor * .9)
     set size world-width * .05
     if size < 25 [ set size 25]
     set color black
     set heading 0
     set clock 0
   ]
   ask clocks
     [ ask settlements in-radius 5 [die] ;;kludge to kill any accidental 'settlements' on the clock-face
     ]
end

;;;;; runtime routines ;;;;
to go
  go-clock
  ask travellers
      [
        set-destination
      ]
  ask settlements 
  [check-home-situation
   calculate-my-importance 
   if auto-resize [resize-settlements]
   territories-plot
  ]
  if auto-clear? [cd] 
end    

to go-end-of-sequence
   ;;;;stopping routines;;;;
  ifelse identify-most-important-sites?
   [
     ask settlements
     [
       set importance importance + (length visitors * (sqrt (mean reflected-glory)) ) 
     ]
     set max-importance max [ importance ] of settlements
     ask settlements with [length visitors >= 1]
             [ show-my-importance ]     ;;; show visual representation  
   ] 
   [resize-settlements]  ;; can remove this, if you don't want settlements to resize automatically at the end of a run
end

to go-clock
   ask clocks
   [ set clock clock + 1
     rt 30
   ]
end   

;;;settlement procedures;;;;

to check-home-situation
   ask travellers with [my-home = [who] of myself]
     [set current-importance-of-home [importance] of myself]
end

to calculate-my-importance ;;; how many visits has this settlement attracted
                           ;; if no visitors this turn, then importance decays       
     ifelse length visitors > (.50 * max [length visitors] of settlements)
     [set importance importance + (length visitors * (sqrt (mean reflected-glory)) )
      set reflected-glory [0 ]
     ]
     [set importance importance + (length visitors * (sqrt (mean reflected-glory))) ; these settlements get their importance
      set importance (importance - (importance / 10)) ;; but they lose some because they didn't attract as much
      
      set reflected-glory [0 ]
       if importance < 10 
         [set importance 10]
      ]
end

;;;representations of settlement importance;;;;

;;;called by go-end-of-sequence
to show-my-importance
   ;;; comparing with every other settlement
   let low5/10 max-importance * 5 / 10
   let mid7/10 max-importance * 7 / 10
   let upp9/10 max-importance * 9 / 10
   let halo-size-base max-pxcor * .05
   let halo-size-unit max-pxcor * .15
   let halo-size-scale 1 / max-importance * halo-size-unit
   if not any? halos-here
   [ hatch 1
     [ set breed halos ]
   ]
   ask halos-here
   [  set size halo-size-base + halo-size-scale * importance
     ifelse importance < low5/10 [ set color gray   ] [
     ifelse importance < mid7/10 [ set color yellow ] [
     ifelse importance < upp9/10 [ set color green  ] [
                                  set color red    ]]]
   ]
   
end   
;;;;; called by button;;;;;

to show-my-importance-v3  ;; this is my third version of this routine. Pressing this button outputs information to the command centre window.
                          ;; this may be useful for you, or it might not. Note that 'most important' settlement will also be extracted in the
                          ;; 'also quite important' list.
  let more-important-than-me [ ]
  set more-important-than-me filter [[importance] of ? > [importance] of self] settlement-of-origin
  if length more-important-than-me = 0
    [print who];  "is most important, with connections to : " + settlement-of-origin]
  if length more-important-than-me < ( .10 * length settlement-of-origin)
    [print who; + " is also quite important, with connections to : " + settlement-of-origin
     print who] ;+ " has color " + color]  
;; if the following is turned on, it will also print out the colors for each settlement listed by the above routine.
;;  let templist [ ]
;;  let templist2 [ ]
;;  set templist fput self templist
;;  set templist2 fput color-of self traveller-colors 
;;  set traveller-colors sentence templist templist2 
end

;;;;;;;;;alternative representation of settlement importance
;;;;;;instead of go-end-of-sequence
;;;;;;this rescales size in proportion to importance throughout simulation

to-report biggest
report max [importance] of settlements
end

to resize-settlements
ask settlements
[ if size > 1 
  [
    set size (( 20 * importance) / biggest )
  ]  
]  
end

         
;;travellers procedures;;;

to set-destination
   if on-my-way = false  
   [ 
     let destination1 
          one-of (settlements in-radius-nowrap vision)
     let destination2 
          one-of (settlements in-radius-nowrap vision) with [self != destination1]
     let destination3
          one-of (settlements in-radius-nowrap vision) with [self != destination1 and self != destination2]
    if destination1 = nobody or destination2 = nobody or destination3 = nobody [stop]
 
     ifelse is-turtle? destination1 or is-turtle? destination2 or is-turtle? destination3
     [ let templist [ ]
       ;;; the equations here for 'score' are from Rihll and Wilson's 1991 paper. Other equations are possible.
       ;;; If you want a different equation (perhaps comparing each settlement against an overall global variable)
       ;;; you'd place it in this routine.
       
       let x1 [importance] of destination1 ;; ~ R + W's 'attractiveness of site j'
       let y1 distance-nowrap destination1
       let z1 0
       ask destination1 [set z1 length visitors ;; ~ R + W's 'k value for site j'  
                         if z1 = 0 [set z1 1]
                        ] 
         
       let score1 (( x1 ^ benefit-of-resources) * (e ^ (- (difficulty-of-communications * y1)))) 
                  / (z1 ^ benefit-of-resources) * (e ^ (- (difficulty-of-communications * y1)))
       
       set templist fput score1 templist
       
       let x2 [importance] of destination2 
       let y2 distance-nowrap destination2
       let z2 0
       ask destination2 [set z2 length visitors
                         if z2 = 0 [set z2 1]
                         ]
       let score2 ((x2 ^ benefit-of-resources) * (e ^ (- (difficulty-of-communications * y2)))) 
                        /  (z2 ^ benefit-of-resources) * (e ^ (- (difficulty-of-communications * y2)))

       set templist fput score2 templist

       let x3 [importance] of destination3 
       let y3 distance-nowrap destination3
       let z3 0
       ask destination3 [set z3 length visitors
                         if z3 = 0 [set z3 1]
                         ]
       let score3 (( x3 ^ benefit-of-resources) * (e ^ (- (difficulty-of-communications * y3)))) 
                        /  (z3 ^ benefit-of-resources) * (e ^ (- (difficulty-of-communications * y3)))

      set templist fput score3 templist
      
      ;; this goes through the templist looking for the highest value.   
      ifelse max templist = position 0 templist
        [set on-my-way true
         set destination destination3
         travel
        ]
        [ifelse max templist = position 1 templist
          [set on-my-way true
           set destination destination2
           travel
          ]
          [set on-my-way true
           set destination destination1
           travel
          ]
        ] 
      ]
      [print who; + " woops! died" ;;; necessary in case of bugs.
       die ]
   ]
end

to travel
   if on-my-way
   [ let dist distance-nowrap destination
     if dist > 0
     [ set heading towards-nowrap destination
           

     ]
     
     ifelse dist < vision
        [ pd jump dist ]
        [ pd jump vision]
        
     if now-at-destination
     [ 
       pu
     without-interruption
       [
       ifelse [importance] of destination > last-place-i-visited ;; influence modeled by the diffusion of different colors
         [ set color [color] of destination
         ]  
         [ask destination [set color [color] of myself]
          ]
       set last-place-i-visited 0
      ; ] 
       let x [my-home] of myself
       let y [current-importance-of-home] of myself
     ask destination
       [without-interruption
         [ set visitors remove-duplicates (fput myself visitors)
           
           set settlement-of-origin remove-duplicates (fput x settlement-of-origin)
           set reflected-glory fput y reflected-glory
           ask travellers-here 
             [set last-place-i-visited [importance] of myself]    
         ] 
       ]
       ]   
     set on-my-way false
    ]  
  ]
end

;;;;reporters;;;;

;;; this 'new-threshold' snippet might be useful if you want to compare each settlement against a global value of the system.
;;; in which case in the 'set-destination' procedure, you'd compare the local score against this 'new-threshold' value.

;;to-report new-threshold
;;  let x mean values-from travellers [importance-of destination] 
;;  let y mean values-from travellers [distance-no-wrap destination]
;;  let z mean values-from settlements [length visitors]
;;;  let temp-i-to-d ((x ^ benefit-of-resources) / (e ^ (-(y) * difficulty-of-communications)))
;;  let temp-i-to-d (z * (x ^ benefit-of-resources) / ( e ^ (- (difficulty-of-communications) * y)))
;;
;;  report temp-i-to-d
;;end 

to-report now-at-destination
  report ( any? turtles-here with [ self = [destination] of myself ] )
end

to-report starting-position
report (abs (pcolor - red) < 5) or  (abs (pcolor - orange) < 5) ;or  (abs (pcolor - pink) < 5)
end     

;;another potentially useful snippett
;;;to-report most-important-settlement
;;;let mis  0
;;;ask settlements with [importance = max values-from settlements [importance]][set mis who]
;;;report mis
;;;end

;;;;;map conversion;;;;;

to convert-map
   ;; converts map using red splotches as settlements to using single violet points
   file-close-all
   ;; read selected map file
   let map-found? true
   carefully
   [ import-pcolors maps
   ]
   [ set map-found? false 
     ;user-message "The selected map--\"" + maps + "\"--was not found."
   ]
   if not map-found? [ stop ]
   
   ;;
   ;; define borders of map
   ;;
   let border-width 2
   ask patches with [max-pxcor - abs pxcor < border-width or max-pycor - abs pycor < border-width ]
     [ set pcolor black ]
 
  ask patches 
  [    
    if shade-of? pcolor magenta [ set pcolor pcolor - magenta + red ]
    if shade-of? pcolor violet [ set pcolor pcolor - violet + red ]
    if shade-of? pcolor pink [ set pcolor pcolor - pink + red ]
    if shade-of? pcolor red [ ifelse pcolor < red - 3  [ set pcolor white ] [ set pcolor red ] ]
    
    ;;if shade-of? pcolor 85  [ set pcolor 85 ]
    ;; if shade-of? pcolor  5  [ set pcolor white ]
    ;;if ( shade-of? pcolor black and pcolor <= gray ) 
    ;;   ; or ( shade-of? pcolor 85 and pcolor < 84 )
    ;;   [ set pcolor black ]
   ;;    and not any? neighbors with [ shade-of? pcolorand an;; if pcolor != 15 and pcolor != 85 and any? neighbors with [ pcolor = white ] [ set pcolor white ]
  ]
 
  
  ask patches with [ pcolor = red ]
  [ sprout 1
    [ ; set shape "square"
      set temp 5 + 10 * random 1000000 
    ] 
  ]

  without-interruption
  [ let change? true
    while [ change? ]
    [ set change? false
      ask turtles with [ any? (turtles-on neighbors)   ]
      [  let max-t max [ temp ] of (turtles-on neighbors)
         if max-t > temp [ set temp max-t set change? true]
      ]
    ]
  ]
 
  ask turtles
  [ set pcolor temp - temp mod 10 + 5
    set color pcolor
  ]
 
   ask turtles
   [  
     set tx mean [ xcor ] of turtles with [ temp = [temp] of myself ]
   set ty mean [ ycor ] of turtles with [ temp = [temp] of myself ]
   set tx round tx set ty round ty
   set tp patch tx ty
   set ptemp self
   set pcolor white
   setxy tx ty
   set color black
   set pcolor violet
   ]
   ask turtles
   [die
   ]
   print count patches with [ pcolor = violet ]
   export-view (word maps "." (int timer) ".png") 
end


;;;;;;;;;;;;;;;;;;;;output social networks to file;;;;;;;;;;;;;

to open-file
  let file user-new-file
  if ( file != false )
  [
    if ( file-exists? file )
      [ file-delete file ]
    file-open file
  ]
end

to write-to-file  
  file-print who; + " had visitors from " + settlement-of-origin + "                   "
end

;;;;;;;plot;;;;;;
to territories-plot
  set-current-plot "Territories"
  histogram [ color ] of settlements 
end
@#$#@#$#@
GRAPHICS-WINDOW
248
10
735
499
234
225
1.0171
1
10
1
1
1
0
1
1
1
-234
234
-225
225
0
0
1
ticks
30.0

BUTTON
14
10
82
43
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
89
10
150
43
Go
repeat days-to-run [go ] go-end-of-sequence\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
181
34
245
79
NIL
clock
3
1
11

SLIDER
3
202
170
235
difficulty-of-communications
difficulty-of-communications
0.0
4
4
0.0010
1
NIL
HORIZONTAL

CHOOSER
3
85
169
130
maps
maps
"greece_2.png" "testpattern-italy.png" "testpattern2-italy.png" "upper ottawa.png" "tibervalley3.png" "taiwan.png"
0

BUTTON
749
240
889
274
Clear Traces
;ask travellers [die]\ncd
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
3
131
170
164
number-of-travellers-per-site
number-of-travellers-per-site
1
5
1
1
1
NIL
HORIZONTAL

SLIDER
4
169
170
202
benefit-of-resources
benefit-of-resources
0
4
4
0.0010
1
NIL
HORIZONTAL

SWITCH
749
273
898
306
identify-most-important-sites?
identify-most-important-sites?
1
1
-1000

MONITOR
4
246
92
291
settlements
count settlements
3
1
11

TEXTBOX
175
183
248
201
R & W's 'alpha'
11
0.0
0

TEXTBOX
175
210
242
228
R & W's 'beta'
11
0.0
0

BUTTON
748
357
884
390
Process new  map
;; (for this model to work with NetLogo's new plotting features,\n  ;; __clear-all-and-reset-ticks should be replaced with clear-all at\n  ;; the beginning of your setup procedure and reset-ticks at the end\n  ;; of the procedure.)\n  __clear-all-and-reset-ticks\nconvert-map
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
751
395
965
492
loads selected map (red dots for settlements) and preprocesses it. (convert red dots to single violet pixels, add border). Map will still need scale markers added and may need other clean up. (red bar showing scale must be 2 pixels thick)
11
0.0
0

MONITOR
92
246
148
291
travellers
count travellers
3
1
11

SLIDER
3
53
169
86
days-to-run
days-to-run
5
365
30
5
1
NIL
HORIZONTAL

MONITOR
181
82
245
127
Px / 20 KM
scale 
3
1
11

BUTTON
129
312
239
345
write network
open-file\nask settlements\n[write-to-file]\nfile-close
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
4
294
92
339
avg # of visitors
mean [length visitors] of settlements
3
1
11

SWITCH
749
306
868
339
auto-resize
auto-resize
1
1
-1000

BUTTON
-1
375
244
414
list origins for visitors to most important settlements
ask settlements\n[\nshow-my-importance-v3\n]\nprint traveller-colors
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
735
10
981
216
Territories
NIL
NIL
5.0
145.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" ""

SWITCH
2
423
121
456
auto-clear?
auto-clear?
1
1
-1000

SLIDER
6
466
326
499
average-journey-length
average-journey-length
0
1.5
0.4
.1
1
(where each .1 = 10 km)
HORIZONTAL

@#$#@#$#@

## INTRODUCTION

Archaeologists are concerned with, amongst other things, trying to understand whether sites discovered through field survey can be used as evidence for ancient territories, and by extension, understanding which sites are most likely to be important locations. Various methods exist, but most are problematic because they do not take into account the actions of individuals, the way different individuals can react to 'tangible' and 'intangible' boundaries, and the fact that the same place may belong in different 'orbits' depending on how we look at it. So, is it possible to move from 'dots-on-a-map' to 'fuzzy territories' of socially interconnected settlements? .....yes! We are inspired by the work of Tracey Rihll and Andrew Wilson, who write:

"The emergence and evolution of the Greek polis has a strong spatial aspect. It involved the formation of a community in a territorial unit encompassing a number of settlements, and the development of a 'captial' city. To have things in common, and in particular to share a common identity, presupposes a relatively intense level of interaction amongst those who constitute a community vis-a-vis those who are excluded from it. When the poleis were coming into existence, did discrete communities align themselves with those with whom they had most in common - those with whom they experienced the most intense interaction? Did location vis-a-vis other settlements have a significant effect on their affiliation and union?"  
(Rihll and Wilson 1991: 60)

Rather than exploring the traditional archaeological concerns with site (geographic and environmental factors of the location), their model, and our simulation, is concerned with situation.  In this way, we move from 'dots-on-a-map' to something of the human interrelationships between sites.

## BASIC HYPOTHESES

The simulation presented here represents an attempt to reimplement Rihll and Wilson's model, or at the very least, create an allied agent-based model. In their model, a distribution of sites from an earlier period represents a starting point for simulating 'credits' and 'debits' of interaction from site to site. Mathematically, the model attempts to solve a series of differential equations, eventually settling on the 'best' answer. Two parameters, aside from the 2-dimensional scatter of settlements, are also modelled, to simulate difficulties in communications and the benefit of concentrated resources (hence attractiveness of a site for interaction). 

Rihll and Wilson's basic hypotheses are that:

1) interaction between any two places is proportional to the size of the origin zone and the importance and distance from the origin zone of all other sites in the survey are, which compete as destination zones;

2) the importance of a place is proportional to the interaction it attracts from other places

3) the size of a place is proportional to its importance  
(Rihll and Wilson 1991: 63, 60)

It is worth noting that we are discussing travel by foot.

## RE-IMPLIMENTATION, RE-IMAGINATION

Their model does appear to predict eventual settlements of some importance, as well as indicating the hierarchy of lesser sites that 'look' to the main one. Our reimplimentation does reproduce their results. Coupled with social-network analysis of the resulting social network of settlement interconnections, sites of particular importance, as well as 'fuzzy territories' of overlapping factions (as defined through social networks analysis) can be determined.

We have chosen to represent the interaction between sites as the result of actual travel by agents. Our model has two 'breeds' of agents: settlements, and travellers. Each traveller has a limited vision, or knowledge of its neighbourhood. The 'vision' is set variable around 20 km, or roughly the distance covered in a day's travel by foot. Travellers decide which settlement to visit by calculating a score for each settlement based on its importance, number of visitors to it, the benefit of concentrated resources, the distance to the settlement, and the difficulty of communications. The traveller visits the settlement with the highest score. It leaves a coloured trace behind it, indicating where it has travelled. 

When it arrives at its destination, it checks to see if the place where it has arrived is 'more important' than the place from which it left. If so, it changes its colour to that of the new settlement. If not, it changes the colour of the settlement to its own colour. In this way, the influence of sites over one another is demonstrated, yet mediated through individuals. The 'Territories' histogram counts the number of individual colours, and the number of settlements displaying those colours, as a rough way of showing the number and size of emergent territories. 
   
The settlements are both two-dimensional points in space, and active agents aware of their environment. It is helpful to think of a settlement agent as a 'genius locui', or spirit of the place. Their primary function is accounting, keeping track of interaction. When a traveller arrives at a settlement, the settlement's importance increases. Attracting interaction increases a site's importance. But if a settlement does not attract any visitors in a given turn, its importance declines.

The 'benefit of concentrated resources' slider allows the user to simulate something of the macro characteristics of the economy of the region. The 'difficulty of communications' slider lets the user simulate difficult travelling situations (e.g., winter, heavy vegetation, what have you).

Increasing the number of travellers who are each differentiated by their ability to perceive their environment, makes for richer interactions, but also a slower simulation and a more cluttered display (the 'Clear Traces' button erases the traces left by travellers at the end of the run; the 'auto-clear' switch will clear traces every few cycles of the model run). When exploring the behaviour of the model, it might be best to have the minimum number of travellers, since this will create a clearer display, and also be comparable to the original simulation's method whereby each settlement calculated its 'debits' and 'credits' compared to every other settlement.

## MODEL OUTPUTS

This model produces various data which can be considered on their own or exported into another programme for analyses. The 'territories' histogram in the top right of the interface window merely counts the number of settlements by color. The number of unique colors (as reported by the histogram) corresponds with the number of unique territories (which may also be seen on the map). This is the lowest level of complexity visible in this model.

The 'write network' button asks all of the settlements to list the settlements-of-origin for visitors to that settlement. This allows the user to study the social network of interactions between sites. THIS IS NOT THE SAME as the pattern of interconnections displayed in the view window. All travellers remember their home settlement; by visiting a new site, they create a social connection between it and their home site (compare with patterns of euergetism in the Roman world). This social network itself, since it is created through the interaction of agents, is a rich source of data in itself. UCINET (www.analytictech.com) is used to analyse these networks to identify the most central, the most powerful, the 'weak links' between local clusters of settlements.

To get the output into a format that UCINET or KEYPLAYER can analyse, you should edit the text file so that eg "settlement 1" becomes "settlement_1". Also, you might need to remove ( ) from around the turtle id's.. Then, place the following five lines of information at the top of the file created by the 'write network' button:

dl  
n = x
                          

format = nodelist  
labels embedded  
data:  
settlement_0 settlement_23 settlement_46 settlement_56

.....etc. X = number of settlements. That first line of sample data above tells the social network analysis software that settlement 0 is connected to settlement 23, settlement 46, and settlement 56. It does not imply that settlement 46 and settlement 56 are directly connected.

Other outputs:

The two switches, 'identify-most-important-sites' and 'resize-settlements' provide two alternative visualisations of site importance. The first runs at the end of a simulation, identifying the sites with the largest importance by a red halo; then green, then yellow, then blue. Resize-settlements operates during the model run, and causes the size of the settlement to scale importance to maximum site importance on a scale of size 1 to 20 (so the most important site will always be displayed as size twenty; this is merely a display variable, and not used in any other calculations).  
Finally, the button 'list origins...' looks at the most important sites based on the variable 'importance' and lists their social connections.

## ASSESSING MODEL OUTPUTS

The social network of interconnected settlements, generated by travelling individuals (and output by the 'write networks' button), can be studied from multiple viewpoints to meet Thomas� (2001) idea of the �productive tension�, the resolution of his two understandings of the word �landscape�, of a �territory which can be apprehended visually�, and a �set of relationships between people and places which provide the context for everyday conduct�. Social network analysis allows us to consider both local and global positioning of a settlement vis-�-vis every other settlement.

Social network analysis is a suite of methods from the mathematics graph theory (which considers sets of connected objects). In social terms, it is predicated on the idea that agency can be mediated through both local and global positioning within a network. I.e., individuals who are well-connected have a greater range of opportunities since there are more channels through which information may flow to them. 

With SNA, we can analyse the ties between settlements: determine which settlement is best connected to the others = social power, which settlement forms a link b/w otherwise disconnected clumps of settlements (forming a social bridge), which settlements can wield the most influence over others.

We can analyse which settlements are allied in their patterning of interconnections, and then use that patterning to determine likely �fuzzy territories�, and to understand the interrelationships of those territories.

Because this model depends on site and traveller interactions, and a number of outputs may be produced in a model run, we suggest using the following network metrics (KEYPLAYER and UCINET) to identify the most important sites:

1. Fragmentation criterion, group size 10. 10 starts. 20 iterations  
2. Dependency (Bonacich Power with a -0.5 attenuation) (top 10)   
3. Flow betweeness (top 10)   
4. Degree  
5. Factions (sets of overlapping patternings; 5 is a good number to start with)

The fragmentation criterion identifies nodes in a network whose removal cause the network to collapse into isolated fragments.

Bonacich power index identifies 'powerful' nodes in a network based on their relative positioning with regard to every other node. When negatively attenuated, it identifies nodes that are well connected to poorly connected others, which would seem to correspond with Rihll and Wilson's 'terminal' sites.

Flow betweeness identifies nodes which are on the majority of shortest paths between every pair of nodes in a network.

Degree is the simple number of connections.

Factions are sets of settlements with similar patterns of interconnections. Identifying factions also allows us to identify patterns of �alliances� between factions (where there are overlaps in the patterning of interconnections). 

## SUCCESS?

A successful reimplementation will make similar predictions of site importance, hierachy and territory. Accordingly, the same map of sites from Geometric Greece is used here. When run at the same parameter values as in the original 1991 model, very similar results emerge.

The various metrics did indicate the importance of settlements such as Athens, Corinth, and Megara; for cities like Thebes it indicated extremely near neighbours, which is in fact what Rihll and Wilson found. The most important site, according to our experiments with this model, did not evolve into a city at all, but rather is the extra-urban sanctuary of the Argive Heraion, which is an intriguing result.

In any event, �situation� rather than �site� is a clearly very important part of the story in the evolution of the later city-states, but not the only factor. When we look at �factions�, to understand those fuzzy territories, the model seems to accurately predict the location and extent of allied groupings. The patterning of densities of overlaps within the factions also points to a heightened importance for Corinth and the Isthmia (the patterning of �alliances� seems to lead to this faction in particular). This accords well with the evidence of pottery, where corinthian-wares are found across the eastern mediterranean and into Etruria in this period.

When we ran the model on the protohistoric period (8th � 6th BC) of Central Italy, we achieved results which also would seem to validate the model. The various network metrics indicated settlements such as Falerii Veteres, Fidenae, and Veii being extremely important. This agrees with the early history of Rome, when these cities were seen as being Rome's major competitors in the region. It is interesting also that these early settlements � all conquests of Rome � ranked higher than Rome did itself in our network analysis. This would recast Rome's early wars of expansion in part as a re-jigging of the networks to improve Rome's 'situation'.

This simulation then seems to have the possibility to be a useful tool for understanding the interrelationships between sites, the likely territories in a given area, and sites likely to be of some archaeological importance.

## IMPORT NEW MAPS

The simulation looks at a map for two crucial things: a scale bar in red, two pixels thick, and single violet pixels marking the location of site. If your map has these (and the scale should be as long as an expected day's journey), then you can simply add the map name to the map chooser. 

The 'process new map' button is for maps digitised by hand or exported from other programmes, where the sites are indicated by a red spot (but not necessarily a one-pixel spot). It processes the map by converting the red spots into single violet pixels (1 violet pixel = 1 site), and saving the output. These semi-processed maps may then be touched up using MS Paint or similar program to add the scale bar, and to check the location of processed sites.

1. Export from your GIS (or digitise/scan in) your base map of settlements as a PNG. Make sure these are coloured red.

2. Add the name of this base map to the map chooser.

3. Select that map.

4. Click on 'Process New Map'. This will load the map, and begin to adjust it.

5. Open the resulting map in your image software. The name of the resulting map will be  
'base map.png.xxxx.png'   
where base map is the name you gave the map,  
xxxxx is a number based on the internal clock of your computer

6. Examine the settlements. These should be violet SQUARES of pixels. If the settlements are rendered as a line of pixels, draw in the necessary pixels to make it square.

7. Add a two-pixel thick line, coloured red, which will be the scale bar. Make it the appropriate length of a single day's journey (we usually use 20 km). Save as a PNG with a new name.

8. Add the newly-named map to the map chooser in the model. Select the new map. Press the SETUP button. Examine the map. If all has gone well, your violet-coloured settlements will have spawned settlement agents. If not, you might see some settlement agents, and some settlements pixels. If this happens, open the newly-named map and fix the settlements at issue.

This process can be a bit awkward. We apologise; hopefully as more people explore this model better import routines will be developed. You might be able to skip some steps if your GIS allows you to colour your settlements with the correct shade of violet in the first place. Use the 'Tools - color swatches' menu in Netlogo to work out the correct shade (violet = 115).

Existing Maps  
A number of maps are provided with the simulation. The numbering of them is a legacy of the development process, and need not  concern the user.

"Greece_2.png" is a map of central Greece with settlements from the Geometric period plotted. This map was hand-digitised from Rihll and Wilson's original article.

"Tibervalley3.png" is a map of central Italy, with protohistoric sites marked on. The data was culled primarily from Chris Smith, 'Early Rome and Latium', Tim Potter, 'Changing Landscape of South Etruria', and other archaeological maps conserved at the British School at Rome. 

"Upper Ottawa.png" is a hand-digitised map of the Upper Ottawa Valley in Canada, showing settlements founded in the 19th century before the advent of the railways (from a base map published in Canadian Geographic Magazine)

The two 'test pattern' maps allows the user to control the placement of settlements (lattice, ring) to explore the effects of altering population and the other sliders. It also allows the user to explore and test for 'edge-effects'.

## WORKS CITED

Borgatti, S. P., M.G. Everett, and L.C. Freeman (1996). UCINET IV Version 1.64. Nantick, MA, Analytic Technologies URL: http:www.analytic.com.

Potter, T. (1979). The Changing Landscape of South Etruria. New York: St. Martin's Press.

Rihll, T.E. and A. G. Wilson (1991). �Modelling settlement structures in ancient Greece : new approaches to the polis�. In J. Rich and A. Wallace-Hadrill (eds). City and country in the ancient world. London : Routledge.

Smith, C. (1996). Early Rome and Latium Economy and Soceity c.1000 to 500 BC. Oxford: Clarendon Press.

Thomas, J. (2001). "Archaeologies of Place and Landscape". In I. Hodder (ed). Archaeological Theory Today. Cambridge: Polity Press.

## ACKNOWLEDGEMENTS

Canadian Research Chair in Roman Archaeology, Department of Classics, University of Manitoba

The British School At Rome

Thanks also to the participants in the simulation modeling session at the 2006 Computer Applications in Archaeology Conference, Fargo, North Dakota

## COPYRIGHT

(c) Shawn Graham, James Steiner 2006  
Some Rights Reserved.  
Creative Commons Attribution-NonCommercial-ShareAlike License v. 2.0.  
Visit http://creativecommons.org/licenses/by-nc-sa/2.0/ for more information. 

To cite this model and this information page, please use:   
Graham, S. and J. Steiner (2006) "TRAVELLERSIM : SETTLEMENTS, TERRITORIES, AND SOCIAL NETWORKS" http://home.cc.umanitoba.ca/~grahams/Travellersim.html 
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

20 km
false
0
Polygon -10899396 true false 15 30 45 0 105 0 135 30 135 60 75 120 120 120 135 150 15 150 90 60 90 30 60 30 60 45 15 45
Polygon -10899396 true false 150 30 180 0 255 0 285 30 270 120 240 150 195 150 165 120 150 60 195 60 210 120 225 120 240 30 195 30 195 60 150 60
Polygon -10899396 true false 30 165 75 165 75 210 105 165 135 165 90 225 135 300 105 300 75 240 75 300 45 300
Polygon -10899396 true false 135 300 135 165 165 165 195 225 225 165 270 165 255 300 225 300 225 225 195 285 165 225 165 300

circle
false
5
Circle -10899396 true true 0 0 300

circle-lined
false
5
Circle -16777216 true false 0 0 300
Circle -10899396 true true 14 14 272

clocks
true
5
Circle -10899396 true true 0 0 300
Circle -1 true false 29 29 242
Rectangle -10899396 true true 135 45 165 165

link
true
0
Line -7500403 true 150 0 150 300

link direction
true
0
Line -7500403 true 150 150 30 225
Line -7500403 true 150 150 270 225

ring
false
5
Polygon -10899396 true true 150 0 210 15 255 45 285 90 300 150 285 210 255 255 210 285 150 300 90 285 45 255 15 210 0 150 15 90 45 45 90 15 150 0 150 30 135 30 90 45 45 90 30 135 30 165 45 210 90 255 135 270 165 270 210 255 255 210 270 165 270 135 255 90 210 45 165 30 150 30

square
false
0
Rectangle -10899396 true false 0 0 300 300

square-lined
false
0
Rectangle -16777216 true false 0 0 300 300
Rectangle -10899396 true false 15 15 285 285

star
false
5
Polygon -10899396 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

star-lined
false
5
Polygon -16777216 true false 120 -15 180 -15 210 90 315 90 315 135 240 180 270 285 225 300 150 255 75 300 30 285 60 180 -15 120 -15 90 90 90
Polygon -10899396 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

@#$#@#$#@
NetLogo 5.0.4
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="movie" repetitions="1" runMetricsEveryStep="true">
    <setup>movie-start user-choose-new-file
setup
movie-grab-interface</setup>
    <go> go movie-grab-interface 
 
</go>
    <final>go-end-of-sequence
movie-close</final>
    <exitCondition>clock = days-to-run</exitCondition>
    <enumeratedValueSet variable="number-of-travellers-per-site">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="difficulty-of-communications">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="identify-most-important-sites?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="benefit-of-resources">
      <value value="1.025"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maps">
      <value value="&quot;greece_2.png&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-resize">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="days-to-run">
      <value value="30"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go
</go>
    <final>ask settlements [print who + " " + settlement-of-origin + "                   "]
ask settlements
[
show-my-importance-v3
]
print traveller-colors
export-view (word maps "." (int timer) ".png") 
;open-file
;ask settlements
;[write-to-file]
;file-close</final>
    <exitCondition>clock = days-to-run </exitCondition>
    <enumeratedValueSet variable="benefit-of-resources">
      <value value="1.025"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="identify-most-important-sites?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="difficulty-of-communications">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maps">
      <value value="&quot;tiber valley3.png&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-travellers">
      <value value="10"/>
      <value value="100"/>
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="days-to-run">
      <value value="30"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 1.0 0.0
0.0 1 1.0 0.0
0.2 0 1.0 0.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
