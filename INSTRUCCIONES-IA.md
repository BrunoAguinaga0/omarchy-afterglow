# Instrucciones para una IA: aplicar este diseño de Omarchy

*[Read in English](INSTRUCTIONS-AI.md)*

Sos un asistente con acceso a una terminal en una compu con **Omarchy** (Arch Linux + Hyprland). Tu tarea es aplicar el **diseño visual** del repo `https://github.com/BrunoAguinaga0/omarchy-config` sobre el Omarchy del usuario, sin pisar sus configuraciones personales (monitores, teclado, atajos, apps, dock, tiempos de bloqueo, etc.).

Seguí los pasos en orden, verificá cada uno y avisale al usuario si algo falla. No inventes cambios de diseño: todo lo necesario está en el repo.

> **No corras `restore.sh`.** Es el script del autor para restaurar *su* compu completa: reemplaza `hyprland.lua`, `shell.json` y los interruptores de Omarchy enteros, incluidas sus preferencias personales. Esta guía aplica solo la parte visual, archivo por archivo.

## Cómo se ve

- **Tema Ristretto** con el fondo `3-industrial-moon.webp`. El diseño sigue los colores de cualquier tema: si el usuario cambia de tema, menú, notificaciones, prompt y fastfetch se recolorean solos.
- **Barra arriba en islas flotantes de vidrio** (`bruno.bar`):
  - Izquierda: botón de menú (`bruno.menu`) y escritorios con pastilla animada e íconos de las apps abiertas (`bruno.workspaces`).
  - Centro: reloj (`bruno.clock`) que se corre a la derecha cuando suena música, y mini reproductor (`bruno.music`) que ocupa la isla, con portada, halo en los colores de la portada y menú al pasar el mouse.
  - Derecha: bandeja, rendimiento en un solo ícono (`skyhonnor.performance`), distribución de teclado, indicadores, actualizaciones, clima, reloj (solo con música) y centro de control (`bruno.control`: red, sonido, luz nocturna, no molestar).
- **Menú de Super + Espacio** rediseñado: buscador con lupa, íconos en cuadraditos, separadores y ayuda de teclado.
- **Pantalla de bloqueo** `bibek.lock`: tarjeta de música, aura de colores que late con la música, clima, aviso "ahora suena" y protector de pantalla propio (la portada grande con el aura, o un reloj sin música) en lugar del protector de terminal de Omarchy.
- **Avisos de volumen y brillo** rediseñados (`bruno.osd`).
- **Ventanas**: vidrio esmerilado, esquinas redondeadas de 18 px, espacios de 4/8 px, ventana inactiva atenuada, sin borde cuando hay una sola ventana, animaciones "popin" y deslizamientos suaves.
- **Terminal** `foot` con márgenes amplios, prompt `starship` en píldoras y `fastfetch` compacto con un logo cuadrado.
- **Cursor** Catppuccin Mocha Dark y **pantalla de arranque** Plymouth "bruno" (fondo desenfocado, tarjeta de vidrio, contraseña redondeada).

## Requisitos

| Requisito | Para qué | Cómo verificar / instalar |
|---|---|---|
| Omarchy con sesión Hyprland abierta | Todo | `omarchy version`. El diseño se hizo sobre **4.5.0-3** (noviembre 2026) |
| `git`, `rsync`, `jq`, `python3` | Clonar, copiar, editar JSON, hook de colores | `pacman -Q git rsync jq python` (vienen con Omarchy) |
| `cava` | Aura y halo que reaccionan a la música | `omarchy pkg add cava` |
| `starship`, `fastfetch`, `foot` | Terminal y prompt | Vienen con Omarchy; si faltan: `omarchy pkg add starship fastfetch foot` |
| Fuentes `adwaita-fonts` y `ttf-jetbrains-mono-nerd` | Terminal y símbolos del prompt | `fc-list \| grep -i -E "adwaita mono\|jetbrainsmono nerd"` |
| `yay` | Cursor desde AUR | `command -v yay` (viene con Omarchy) |
| `sudo` | Cursor y pantalla de arranque | El usuario escribe su contraseña |
| Un reproductor con MPRIS (Spotify, Chromium, mpv…) | Que aparezca la música en la barra y el bloqueo | Cualquiera sirve |

**Versión de Omarchy:** `bruno.bar`, `bruno.clock`, `bruno.osd`, `bruno.workspaces`, `bruno.menu` y `bibek.lock` son copias modificadas de plugins de Omarchy (ver `clonedFrom` en su `manifest.json`). Si el usuario tiene una versión mucho más nueva que 4.5.0, avisale que alguno puede no cargar.

## Pasos

Antes de reemplazar cualquier archivo, hacé una copia `archivo.bak.<fecha>`. Usá una sola marca de tiempo para todo:

