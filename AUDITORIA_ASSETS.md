# Auditoria inicial dos arquivos — Pokémon Aventura Continua

**Data:** 10/11/2026  
**Branch:** main  
**Resultado:** inventário da raiz concluído.

## Estrutura encontrada

A raiz contém 18 arquivos: 1 README, 17 modelos 3D `.glb`. Não foram encontrados diretórios, subdiretórios nem arquivos compactados `.zip`, `.rar`, `.7z` ou semelhantes nesta listagem.

## Inventário

| Arquivo | Tamanho | Identificação provável |
|---|---:|---|
| `amoonguss.glb` | 164.172 B | Pokémon Amoonguss |
| `beedrill.glb` | 8.365.880 B | Pokémon Beedrill |
| `diancie_dancing_to_sweet_dreams.glb` | 1.478.444 B | Diancie, modelo/pose dançando |
| `eevee_pokemon.glb` | 1.263.992 B | Pokémon Eevee |
| `flygon_go_fest_2021.glb` | 4.163.980 B | Pokémon Flygon |
| `hisuian_voltorb.glb` | 8.554.368 B | Voltorb de Hisui |
| `ho_oh.glb` | 2.073.604 B | Pokémon Ho-Oh |
| `lucario.glb` | 2.484.300 B | Pokémon Lucario |
| `magnemite.glb` | 446.748 B | Pokémon Magnemite |
| `mew_pokemon.glb` | 6.873.212 B | Pokémon Mew |
| `original_pokemon_village.glb` | 23.675.404 B | Cenário/vila Pokémon 3D (principal mapa) |
| `pokemon_3ds_celebi.glb` | 677.588 B | Pokémon Celebi |
| `pokemon_basic_pokeball.glb` | 13.054.248 B | Pokébola/modelo relacionado |
| `pokemon_sudowoodo_-_tree.glb` | 1.354.152 B | Sudowoodo (modelo com aparência de árvore) |
| `shiny_metagross.glb` | 1.234.044 B | Metagross shiny |
| `smoliv_fully_rigged.glb` | 1.746.280 B | Smoliv, descrito no nome como rigged |
| `squirtle.glb` | 2.373.100 B | Pokémon Squirtle |
| `README.md` | 208 B | Instruções do repositório |

## Totais

- **18 arquivos** na raiz (17 modelos + README).
- **79.983.724 bytes** (~80 MB decimal; ~76,3 MiB) contabilizados.
- **1 cenário 3D** identificado pelo nome: `original_pokemon_village.glb`.
- **16 arquivos de modelos Pokémon/objetos** além do cenário.
- Nenhum arquivo compactado ou pasta apareceu na raiz.

## O que foi e o que não foi possível verificar

- Os nomes, caminhos e tamanhos foram conferidos pela API do GitHub.
- `.glb` é um formato de modelo 3D binário, não um ZIP de arquivos comuns. Ele pode conter malha, materiais, texturas e animações internamente; não deve ser descompactado como se fosse uma pasta de projeto.
- Esta auditoria inicial **não inspecionou o conteúdo interno de cada GLB** (meshes, materiais, esqueletos, animações, texturas embutidas), nem validou compatibilidade com Godot/Android.
- Não há ZIP/RAR/7z na listagem atual para extrair. Caso existam arquivos em outra branch, release ou upload que ainda não foi enviado ao GitHub, eles não estão incluídos neste inventário.

## Próxima etapa técnica

1. Inspecionar os GLBs individualmente: tamanho real, nós, materiais, texturas, rigs e animações.
2. Testar a importação do mapa `original_pokemon_village.glb` no Godot 4 e medir desempenho no Android.
3. Criar uma estrutura de projeto Godot (`project.godot`, cenas, scripts, UI e pastas de assets) sem alterar os modelos originais.
4. Integrar os Pokémon como entidades exploráveis/companheiros e preparar controles móveis.

> Observação: a presença de modelos 3D não significa que o jogo já esteja montado. Ainda faltam projeto Godot, lógica, câmera, movimentação, colisões, interface, sistema de captura/batalha e build Android.