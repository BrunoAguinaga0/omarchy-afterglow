# omarchy-config

Mis personalizaciones de Omarchy (tema Ristretto).

## Qué hay

- `plugins/bibek.lock`: pantalla de bloqueo con tarjeta de música, aura de colores que reacciona a la música (cava), clima, protector de pantalla con la portada y aviso "ahora suena". Basado en [omarchy-better-lock](https://github.com/BibekBhusal0/omarchy-better-lock) (MIT).
- `plugins/skyhonnor.performance`: [omarchy-performance](https://github.com/SkyHonnor/omarchy-performance) (MIT) con la opción `compact` (un solo ícono).
- `plugins/bruno.bar`: barra en islas flotantes (clon de `omarchy.bar`).
- `plugins/bruno.workspaces`: escritorios con pastilla animada e íconos de apps.
- `plugins/bruno.clock`: reloj que se corre a la derecha cuando suena música (opción `music`: `hide` / `only`).
- `plugins/bruno.music`: mini reproductor en la barra; ocupa toda la isla del centro y el menú se abre al pasar el mouse.
- `plugins/bruno.menu`: copia del menú de Super + Espacio con otro aspecto (buscador con lupa, íconos en cuadraditos, separadores, ayuda de teclado). No recibe las actualizaciones del menú original de Omarchy.
- `plugins/bruno.control`: centro de control (red, sonido, luz nocturna, no molestar), en gris como las demás islas.
- `plugins/bruno.osd`: avisos de volumen y brillo rediseñados.
- `config/`: archivos de `~/.config`; la lista está en `files.sh` y la usan `sync.sh` y `restore.sh`.
  - `omarchy/shell.json`: orden de la barra, idle y plugins activos.
  - `omarchy/shell.toml`: vidrio y bordes del menú y las notificaciones (colores de Ristretto).
  - `omarchy/lock.json`: opciones del bloqueo (formato de hora, estilo del aura, protector, aviso).
  - `hypr/hyprland.lua`: esquinas redondeadas (al final del archivo).
  - `hypr/looknfeel.lua`: espacios entre ventanas, animaciones, ventana inactiva atenuada y borde solo con dos o más ventanas.
  - `foot/foot.ini`: margen de la terminal y fuente de respaldo para los símbolos del prompt.
  - `starship.toml`: prompt en píldoras.
  - `fastfetch/`: fastfetch compacto con logo propio.
  - `omarchy/hooks/theme-set.d/bruno-colors`: al cambiar de tema, recolorea el menú, las notificaciones, el prompt y fastfetch con los colores del tema nuevo.
  - `omarchy/plymouth/`: pantalla de arranque "bruno" (fondo desenfocado, tarjeta de vidrio, contraseña redondeada) e `install.sh`, que la instala junto con el cursor Catppuccin Mocha Dark. Pide sudo; `restore.sh` no lo corre solo. Para volver a la de Omarchy: `omarchy plymouth set by theme ristretto`.
  - `hypr/hyprland.lua` también abre Spotify en el escritorio 3 y Chromium en el 2, y elige el cursor.
- `state/`: interruptores de Omarchy, tema y fondo elegidos.

## Guardar cambios

```bash
./sync.sh
git status
git commit -am "..." && git push
```

## Restaurar en otra compu

```bash
gh repo clone BrunoAguinaga0/omarchy-config
cd omarchy-config
omarchy pkg add cava      # para que el aura reaccione a la música
./restore.sh
```

`restore.sh` copia los plugins y la config, los interruptores de Omarchy (`state/toggles`: barra y ventanas de vidrio, esquinas redondeadas, protector de terminal apagado; quedan exactamente como en el repo), aplica el tema y el fondo (`state/theme`, `state/background`), enlaza el plugin de Superwhisper si la app está instalada y reinicia el shell. Todo lo que reemplaza queda antes en `*.bak.<fecha>`.

La ciudad del clima solo se guarda si se eligió a mano; si no, Omarchy la detecta por IP.

Los clones (`bruno.bar`, `bruno.clock`, `bruno.osd`, `bruno.workspaces`) salen de la versión de Omarchy de noviembre 2026; con una versión mucho más nueva puede hacer falta volver a clonar el original y reaplicar los cambios.
