; ==== Hallmarks (simplified) interactive model + chemotherapy gameplay ====
;
; This model is adapted in part from:
;
; Wilensky, U. (2007).
; NetLogo Hex Cell Aggregation model.
; Center for Connected Learning and Computer-Based Modeling,
; Northwestern University, Evanston, Illinois.
;
; Original model:
; http://ccl.northwestern.edu/netlogo/models/HexCellAggregation
;
; Original model copyright 2007 Uri Wilensky.
; Licensed under the Creative Commons
; Attribution-NonCommercial-ShareAlike 3.0 License:
; https://creativecommons.org/licenses/by-nc-sa/3.0/
;
; Modifications copyright 2026 Rodrigo Enrique Caceres Gutierrez.
;
; This modified version adds tumor proliferation, crowding suppression,
; replicative lifespan, anchorage dependence, chemotherapy, toxicity,
; patient-condition calculations, and a patient HUD.
;
; This modified version is also distributed under CC BY-NC-SA 3.0.
; No endorsement by the original author or Northwestern University
; is intended or implied.


; Last modification: Added a right-side HUD strip for the avatar (outside the tumor grid)

; REQUIRED INTERFACE WIDGETS (create these on the Interface tab):
; sliders: proliferation-prob (0–100), neighbor-threshold (0–8), anchorage-delay (0–200), chemo-dose (0–100)
; switches: evading-suppressors?, immortality?
; chooser: chemo-frequency ["Manual" "Every 7 ticks" "Every 14 ticks"]
; button: Give Chemo  -> calls give-chemo

; ---------- declare breeds FIRST ----------
breed [tumor-cells tumor-cell]
breed [hud-labels hud-label]
breed [avatars avatar]         ;; a single “person” turtle for patient state

globals [
  eligibles                    ;; agentset of dead tumor-cells eligible to become alive (≥1 live neighbor)

  ;; --- Chemo & visuals (preset; no extra sliders) ---
  toxicity                     ;; 0–100; increases on dose, decays each tick
  toxicity-death-threshold     ;; fixed at 100
  toxicity-half-life           ;; decay half-life in ticks (exponential)
  toxicity-per-100             ;; toxicity added by a 100-dose click
  base-kill                    ;; per-cell kill probability at dose=100 (before bonus)
  chemo-cooldown               ;; min ticks between doses (prevents spam)
  last-chemo-tick              ;; last tick chemo was given
  auto-chemo-interval          ;; 0 (manual), 7, or 14 based on chooser
  patient-w-tox        ;; weight of toxicity in overall patient condition
  patient-w-burden     ;; weight of tumor burden in overall patient condition
  patient-burden-gain     ;; >1 amplifies tumor burden before mixing (keeps chemo weight unchanged)



  ;; stacking toxicity control
  recent-dose-burden           ;; 0–1, rises with each dose, decays each tick (amplifies toxicity if dosing too frequently)

  kill-quota                   ;; hard cap on number of cells sampled per dose (performance)
  tumor-%                      ;; % alive cells (for monitors/plots if you add them)

  ;; ---- HUD strip configuration ----
  hud-cols                     ;; how many rightmost columns are reserved for the HUD
  hud-xmin                     ;; left boundary (pxcor) of HUD strip
  hud-header-y                 ;; row for "Patient" header
]

tumor-cells-own [
  lifespan-counter             ;; replicative age
  alive?                       ;; living state
  anchor-counter               ;; counter for anchorage dependence
]

; ---------- setup ----------
to setup
  clear-all
  configure-hud                 ;; compute HUD geometry
  setup-grid                    ;; sprout tumor cells ONLY outside the HUD strip
  seed-center
  setup-chemo-and-visuals
  paint-hud                     ;; color and label HUD background
  setup-avatar                  ;; place avatar inside HUD strip
  reset-ticks
end

; compute HUD geometry from current world size
to configure-hud
  set hud-cols 8
  set hud-xmin (max-pxcor - (hud-cols - 1))
  set hud-header-y (max-pycor - 35)
end