```bash
stamp=$(date +%s)
bak() { [[ -e $1 ]] && cp -a "$1" "$1.bak.$stamp"; return 0; }
```

### 1. Comprobaciones previas y dependencias

```bash
omarchy version
[[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && echo "Hyprland OK"
omarchy pkg add cava
```

### 2. Clonar el repo

```bash
repo=$(mktemp -d)/omarchy-config
git clone --depth 1 https://github.com/BrunoAguinaga0/omarchy-config.git "$repo"
```

### 3. Plugins

```bash
plugins_dir=~/.config/omarchy/plugins
mkdir -p "$plugins_dir"
for dir in "$repo"/plugins/*/; do
  name=$(basename "$dir")
  bak "$plugins_dir/$name"
  mkdir -p "$plugins_dir/$name"
  rsync -a "$dir" "$plugins_dir/$name/"
done
```

### 4. Barra y plugins activos (`shell.json`)

No reemplaces el archivo: copiá solo la barra y la lista de plugins, y dejá como están el dock, los tiempos de bloqueo y lo demás del usuario.

```bash
shell=~/.config/omarchy/shell.json
bak "$shell"
[[ -s $shell ]] || echo '{"version":1}' > "$shell"
jq --slurpfile d "$repo/config/omarchy/shell.json" '
  .bar = $d[0].bar
  | .plugins = $d[0].plugins
  | .disabledPlugins = $d[0].disabledPlugins
  | .cloneSourceRestores = $d[0].cloneSourceRestores
' "$shell" > "$shell.tmp" && mv "$shell.tmp" "$shell"
```

La bandeja del diseño incluye `superwhisper.panel` (una app de dictado). Si el usuario no tiene Superwhisper (`ls /opt/superwhisper` falla), sacalo:

```bash
jq '.bar.layout.tray |= map(select(.id != "superwhisper.panel"))' "$shell" > "$shell.tmp" && mv "$shell.tmp" "$shell"
```

### 5. Archivos visuales que se copian enteros

```bash
for f in omarchy/shell.toml omarchy/lock.json hypr/looknfeel.lua starship.toml fastfetch/config.jsonc fastfetch/logo.txt; do
  bak ~/.config/$f
  mkdir -p "$(dirname ~/.config/$f)"
  cp "$repo/config/$f" ~/.config/$f
done
```

- `shell.toml`: vidrio y bordes del menú y las notificaciones.
- `lock.json`: formato de hora del bloqueo y estilo del aura (`halo`).
- `looknfeel.lua`: espacios, animaciones, ventana inactiva atenuada y sin borde con una sola ventana. Si el usuario ya tenía cosas propias ahí, mostrale el `.bak` y ofrecé sumarlas al final.

### 6. Terminal (`foot.ini`)

Cambiá solo la fuente y el margen; el resto del archivo es del usuario:

```bash
foot=~/.config/foot/foot.ini
bak "$foot"
sed -i -E 's|^font=.*|font=Adwaita Mono:size=9,JetBrainsMono Nerd Font:size=9|; s|^pad=.*|pad=24x20|' "$foot"
grep -q '^font=' "$foot" || sed -i '/^\[main\]/a font=Adwaita Mono:size=9,JetBrainsMono Nerd Font:size=9' "$foot"
grep -q '^pad=' "$foot" || sed -i '/^\[main\]/a pad=24x20' "$foot"
```

### 7. Esquinas redondeadas y cursor (`hyprland.lua`)

No copies `hyprland.lua` del repo: tiene reglas personales del autor. Agregá **solo** este bloque al final del `~/.config/hypr/hyprland.lua` del usuario. Tiene que quedar después de `require("default.hypr.toggles")` para ganarle al redondeo del tema. Si ya está, no lo dupliques:

```bash
hypr=~/.config/hypr/hyprland.lua
bak "$hypr"
grep -q 'rounding = 18' "$hypr" || cat >> "$hypr" <<'LUA'

-- Rounded corners even with the no-gaps toggle on (it forces rounding = 0).
hl.config({
  decoration = {
    rounding = 18,
    rounding_power = 2,
  },
})

-- Cursor: Catppuccin Mocha Dark (AUR catppuccin-cursors-mocha).
hl.env("XCURSOR_THEME", "catppuccin-mocha-dark-cursors")
hl.env("HYPRCURSOR_THEME", "catppuccin-mocha-dark-cursors")
LUA
```

### 8. Vidrio y esquinas (interruptores de Omarchy)

Agregá solo los interruptores visuales, sin borrar los que el usuario ya tenga (no uses `--delete`):

```bash
toggles="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/toggles/hypr"
mkdir -p "$toggles"
cp "$repo"/state/toggles/hypr/{bar-glassy,window-glassy,corners-rounded}.lua "$toggles/"
```

