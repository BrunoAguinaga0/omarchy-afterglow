# omarchy-config

Mis personalizaciones de Omarchy (tema Ristretto).

## Qué hay

- `plugins/bibek.lock`: pantalla de bloqueo con tarjeta de música, aura de colores que reacciona a la música (cava), clima, protector de pantalla con la portada y aviso "ahora suena". Basado en [omarchy-better-lock](https://github.com/BibekBhusal0/omarchy-better-lock) (MIT).
- `plugins/skyhonnor.performance`: [omarchy-performance](https://github.com/SkyHonnor/omarchy-performance) (MIT) con la opción `compact` (un solo ícono).
- `plugins/bruno.bar`: barra en islas flotantes (clon de `omarchy.bar`).
- `plugins/bruno.workspaces`: escritorios con pastilla animada e íconos de apps.
- `plugins/bruno.clock`: reloj que se corre a la derecha cuando suena música (opción `music`: `hide` / `only`).
- `plugins/bruno.music`: mini reproductor en la barra.
- `plugins/bruno.control`: centro de control (red, sonido, luz nocturna, no molestar).
- `plugins/bruno.osd`: avisos de volumen y brillo rediseñados.
- `config/omarchy/shell.json`: orden de la barra, idle y plugins activos.
- `config/omarchy/lock.json`: opciones del bloqueo (formato de hora, estilo del aura, protector, aviso).
- `config/hypr/hyprland.lua`: esquinas redondeadas (al final del archivo).

## Guardar cambios

```bash
./sync.sh
git status
git commit -am "..." && git push
```

## Restaurar en otra compu

1. Copiar cada carpeta de `plugins/` a `~/.config/omarchy/plugins/`.
2. Copiar `config/omarchy/*.json` a `~/.config/omarchy/` y `config/hypr/hyprland.lua` a `~/.config/hypr/`.
3. `omarchy pkg add cava` (para el aura) y `omarchy toggle screensaver` (apaga el protector de terminal, lo reemplaza el del bloqueo).
4. `hyprctl reload && omarchy restart shell`.