to seed-center
  ; seed: one immortal live cell at the center patch (must be outside HUD)
  let center-patch patch 0 0
  if [pxcor] of center-patch >= hud-xmin [
    user-message (word "Your world center (0,0) lies inside the HUD strip.\n"
                       "Please use a world width where 0 < " (hud-xmin) ".")
    stop
  ]
  ask one-of (tumor-cells-on center-patch) [
    become-alive
    set lifespan-counter 0     ; center stays at 0 forever (not incremented later)
  ]
end

; ---------- main step ----------
to go
  ;; force current chooser into interval and decay toxicity
  update-auto-chemo-interval
  set toxicity toxicity * (0.5 ^ (1 / toxicity-half-life))
  if toxicity < 0 [ set toxicity 0 ]
  if toxicity > toxicity-death-threshold [ set toxicity toxicity-death-threshold ]
  ;; decay stacking penalty (fast decay; increase 0.9->0.95 for slower decay)
  set recent-dose-burden recent-dose-burden * 0.9

  ;; recompute eligibles each tick: currently-dead cells that touch ≥1 live neighbor
  set eligibles (tumor-cells with [
    (not alive?) and any? ((tumor-cells-on neighbors) with [alive?])
  ])

  ;; stop if nothing else can happen
  if (not any? eligibles) and (not any? tumor-cells with [alive?]) and (auto-chemo-interval = 0) [ stop ]

  ;; 1) Sustained proliferative signaling (+ crowding suppression)
  ask eligibles [
    let eff-prob proliferation-prob
    let neighbor-count count ((tumor-cells-on neighbors) with [alive?])

    ;; Apply crowding suppression unless evading is ON; skip center patch
    if (not evading-suppressors?) and (not (pxcor = 0 and pycor = 0)) [
      if neighbor-count > neighbor-threshold [
        set eff-prob eff-prob * 0.1
      ]
    ]

    if (random-float 100) < eff-prob [
      become-alive
    ]
  ]

  ;; 2) Replicative immortality (lifespan)
  ask tumor-cells with [alive?] [
    if not (pxcor = 0 and pycor = 0) [  ;; center is special
      set lifespan-counter lifespan-counter + 1
      if (not immortality?) and (lifespan-counter >= 50) [
        become-dead
      ]
    ]
  ]

  ;; 3) Anchorage dependence
  ask tumor-cells with [alive?] [
    if not (pxcor = 0 and pycor = 0) [  ;; center is exempt
      let my-dist distancexy 0 0
      let closer-neighbors ((tumor-cells-on neighbors) with [
        alive? and (distancexy 0 0 < my-dist)
      ])
      ifelse any? closer-neighbors [
        set anchor-counter 0
      ] [
        set anchor-counter anchor-counter + 1
        if anchor-counter >= anchorage-delay [
          become-dead
        ]
      ]
    ]
  ]

  ;; Auto-chemo schedule (respects cooldown)
  if (auto-chemo-interval > 0) and ((ticks - last-chemo-tick) >= auto-chemo-interval) [
    give-chemo
  ]

  ;; update tumor % (optional monitor/plot) and avatar
  ifelse any? tumor-cells [
    set tumor-% 100 * (count tumor-cells with [alive?]) / count tumor-cells
  ] [
    set tumor-% 0
  ]
  update-avatar

  tick
end

; ---------- chemotherapy + visuals (preset) ----------
to setup-chemo-and-visuals
  ;; more realistic/penalizing toxicity defaults
  set toxicity 0
  set toxicity-death-threshold 100
  set toxicity-half-life 20
  set toxicity-per-100 30      ;; harsher toxicity
  set base-kill 0.15
  set chemo-cooldown 8         ;; less click-spam
  set last-chemo-tick -9999
  set recent-dose-burden 0     ;; starts with no stacking penalty
  set patient-burden-gain 1.30  ;; try 1.30–1.50; 1.30 lets 100% burden hit Critical when tox=0


  ;; patient condition weights (simple linear mix)
  set patient-w-tox 0.6      ;; toxicity contributes 60%
  set patient-w-burden 0.4   ;; tumor size contributes 40%

  ;; cap per-dose work to keep things snappy (≈25% of grid; at least 1)
  set kill-quota max list 1 round (0.25 * count tumor-cells)

  update-auto-chemo-interval