Apagá también el protector de pantalla de Omarchy (el de la terminal): el bloqueo `bibek.lock` trae su propio protector (la portada grande con el aura, o un reloj si no suena música) que lo reemplaza. Si quedan los dos encendidos, aparecen ambos.

```bash
cp "$repo/state/toggles/screensaver-off" "${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/toggles/"
```

El protector aparece después de `idle.screensaver` segundos de inactividad, según el `shell.json` del usuario. No cambies sus tiempos.

### 9. Hook que recolorea con cada tema

```bash
hooks=~/.config/omarchy/hooks/theme-set.d
mkdir -p "$hooks"
cp "$repo/config/omarchy/hooks/theme-set.d/bruno-colors" "$hooks/"
chmod +x "$hooks/bruno-colors"
```

### 10. Tema y fondo

```bash
hyprctl reload
omarchy theme set ristretto
omarchy theme bg set "${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/current/theme/backgrounds/3-industrial-moon.webp"
"$hooks/bruno-colors"
omarchy restart shell
```

Si el usuario prefiere otro tema, salteá `theme set` y `bg set`: el diseño toma los colores del tema que tenga.

### 11. Cursor y pantalla de arranque (pide sudo)

Copiá los archivos y pedile al usuario que corra el instalador **él mismo** en su terminal, porque pide contraseña:

```bash
mkdir -p ~/.config/omarchy/plymouth
rsync -a "$repo/config/omarchy/plymouth/" ~/.config/omarchy/plymouth/
echo "Corré: ~/.config/omarchy/plymouth/install.sh"
```

Instala `catppuccin-cursors-mocha` desde AUR, lo deja como cursor por defecto, instala el tema Plymouth `bruno` en `/usr/share/plymouth/themes/bruno` y regenera el initramfs. La pantalla de arranque se ve al reiniciar. Para volver a la de Omarchy: `omarchy plymouth set by theme ristretto`.

## Verificar

```bash
omarchy theme current                                          # → Ristretto (si se aplicó)
ls ~/.config/omarchy/plugins                                   # → bibek.lock, bruno.*, skyhonnor.performance
jq -r '.bar.id, (.disabledPlugins|join(","))' ~/.config/omarchy/shell.json   # → bruno.bar / omarchy.lock,omarchy.osd,omarchy.menu
ls "${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/toggles/hypr"  # → bar-glassy, window-glassy, corners-rounded
ls "${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/toggles/screensaver-off"  # existe
command -v cava
```

Y a la vista, con el usuario:

- La barra está arriba, en islas de vidrio, con el reloj en el centro.
- Al poner música: el reloj se corre a la derecha, el reproductor ocupa el centro y sus colores siguen la portada.
- `Super + Espacio` abre el menú rediseñado.
- Al bloquear (`omarchy-system-lock`) se ve la tarjeta de música y el aura.
- Al subir el volumen aparece el aviso rediseñado.
- `omarchy-shell lock screensaver` muestra el protector con la portada (el mismo comando lo cierra).
- Una terminal nueva muestra el prompt en píldoras y márgenes amplios.

Si algún plugin no aparece, revisá los logs (`journalctl --user -b | grep -i -E "qml|plugin" | tail -50`) y validalo con `omarchy plugin validate ~/.config/omarchy/plugins/<id>`.

## Qué no hacer

- No corras `restore.sh` ni `sync.sh` del repo: son del autor para su propia compu.
- No copies `hypr/hyprland.lua`, `hypr/monitors.lua`, `hypr/input.lua`, `hypr/bindings.lua` ni `hypr/autostart.lua`.
- No cambies el dock, los tiempos de bloqueo, el clima ni los atajos del usuario.
- No "mejores" los plugins ni los colores: el objetivo es el diseño tal cual.
- No borres los `*.bak.*`; sirven para volver atrás.

## Deshacer

Cada archivo reemplazado tiene su `*.bak.<stamp>`: copialo encima del actual. Para los plugins, borrá las carpetas `bruno.*`, `bibek.lock` y `skyhonnor.performance` de `~/.config/omarchy/plugins` y restaurá `shell.json` desde su `.bak`. Después: `hyprctl reload && omarchy restart shell`.

## Créditos

- `bibek.lock`: basado en [omarchy-better-lock](https://github.com/BibekBhusal0/omarchy-better-lock) de Bibek Bhusal (MIT).
- `skyhonnor.performance`: [omarchy-performance](https://github.com/SkyHonnor/omarchy-performance) (MIT), con la opción `compact`.
- `bruno.bar`, `bruno.clock`, `bruno.menu`, `bruno.osd`, `bruno.workspaces`: modificados a partir de los plugins de Omarchy.
