# Guía paso a paso — publicar en GitHub (sin ser desarrollador)

Esta guía está pensada para alguien que **no programa**. Solo necesitas el navegador, el Odin2 (o el PC donde tengas el proyecto) y **copiar/pegar** comandos en la terminal.

**Nombre del repositorio:** `ayn-sm8550-easy-kernel-updater`  
**Título visible:** AYN sm8550 Easy Kernel Updater for Armbian

---

## ¿Puede la IA entrar en mi GitHub por mí?

**No.** Nadie (ni Cursor ni yo) puede entrar en tu cuenta de GitHub sin que **tú** inicies sesión una vez en tu dispositivo. No existe un botón mágico de “dame acceso”.

Lo que sí podemos hacer:

1. **Tú** creas el repositorio vacío en la web (5 minutos).  
2. **Tú** pegas 4–5 comandos en Konsole (te los damos abajo).  
3. Opcional: instalar **GitHub Desktop** y arrastrar la carpeta (aún más visual).

---

## Parte 1 — Cuenta y repositorio vacío (solo navegador)

### 1.1 Crear cuenta (si no tienes)

1. Abre [https://github.com/signup](https://github.com/signup)  
2. Email, contraseña, nombre de usuario (ejemplo: `odin2dev`)  
3. Verifica el email que te envían  

### 1.2 Crear el repositorio vacío

1. Inicia sesión en [https://github.com](https://github.com)  
2. Arriba a la derecha: **+** → **New repository**  
3. Rellena:

   | Campo | Qué poner |
   |-------|-----------|
   | **Repository name** | `ayn-sm8550-easy-kernel-updater` |
   | **Description** | `Gaming kernel builder for AYN SM8550 on Armbian` |
   | **Public** | marcado |
   | **Add README** | **NO** marcar |
   | **Add .gitignore** | **NO** marcar |
   | **Choose a license** | **NO** elegir (ya tenemos LICENSE en el proyecto) |

4. Pulsa **Create repository**  

Verás una página con comandos grises. **No hace falta entenderlos** — usa la Parte 2 de abajo.

Anota tu usuario de GitHub: `________________`

Tu repo quedará en:  
`https://github.com/TU_USUARIO/ayn-sm8550-easy-kernel-updater`

---

## Parte 2 — Subir el proyecto desde el Odin2 (terminal)

Abre **Konsole** en el Odin2.

### 2.1 Instalar git (solo la primera vez)

```bash
sudo apt update
sudo apt install -y git
```

### 2.2 Ir a la carpeta del proyecto

Ajusta la ruta si la tienes en otro sitio (Desktop, Projects, etc.):

```bash
cd ~/Projects/ayn-sm8550-kernel
```

Si está en el escritorio:

```bash
cd ~/Desktop/ayn-sm8550-kernel
```

Comprueba que ves los scripts:

```bash
ls make_kernel.sh update.sh README.md
```

### 2.3 (Opcional) Añadir tus videos demo

Si ya tienes los dos MP4 de ~10 segundos:

```bash
mkdir -p docs/videos
cp /ruta/a/tu-video-bueno.mp4   docs/videos/demo-tuned-kernel.mp4
cp /ruta/a/tu-video-malo.mp4    docs/videos/demo-armbian-default.mp4
```

Si aún no los tienes, puedes subirlos **después** (Parte 4).

### 2.4 Preparar git y el primer “commit”

Copia **todo este bloque** y pégalo de una vez:

```bash
cd ~/Projects/ayn-sm8550-kernel

chmod +x make_kernel.sh update.sh install-from-output.sh scripts/*.sh hooks/*

git init
git branch -M main

git config user.email "TU_EMAIL@ejemplo.com"
git config user.name "Tu Nombre"

git add .
git status

git commit -m "Initial release: AYN SM8550 easy kernel updater for Armbian"
```

**Importante:** cambia `TU_EMAIL@ejemplo.com` y `Tu Nombre` por los tuyos (pueden ser los de GitHub).

Si `git status` muestra `output/` o `.cache/`, no pasa nada — el `.gitignore` debería ignorarlos. Si aparecen en verde, avisa antes de continuar.

### 2.5 Conectar con GitHub y subir

Sustituye **TU_USUARIO** por tu nombre de GitHub (el de la Parte 1):

```bash
git remote add origin https://github.com/TU_USUARIO/ayn-sm8550-easy-kernel-updater.git
git push -u origin main
```

Te pedirá **usuario y contraseña de GitHub**:

- **Usuario:** tu nombre de GitHub  
- **Contraseña:** **NO** es la de la web — desde 2021 GitHub exige un **Personal Access Token (PAT)**  

→ Si no tienes token, sigue la **Parte 3** y vuelve aquí.

Si todo va bien, al refrescar la página del repo verás todos los archivos.

---

## Parte 3 — Token de acceso (solo una vez)

GitHub ya no acepta tu contraseña normal en `git push`. Necesitas un “token” (como una contraseña de app).

1. GitHub → foto arriba derecha → **Settings**  
2. Abajo del todo a la izquierda: **Developer settings**  
3. **Personal access tokens** → **Tokens (classic)**  
4. **Generate new token (classic)**  
5. Nombre: `odin2-git`  
6. Expiration: 90 days (o No expiration si prefieres)  
7. Marca la casilla **`repo`** (acceso completo a repositorios)  
8. **Generate token**  
9. **Copia el token** (empieza por `ghp_...`) — solo se muestra una vez  

En el `git push`, cuando pida **Password**, pega el **token** (no la contraseña de la web).

Guarda el token en un sitio seguro (bloc de notas cifrado, gestor de contraseñas).

---

## Parte 4 — Subir los videos a la página principal

### Opción A — Más fácil (editor web)

1. Ve a tu repo en GitHub  
2. Abre **README.md**  
3. Icono **lápiz** (Edit)  
4. Donde quieras el video, **arrastra el MP4** a la ventana de edición  
5. GitHub lo sube y crea un enlace automático  
6. Abajo: **Commit changes**  

Repite para el segundo video (bueno vs malo rendimiento).

### Opción B — Carpeta docs/videos

Si ya copiaste los MP4 en el paso 2.3:

```bash
cd ~/Projects/ayn-sm8550-kernel
git add docs/videos/*.mp4
git commit -m "docs: add performance demo videos"
git push
```

---

## Parte 5 — Dejar el repo presentable (opcional, 2 minutos)

En la página principal del repo, engranaje **About** (derecha):

- **Description:** `Easy gaming kernel builder & installer for AYN Odin2 / Thor on Armbian`  
- **Topics** (etiquetas): `armbian` `ayn` `odin2` `sm8550` `kernel` `gaming`  

---

## Parte 6 — Enlace para compartir

Cuando termines, la gente clona así:

```bash
git clone https://github.com/TU_USUARIO/ayn-sm8550-easy-kernel-updater.git
cd ayn-sm8550-easy-kernel-updater
./make_kernel.sh
```

Pon ese enlace en la descripción de tus videos.

---

## Problemas frecuentes

| Problema | Qué hacer |
|----------|-----------|
| `remote origin already exists` | `git remote remove origin` y repite el `git remote add` |
| `Authentication failed` | Usa **token** (Parte 3), no contraseña web |
| `Permission denied (publickey)` | Usa URL **https://** (no git@github.com) |
| Archivo muy grande (>100 MB) | No subas `output/` ni `.cache/`; comprime videos o usa YouTube |
| No encuentro la carpeta | `find ~ -name make_kernel.sh 2>/dev/null` |

---

## Alternativa visual: GitHub Desktop (PC con Windows/Mac)

Si tienes un PC aparte:

1. [https://desktop.github.com](https://desktop.github.com) — instalar  
2. Iniciar sesión con tu cuenta GitHub  
3. **File → Add local repository** → elegir carpeta `ayn-sm8550-kernel`  
4. **Publish repository** → nombre `ayn-sm8550-easy-kernel-updater` → Public  

En el Odin2/Linux, la terminal (Parte 2) suele ser más directa.

---

## Checklist final

- [ ] Repo creado en github.com (vacío, sin README automático)  
- [ ] `git push` completado sin errores  
- [ ] README visible en inglés  
- [ ] Dos videos demo enlazados o en `docs/videos/`  
- [ ] Topics añadidos en About  

¡Listo! No necesitas ser desarrollador — solo seguir los pasos en orden.
