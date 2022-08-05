wireframe(volcano, shade = TRUE,
           aspect = c(61/87, 0.4),
           screen = list(z = -120, x = -45),
           light.source = c(0,0,10), distance = .2,
           shade.colors = function(irr, ref, height, w = .5)
           grey(w * irr + (1 - w) * (1 - (1-ref)^.4)))

