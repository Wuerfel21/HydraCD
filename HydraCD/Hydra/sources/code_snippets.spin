{
' kaledioscope
  repeat i from 0 to 1000
    ' select random color for point


    color := 1+(color + (?rand)) // 3
    x := ?rand // (SCREEN_WIDTH/2)
    y := ?rand // SCREEN_HEIGHT
    gr.colorwidth(color, 0)
    gr.plot(x + SCREEN_WIDTH/2,y)
    gr.plot(SCREEN_WIDTH/2 - x,y) 
}