end

to update-auto-chemo-interval
  ifelse chemo-frequency = "Every 7 ticks" [
    set auto-chemo-interval 7
  ] [
    ifelse chemo-frequency = "Every 14 ticks" [
      set auto-chemo-interval 14
    ] [
      set auto-chemo-interval 0
    ]
  ]
end

to give-chemo
  ;; respect cooldown to prevent spam
  if (ticks - last-chemo-tick) < chemo-cooldown [ stop ]
  set last-chemo-tick ticks

  ;; stacking multiplier: recent-dose-burden (0..1) boosts toxicity up to ~2.5×
  let stack-mult (1 + 1.5 * recent-dose-burden)

  ;; toxicity increase (scaled by dose) with stacking, then clamp
  set toxicity toxicity + (chemo-dose / 100) * toxicity-per-100 * stack-mult
  if toxicity > toxicity-death-threshold [ set toxicity toxicity-death-threshold ]
  if toxicity < 0 [ set toxicity 0 ]

  ;; update the stacking burden (clamp 0..1). Bigger doses add more burden.
  set recent-dose-burden min list 1 (recent-dose-burden + (chemo-dose / 100) * 0.6)

  ;; if no live cells, nothing to do
  if not any? tumor-cells with [alive?] [ stop ]

  ;; sample targets with a hard cap (performance)
  let alive-n count tumor-cells with [alive?]
  let n min list kill-quota round (alive-n * (chemo-dose / 100))
  if n <= 0 [ stop ]

  no-display
  let targets n-of n (tumor-cells with [alive?])
  ask targets [
    ;; proliferative bonus: recently divided cells are more sensitive
    let bonus (ifelse-value (lifespan-counter <= 2) [1.5] [1.0])
    let kill-prob base-kill * (chemo-dose / 100) * bonus
    if kill-prob > 1 [ set kill-prob 1 ]
    if random-float 1 < kill-prob [ become-dead ]
  ]
  display
end

; ---------- HUD strip ----------
to paint-hud
  ask patches with [pxcor >= hud-xmin] [
    set pcolor 88               ;; light gray HUD background
  ]
 ;; header: centered in the HUD strip using a label turtle
create-hud-labels 1 [
  ;; center x = left edge + half the HUD width
  setxy (hud-xmin - 0.5 + (hud-cols / 2)) hud-header-y
  set shape "square"   ;; invisible: size 0
  set size 0
  set label "Patient"
  set label-color black
]
end

; ---------- avatar (schematic person) ----------
to setup-avatar
  create-avatars 1 [
    ;; place inside the HUD strip (right side, mid-height)
    setxy (hud-xmin + 3) 0
    set size 8
    ;; if "person" shape is missing in your NetLogo library, change to "circle"
    set shape "person"
    set color green
    set label "Stable"
  ]
end

to update-avatar
  ask avatars [
    ;; normalize inputs
    let toxfrac (toxicity / toxicity-death-threshold)   ;; 0..1
    let burdenfrac (tumor-% / 100)                       ;; 0..1

    ;; amplify burden before mixing; DO NOT clamp here
    let effective-burden (burdenfrac * patient-burden-gain)

    ;; linear mix with your existing weights; then clamp the final score 0..1
    let condition (patient-w-tox * toxfrac + patient-w-burden * effective-burden)
    set condition max list 0 min list 1 condition

    ;; toxicity hard limit (keeps label from being overwritten)
    if toxicity >= toxicity-death-threshold [
      set color red
      set label "Tox. limit"
      stop
    ]

    ;; more sensitive thresholds you chose earlier (0.2 / 0.5)
    ifelse condition < 0.2 [
      set color green
      set label "Stable"
    ] [
      ifelse condition < 0.5 [
        set color yellow
        set label "Unwell"
      ] [
        set color orange
        set label "Critical"
      ]
    ]
  ]
end




