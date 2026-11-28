# Publicar plugins (pendiente)

Notas para el día que quiera compartir partes de este Omarchy con otros.

## Cómo se comparten plugins en Omarchy

Cada plugin es un repo de git propio. Quien lo quiera lo instala con:

```bash
omarchy plugin add https://github.com/<usuario>/<repo>.git --enable
```

Antes de publicar, se valida la carpeta con:

```bash
omarchy plugin validate ~/.config/omarchy/plugins/<id>
```

Lo que conviene es subir plugins sueltos, no todo el escritorio junto.

**omarchyplugins.com:** no revisé cómo funciona ni cómo se publica ahí. Mirarlo antes; probablemente liste repos de GitHub.

## Qué publicar

| Plugin | ¿Publicar? | Por qué |
|---|---|---|
| `bruno.music` | **Sí, el primero** | Es lo más original: píldora con portada, halo y menú que siguen la música (cava), y clic para abrir el reproductor. |
| `bruno.control` | Se puede | Es propio. |
| `bruno.bar`, `bruno.menu`, `bruno.workspaces`, `bruno.clock`, `bruno.osd` | No como plugins | Son copias modificadas de los plugins de Omarchy (`clonedFrom` en su `manifest.json`). Quedan atadas a esa versión y se desactualizan con cada update. Se pueden mostrar como inspiración. |
| `bibek.lock` | No | Es de Bibek Bhusal (https://github.com/BibekBhusal0/omarchy-better-lock). Se puede recomendar, no publicar como propio. |
| Este repo (`omarchy-afterglow`) | Hecho | Público desde el 22/11/2026, con `LICENSE` (MIT) y `NOTICE.md` con los créditos. |

## Pendientes antes de publicar `bruno.music`

1. **Crédito y licencia:** `CoverPalette.qml` es idéntico al de `bibek.lock`, y `MediaCard.qml` está basado en el suyo. Su licencia es MIT, así que se pueden usar, pero hay que:
   - incluir su aviso de copyright (`Copyright (c) 2026 Bibek Bhusal`) en un `LICENSE` o `NOTICE` (en este repo ya está en `NOTICE.md`),
   - mencionarlo en el README.
2. **Que funcione en un Omarchy sin mis cambios:**
   - El modo "isla" (la píldora ocupa la isla del centro) usa funciones que agregué a `bruno.bar` (`islands`, `islandHeight`, `islandColor`, `setCenterIslandYielded`). Sin ellas no se rompe, pero hay que probar cómo se ve con la barra normal de Omarchy.
   - Cambiar de tema desde el menú usa `quietNowPlaying` de `bibek.lock` para no mostrar el aviso. Es opcional: probar que no dé errores si `bibek.lock` no está instalado.
   - Necesita `cava` instalado para que el brillo siga la música. Sin cava, el brillo queda quieto. Ponerlo en el README.
3. **Repo público:**
   - README con capturas o un GIF,
   - archivo de licencia (MIT, por ejemplo),
   - revisar `author` e `id` en `manifest.json` (hoy dicen "bruno"),
   - subir `version` cuando haya cambios.
4. **Decidir qué incluir:** el marco de luz alrededor de las ventanas y el halo de la píldora viven en el mismo `Widget.qml`. Quizás convenga que el marco sea una opción que se pueda apagar.

## Pasos cuando lo haga

1. Copiar `~/.config/omarchy/plugins/bruno.music` a un repo nuevo, por ejemplo `omarchy-music-pill`.
2. Resolver los pendientes de arriba.
3. Correr `omarchy plugin validate` sobre la carpeta.
4. Probarlo en limpio: `omarchy plugin add <url> --enable` con el plugin local desactivado.
5. Publicarlo en GitHub y, si corresponde, en omarchyplugins.com.
