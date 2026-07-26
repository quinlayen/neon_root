#!/bin/bash
# ============================================================
#  Neon Root — ASCII Art & Color Definitions
#  Sourceable; colors + welcome banner for generator/launcher.
#  Borders use plain ASCII; box lines share a fixed width.
# ============================================================

R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; B=$'\e[34m'
M=$'\e[35m'; C=$'\e[36m'; W=$'\e[37m'
BLD=$'\e[1m'; DIM=$'\e[2m'; N=$'\e[0m'
BR=$'\e[1;31m'; BG=$'\e[1;32m'; BY=$'\e[1;33m'
BC=$'\e[1;36m'; BW=$'\e[1;37m'; BM=$'\e[1;35m'
DR=$'\e[2;31m'; DY=$'\e[2;33m'; DW=$'\e[2;37m'

# ── ART_WELCOME ──
ART_WELCOME="
${C}              +---------------------------------------+${N}
${C}              |                                       |${N}
${C}              |            N E O N   R O O T          |${N}
${C}              |                                       |${N}
${M}              |         M E T R O P L E X   O S       |${N}
${C}              |                                       |${N}
${Y}              |     A Multi-Skill Command Adventure   |${N}
${C}              |                                       |${N}
${C}              +---------------------------------------+${N}
${M}              |###|       :::::::::::::::::       |###|${N}
${M}              |###|     . jack into the grid .    |###|${N}
${M}              |###|      . shell  py  git  .      |###|${N}
${M}              |###|       :::::::::::::::::       |###|${N}
${C}              +---+           #########           +---+${N}
${C}              ===            ###########            ===${N}
"