; ---------- state transitions ----------
to become-alive  ;; tumor-cell procedure
  set alive? true
  show-turtle
  set color red
  set lifespan-counter 0
  set anchor-counter 0
end

to become-dead  ;; tumor-cell procedure
  set alive? false
  hide-turtle
  set color orange
  set lifespan-counter 0
  set anchor-counter 0
end

; ---------- grid ----------
to setup-grid
  set-default-shape turtles "circle"
  ask patches with [pxcor < hud-xmin] [     ;; ONLY outside HUD
    sprout-tumor-cells 1 [
      hide-turtle
      set size 1.2
      set color orange
      set alive? false
      set lifespan-counter 0
      set anchor-counter 0
      ;; vertical offset for even columns to make hex-like lattice
      if (pxcor mod 2 = 0) [ set ycor ycor - 0.5 ]
    ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
53
25
838
811
-1
-1
9.6
1
10
1
1
1
0
1
1
1
-40
40
-40
40
0
0
1
ticks
30.0

SLIDER
1054
100
1198
133
proliferation-prob
proliferation-prob
0
10
1.0
1
1
NIL
HORIZONTAL

BUTTON
1582
116
1704
191
setup
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
1714
116
1835
192
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
1056
186
1181
219
immortality?
immortality?
0
1
-1000

SWITCH
1056
275
1234
308
evading-suppressors?
evading-suppressors?
1
1
-1000

SLIDER
1055
448
1227
481
anchorage-delay
anchorage-delay
1
10
4.0
1
1
NIL
HORIZONTAL

SLIDER
1055
369
1227
402
neighbor-threshold
neighbor-threshold
1
6
1.0
1
1
NIL
HORIZONTAL

SLIDER
1630
296
1802
329
chemo-dose
chemo-dose
0
100
100.0
1
1
NIL
HORIZONTAL

CHOOSER
1655
362
1793
407
chemo-frequency
chemo-frequency
"Manual" "Every 7 ticks" "Every 14 ticks"
0

BUTTON
1649
214
1773
270
give-chemo 💊 💉
give-chemo
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
1253
273
1290
314
👿
30
114.0
1

TEXTBOX
1202
178
1243
215
👻
30
0.0
1

TEXTBOX
1200
57
1289
131
🏎
70
0.0
1

TEXTBOX
1782
223
1855
262
💊💉
30
0.0
1

TEXTBOX
1237
445
1279
478
⚓
30
0.0
1

TEXTBOX
1238
373
1277
400
🛑
30
0.0
1

@#$#@#$#@
## WHAT IS IT?

This model is an educational simulation of tumor growth and chemotherapy. It introduces several simplified characteristics associated with cancer, including sustained cell proliferation, evasion of growth suppression, replicative immortality, and reduced dependence on cellular anchorage.

The simulation begins with one tumor cell in the center of the model. Depending on the settings selected by the user, the tumor may expand, stop growing, or lose cells.

The model also illustrates an important challenge in cancer treatment: chemotherapy may reduce the number of tumor cells, but it can also harm the patient. A patient avatar on the right side of the model reflects the combined effects of tumor burden and treatment toxicity.

The model is intended for education and discussion. It is not a clinically validated cancer model and should not be used to predict the behavior of a real tumor or the outcome of a medical treatment.


## HOW IT WORKS

At setup, the tumor area is filled with inactive tumor-cell agents. These cells are initially hidden. The columns are vertically offset to produce a hexagon-like arrangement.

One active tumor cell is placed at the center of the world. The central cell acts as the original tumor cell and is exempt from the lifespan and anchorage-dependence rules.

During each tick, the model identifies inactive tumor cells that have at least one active neighboring tumor cell. These cells become eligible to grow.

### Proliferation

Each eligible cell has a probability of becoming active. This probability is controlled by the `proliferation-prob` slider.

When an inactive cell becomes active, it becomes visible and red. Its lifespan and anchorage counters are reset.

### Growth suppression

When `evading-suppressors?` is off, crowding can reduce proliferation.

The model counts the active neighbors surrounding an eligible cell. If that number is greater than `neighbor-threshold`, the cell's proliferation probability is reduced to 10% of its original value.

When `evading-suppressors?` is on, this crowding suppression is ignored.

### Replicative lifespan

Every active tumor cell except the original central cell has a lifespan counter.

When `immortality?` is off, a tumor cell dies after its lifespan counter reaches 50 ticks.

When `immortality?` is on, cells are not removed because of replicative age.

### Anchorage dependence

Each active tumor cell checks whether it has an active neighboring cell that is closer to the original tumor center.

If it has such a neighbor, its anchorage counter is reset. If it does not, its anchorage counter increases.

When the counter reaches the value of `anchorage-delay`, the cell dies. The original central cell is exempt from this rule.

This is a simplified representation of the requirement of many normal cells to remain connected to an appropriate cellular environment.

### Chemotherapy

Chemotherapy may be given manually or automatically.

The selected dose determines:

* how many active tumor cells are considered for treatment;
* the probability that each targeted cell dies; and
* how much toxicity is added to the patient.

Recently created tumor cells are more sensitive to chemotherapy in this model.

Only a limited proportion of the tumor-cell population is sampled during each treatment. This limit helps the simulation remain responsive in large worlds.

Chemotherapy has a cooldown period of eight ticks. Attempts to administer another treatment during the cooldown period have no effect.

### Toxicity

Toxicity increases when chemotherapy is administered and gradually decreases between treatments.

Giving large or closely spaced doses produces a stacking effect. This means that repeated treatment can add more toxicity than the same doses given farther apart.

### Patient condition

The percentage of active tumor cells is used as a simplified measure of tumor burden.

The patient's condition combines:

* chemotherapy toxicity; and
* tumor burden.

In the current model, toxicity contributes 60% of the condition score, while amplified tumor burden contributes 40%.

The patient avatar changes color and label:

* **Green — Stable**
* **Yellow — Unwell**
* **Orange — Critical**
* **Red — Tox. limit**

A patient may therefore become worse because of tumor growth, chemotherapy toxicity, or a combination of both.

## HOW TO USE IT

### SETUP

Press **SETUP** to clear the model, create the tumor-cell grid, place one active cell at the center, reset chemotherapy and toxicity, and create the patient display.

Press **SETUP** again whenever you want to begin a new experiment.

### GO

Press **GO** to advance the model continuously.

Each tick represents one simulation step. It does not represent a specific real-world unit such as one hour, day, or week.

### proliferation-prob

Range: 0–100

This slider controls the percentage probability that an eligible inactive tumor cell will become active during a tick.

Higher values generally produce faster tumor growth.

### neighbor-threshold

Range: 0–8

This slider controls how much crowding is tolerated before growth suppression occurs.

When `evading-suppressors?` is off and the number of active neighbors is greater than this threshold, the cell's proliferation probability is reduced.

Lower values make crowding suppression occur sooner. Higher values allow cells to continue proliferating in more crowded areas.

### evading-suppressors?

When this switch is off, crowding can reduce proliferation.

When it is on, tumor cells ignore the crowding-suppression rule and continue using the full proliferation probability.

### immortality?

When this switch is off, noncentral tumor cells die after reaching a replicative lifespan of 50 ticks.

When it is on, cells do not die because of replicative age.

### anchorage-delay

Range: 0–200

This slider controls how long an active tumor cell can remain without an active connection leading toward the tumor center.

Low values make unanchored cells die quickly. High values allow them to survive longer.

At a value of 0, an unanchored cell may die as soon as the anchorage rule is evaluated.

### chemo-dose

Range: 0–100

This slider controls the strength of chemotherapy.

Higher doses target more tumor cells and give each targeted cell a greater probability of dying. Higher doses also cause more patient toxicity.

A dose of 0 does not kill tumor cells or add meaningful treatment toxicity.

### chemo-frequency

This chooser determines how chemotherapy is scheduled:

* **Manual** — chemotherapy is given only when the user presses **Give Chemo**.
* **Every 7 ticks** — the model attempts to give treatment after seven ticks. Because treatment also has an eight-tick cooldown, the effective interval cannot be shorter than eight ticks.
* **Every 14 ticks** — the model attempts to give chemotherapy every fourteen ticks.

### Give Chemo

Press this button to administer the dose selected with `chemo-dose`.

The button has no effect when treatment is still within the eight-tick cooldown period.

### Tumor display

Visible red circles represent active tumor cells.

Inactive or dead tumor cells are hidden. They remain available as locations that may become active again if they are next to living tumor cells.

### Patient display

The strip on the right side of the world displays the patient avatar.

Its color and label summarize the patient's current condition based on tumor burden and treatment toxicity.


## THINGS TO NOTICE

Notice that repeated runs can produce different results even when all settings are identical. Cell proliferation and chemotherapy killing are probabilistic.

Observe how the tumor's shape changes when growth suppression is active. Crowding may slow growth in dense areas, while cells near the tumor boundary may continue expanding.

Compare the tumor when `evading-suppressors?` is on and off. Evading suppression generally allows more aggressive expansion.

Observe what happens when `immortality?` is off. Individual tumor cells may disappear after reaching their lifespan limit, even while new cells continue to appear.

Notice how `anchorage-delay` affects cells near irregular or disconnected parts of the tumor.

Watch the patient avatar as chemotherapy is administered. A treatment may reduce tumor burden while simultaneously making the patient more unwell because of toxicity.

Notice that closely spaced doses can increase toxicity more rapidly because of the dose-stacking mechanism.

The best result for tumor control is not necessarily the best immediate result for the patient's condition.

## THINGS TO TRY

Run the model several times with the same settings. Compare the final tumor size, shape, and patient condition.

Set a high `proliferation-prob`, turn on `evading-suppressors?`, and turn on `immortality?`. Observe how these characteristics combine to produce aggressive growth.

Turn off `evading-suppressors?` and compare low and high values of `neighbor-threshold`.

Turn off `immortality?` and observe whether the tumor can continue expanding even though individual cells have limited lifespans.

Compare a very short `anchorage-delay` with a very long one. Look for differences in the tumor boundary and in isolated groups of cells.

Try controlling the tumor with several small chemotherapy doses. Then restart the model and try fewer large doses.

Compare manual treatment with automatic treatment every 14 ticks.

Allow the tumor to grow before starting chemotherapy. Restart the model and begin treatment earlier. Compare tumor burden, toxicity, and patient condition.

Try to keep the patient in the **Stable** or **Unwell** state while also preventing the tumor from occupying most of the grid.

Experiment with settings that cause the tumor to shrink temporarily and then begin growing again.

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES




## RELATED MODELS

The grid-based growth framework in this model was adapted in part from the NetLogo **Hex Cell Aggregation** model by Uri Wilensky.

That model demonstrates how cells can grow across a hexagon-like arrangement according to local neighbor rules.

## CREDITS AND REFERENCES

### Scientific framework

Hanahan, D. (2022). Hallmarks of Cancer: New Dimensions.  
*Cancer Discovery*, 12(1), 31–46.  
https://doi.org/10.1158/2159-8290.CD-21-1059

The model is an educational simplification inspired by concepts discussed in this publication. It does not reproduce the complete biological framework and is not intended as a quantitative implementation of the Hallmarks of Cancer.

### Adapted NetLogo model

This model adapts portions of:

Wilensky, U. (2007). *NetLogo Hex Cell Aggregation model*.  
Center for Connected Learning and Computer-Based Modeling,  
Northwestern University, Evanston, Illinois.

Original model:

http://ccl.northwestern.edu/netlogo/models/HexCellAggregation

Original model copyright 2007 Uri Wilensky.

The original model is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License:

https://creativecommons.org/licenses/by-nc-sa/3.0/

This modified model is distributed under the same license. Changes include tumor-specific proliferation, growth suppression, replicative lifespan, anchorage dependence, chemotherapy, toxicity, patient-condition calculations, and the patient HUD.

No endorsement by Uri Wilensky, Northwestern University, the Center for Connected Learning and Computer-Based Modeling, Douglas Hanahan, or the cited publishers is intended or implied.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
