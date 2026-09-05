-- 7-bosqich: Erase occupied-use categories from the candidate set.
-- Most importantly AX_FlaecheBesondererFunktionalerPraegung -- the category that
-- had been silently absorbing schools, colleges, hospitals, and similar
-- institutions under one generic label.

bezeich IN (
    'AX_Wohnbauflaeche', 'AX_IndustrieUndGewerbeflaeche',
    'AX_FlaecheBesondererFunktionalerPraegung', 'AX_Friedhof',
    'AX_Bahnverkehr', 'AX_Strassenverkehr', 'AX_Flugverkehr',
    'AX_Hafenbecken', 'AX_Schiffsverkehr', 'AX_TagebauGrubeSteinbruch',
    'AX_StehendesGewaesser', 'AX_Fliessgewaesser', 'AX_Wald',
    'AX_Moor', 'AX_Sumpf', 'AX_Halde', 'AX_Weg'
)
