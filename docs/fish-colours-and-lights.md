# Fish colours and lighting (0.12)

BETTA 120Hz advertises fish colours, details, lights and background colours on [the developer's page](https://maxelus.net/android/betta-120hz/) (reviewed 25 November 2026). The user's archived Unity scene also contains objects named `BaseColor`, `DetailsColor`, `SpecularColor`, `LightColor`, `BackgroundColor`, `LIGHTNES`, `ColorHSV`, `RESET_FISH`, `CustomColors`, `RANDOM_CLOCK` and `RandomTimer`.

These names establish control categories, not the original slider ranges, exact shading mathematics or timer behaviour. TamoTank implements its own controls and shaders; no code, textures or other assets from the reference app are included.

| Reference evidence | TamoTank equivalent | Limits |
| --- | --- | --- |
| BaseColor and DetailsColor | Independent base/marking colours, custom palette toggle, marking strength | Recolours warm/cool regions of the existing texture; does not generate new patterns |
| SpecularColor | Coloured shimmer, shimmer strength and surface shine | A view-dependent sheen with existing PBR lighting, not identical Unity specular tint |
| ColorHSV and CustomColors | HSV/RGB/HTML colour picker; five palettes and Surprise me | TamoTank palettes and parameter ranges are original choices |
| LightColor and LIGHTNES | Main light colour/strength, direction, optional fill colour/strength, ambient strength | Fill and direction are our extensions, not verified original controls |
| BackgroundColor | Backwall picker in World and Lighting, shared by Showcase/Tank | Solid colour only |
| RESET_FISH | Original colours; separate Reset lighting | Resets appearance without affecting care |
| RANDOM_CLOCK and RandomTimer | One-tap random fish palette | Automatic timed palette changes are not implemented; original timing was not recovered |
| Multiple reference fish materials | Both purchased shapes and original companion share the controls | Additional purchased texture variants have not been supplied; this does not add the reference app's full texture catalogue |

## Behaviour

World opens Fish colours & shimmer or Lights & atmosphere. These pages leave the upper water visible while values update live. Changing base or markings enables the custom palette; disabling it reveals original texture colours. Brightness, saturation, shine and shimmer also work with original colours. Eyes retain natural materials.

Defaults preserve previous natural colours and lighting. Older saves retain their old tint until a fish appearance control changes. Colour drags preview immediately and coalesce into a save after 350 ms of inactivity; pausing also saves. Wallpaper reads the same save without writing care progress. Colour refresh updates materials/lights in place, retaining the resident, animation and turn state. Rest dims configured main, fill and ambient lighting; Wake restores the user's strengths.

Shaders use bounded finite parameters, preserve UV/normal detail and keep vertex/fin deformation. No per-frame texture generation or network connection is required. Purchased assets stay outside Git/CI.

## Validation

`test_customization.gd` checks old-save migration, malformed data/ranges, body/fin surfaces on all available rigs, untouched eyes, live controls, coalesced persistence, rest/wake, and wallpaper reload without care writes or motion reset. CI exercises the public fallback; private builds also exercise both purchased rigs. `ColourShowcase.gd` renders the production scene/material/light code in six repeatable cases.
